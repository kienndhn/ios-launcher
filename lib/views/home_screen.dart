import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_info.dart';
import '../models/grid_item.dart';
import '../utils/grid_utils.dart';
import '../utils/theme.dart';
import '../widgets/app_grid.dart';
import '../widgets/dock.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  static const platform = MethodChannel('com.example.ios_launcher/apps');

  // Configurable hold delays
  static const Duration dragDelay = Duration(milliseconds: 500);
  static const Duration popupDelay = Duration(
    milliseconds: 1000,
  ); // Always dragDelay * 2

  List<AppInfo> dockApps = [];
  List<GridItem> gridApps = [];
  List<AppInfo> allApps = [];
  Map<String, int> _launchCounts = {};
  bool isLoading = true;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  bool _isGlobalDragging = false;
  GridDragInfo? _activeDragInfo;
  GridCoordinate? _hoveredSlot;
  Timer? _pageTurnTimer;
  Timer? _hoverTimer;
  bool _isEditingMode = false;
  bool _isContextMenuOpen = false;

  String _wallpaperType = 'gradient';
  Color _color1 = const Color(0xFF1D2671);
  Color _color2 = const Color(0xFFC33764);
  String? _wallpaperImagePath;

  bool _showClockWidget = false;
  bool _showWeatherWidget = false;
  bool _showBatteryWidget = false;

  AppInfo? _launchingApp;
  AppGridItem? _displacedDockAppItem;
  Map<String, Offset> _displacedInitialOffsets = {};
  Map<String, Offset> _dockInitialOffsets = {};
  final AppInfo _dockDummyApp = AppInfo(
    packageName: 'dock_dummy',
    label: '',
    icon: Uint8List(0),
  );
  Offset? _launchStartBounds;
  Size? _launchStartSize;
  late AnimationController _launchAnimationController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeData();
    _launchAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
  }

  Future<void> _initializeData() async {
    await _loadWallpaperSettings();
    await _loadWidgetSettings();
    _launchCounts = await _loadLaunchCounts();
    await _loadApps();
  }

  Future<Map<String, int>> _loadLaunchCounts() async {
    try {
      final file = File(
        '/data/data/com.example.ios_launcher/files/launch_counts.json',
      );
      if (await file.exists()) {
        final content = await file.readAsString();
        final Map<String, dynamic> jsonMap = jsonDecode(content);
        return jsonMap.map((key, value) => MapEntry(key, value as int));
      }
    } catch (e) {
      print("Error loading launch counts: $e");
    }
    return {};
  }

  Future<void> _recordAppLaunch(String packageName) async {
    try {
      final file = File(
        '/data/data/com.example.ios_launcher/files/launch_counts.json',
      );
      _launchCounts[packageName] = (_launchCounts[packageName] ?? 0) + 1;
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(_launchCounts));
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print("Error saving launch counts: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _launchAnimationController.dispose();
    _pageTurnTimer?.cancel();
    _hoverTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initializeData();
      if (_launchingApp != null) {
        setState(() {
          _launchingApp = null;
          _launchAnimationController.reset();
        });
      }
    } else if (state == AppLifecycleState.paused) {
      if (_launchingApp != null) {
        setState(() {
          _launchingApp = null;
          _launchAnimationController.reset();
        });
      }
    }
  }

  Future<void> _loadWallpaperSettings() async {
    try {
      final Map<dynamic, dynamic>? settings = await platform.invokeMethod(
        'getWallpaperSettings',
      );
      if (settings != null && mounted) {
        setState(() {
          _wallpaperType = settings['type'] as String;
          final c1Val = settings['color1'] as int;
          final c2Val = settings['color2'] as int;
          _color1 = Color(c1Val);
          _color2 = Color(c2Val);
          _wallpaperImagePath = settings['imagePath'] as String?;
        });
      }
    } catch (e) {
      print("Failed to load wallpaper settings: $e");
    }
  }

  Future<void> _loadWidgetSettings() async {
    try {
      final Map<dynamic, dynamic>? settings = await platform.invokeMethod(
        'getWidgetSettings',
      );
      if (settings != null && mounted) {
        setState(() {
          _showClockWidget = settings['showClock'] as bool? ?? false;
          _showWeatherWidget = settings['showWeather'] as bool? ?? false;
          _showBatteryWidget = settings['showBattery'] as bool? ?? false;
        });
      }
    } catch (e) {
      print("Failed to load widget settings: $e");
    }
  }

  Future<void> _saveWidgetSettings() async {
    try {
      await platform.invokeMethod('saveWidgetSettings', {
        'showClock': _showClockWidget,
        'showWeather': _showWeatherWidget,
        'showBattery': _showBatteryWidget,
      });
    } catch (e) {
      print("Failed to save widget settings: $e");
    }
  }

  Future<void> _changeWallpaperToGradient(Color c1, Color c2) async {
    try {
      final bool success = await platform.invokeMethod('setGradientWallpaper', {
        'color1': c1.value,
        'color2': c2.value,
      });
      if (success && mounted) {
        setState(() {
          _wallpaperType = 'gradient';
          _color1 = c1;
          _color2 = c2;
          _wallpaperImagePath = null;
        });
      }
    } catch (e) {
      print("Failed to set gradient wallpaper: $e");
    }
  }

  Future<void> _changeWallpaperToGallery() async {
    try {
      final String? path = await platform.invokeMethod('pickImageFromGallery');
      if (path != null && mounted) {
        setState(() {
          _wallpaperType = 'image';
          _wallpaperImagePath = path;
        });
      }
    } catch (e) {
      print("Failed to pick image from gallery: $e");
    }
  }

  Future<void> _changeWallpaperToAsset(String assetPath) async {
    try {
      final bool success = await platform.invokeMethod('setAssetWallpaper', {
        'assetPath': assetPath,
      });

      if (success && mounted) {
        setState(() {
          _wallpaperType = 'asset';
          _wallpaperImagePath = assetPath;
        });
      }
    } catch (e) {
      print("Failed to set asset wallpaper: $e");
    }
  }

  Future<void> _loadApps() async {
    try {
      // 1. Load custom iOS icons JSON (Mapped by PackageName / Bundle ID)
      Map<String, dynamic> customIcons = {};
      try {
        final jsonStr = await rootBundle.loadString('assets/icons/custom_icons.json');
        customIcons = jsonDecode(jsonStr);
      } catch (e) {
        print("Failed to load custom icons: $e");
      }

      // 2. Fetch installed apps
      final List<dynamic> result = await platform.invokeMethod(
        'getInstalledApps',
      );
      final List<AppInfo> loaded = result.map((app) {
        final map = app as Map<dynamic, dynamic>;
        final packageName = map['packageName'] as String;
        final label = map['label'] as String;
        Uint8List iconBytes = map['icon'] as Uint8List;
        
        // 3. Inject custom icon if packageName matches
        if (customIcons.containsKey(packageName)) {
          try {
            iconBytes = base64Decode(customIcons[packageName] as String);
          } catch (e) {
            print("Failed to decode custom icon for $packageName: $e");
          }
        }

        return AppInfo(
          packageName: packageName,
          label: label,
          icon: iconBytes,
        );
      }).toList();

      if (!isLoading) {
        final newPackages = loaded.map((app) => app.packageName).toSet();
        final oldPackages = <String>{};
        for (final app in dockApps) {
          oldPackages.add(app.packageName);
        }
        for (final item in gridApps) {
          if (item is AppGridItem) {
            oldPackages.add(item.app.packageName);
          }
        }

        if (newPackages.length == oldPackages.length &&
            newPackages.containsAll(oldPackages)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkDefaultLauncher();
          });
          return;
        }
      }

      List<String> savedLayout = [];
      try {
        final List<dynamic>? layoutResult = await platform.invokeMethod(
          'getGridLayout',
        );
        if (layoutResult != null) {
          savedLayout = List<String>.from(layoutResult);
        }
      } catch (e) {
        print("Failed to get grid layout: $e");
      }

      List<String> savedDockLayout = [];
      try {
        final List<dynamic>? dockResult = await platform.invokeMethod(
          'getDockLayout',
        );
        if (dockResult != null) {
          savedDockLayout = List<String>.from(dockResult);
        }
      } catch (e) {
        print("Failed to get dock layout: $e");
      }

      final Map<String, AppInfo> allAppMap = {
        for (final app in loaded) app.packageName: app,
      };

      if (savedDockLayout.isNotEmpty) {
        dockApps = [];
        for (final id in savedDockLayout) {
          if (allAppMap.containsKey(id)) {
            dockApps.add(allAppMap[id]!);
          }
        }
      } else {
        if (loaded.length >= 4) {
          dockApps = loaded.sublist(0, 4);
        } else {
          dockApps = loaded;
        }
      }

      final Map<String, AppInfo> appMap = {};
      for (final app in loaded) {
        if (!dockApps.any((d) => d.packageName == app.packageName)) {
          appMap[app.packageName] = app;
        }
      }

      final List<GridItem> tempGrid = [];

      // Phục hồi bố cục từ dữ liệu đã lưu
      for (final rawStr in savedLayout) {
        final parts = rawStr.split(':');
        final id = parts[0];
        int page = 0;
        int row = 0;
        int col = 0;
        if (parts.length >= 4) {
          page = int.tryParse(parts[1]) ?? 0;
          row = int.tryParse(parts[2]) ?? 0;
          col = int.tryParse(parts[3]) ?? 0;
        }

        GridItem? item;
        if (id == 'clock') {
          if (_showClockWidget) {
            item = WidgetGridItem('clock', page: page, row: row, col: col);
          }
        } else if (id == 'weather') {
          if (_showWeatherWidget) {
            item = WidgetGridItem('weather', page: page, row: row, col: col);
          }
        } else if (id == 'battery') {
          if (_showBatteryWidget) {
            item = WidgetGridItem('battery', page: page, row: row, col: col);
          }
        } else {
          final app = appMap[id];
          if (app != null) {
            item = AppGridItem(app, page: page, row: row, col: col);
            appMap.remove(id);
          }
        }

        if (item != null) {
          tempGrid.add(item);
        }
      }

      // Khởi tạo bố cục mặc định khi chạy lần đầu
      if (savedLayout.isEmpty) {
        _showClockWidget = true;
        _showWeatherWidget = true;
        _showBatteryWidget = true;
        _saveWidgetSettings();

        // Đồng hồ ở góc trái, Thời tiết ở góc phải, Pin ở hàng thứ 3
        tempGrid.add(WidgetGridItem('clock', page: 0, row: 0, col: 0));
        tempGrid.add(WidgetGridItem('weather', page: 0, row: 0, col: 2));
        tempGrid.add(WidgetGridItem('battery', page: 0, row: 2, col: 0));
      }

      // Xếp các ứng dụng mới vào các ô trống còn lại
      for (final app in appMap.values) {
        final emptySlot = findFirstEmptySlot(tempGrid, 1, 1);
        tempGrid.add(
          AppGridItem(
            app,
            page: emptySlot.page,
            row: emptySlot.row,
            col: emptySlot.col,
          ),
        );
      }

      // Giải quyết va chạm ô lưới nếu có
      resolveOverlaps(tempGrid);

      setState(() {
        allApps = loaded;
        gridApps = tempGrid;
        isLoading = false;
      });

      if (savedLayout.isEmpty) {
        _saveGridLayout();
      }
      if (savedDockLayout.isEmpty) {
        _saveDockLayout();
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkDefaultLauncher();
      });
    } on PlatformException catch (e) {
      print("Failed to get apps: '${e.message}'.");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _saveGridLayout() async {
    try {
      final List<String> layoutIds = gridApps
          .map((item) => '${item.id}:${item.page}:${item.row}:${item.col}')
          .toList();
      await platform.invokeMethod('saveGridLayout', {'layout': layoutIds});
    } catch (e) {
      print("Failed to save grid layout: $e");
    }
  }

  Future<void> _saveDockLayout() async {
    try {
      final List<String> layoutIds = dockApps
          .map((app) => app.packageName)
          .toList();
      await platform.invokeMethod('saveDockLayout', {'layout': layoutIds});
    } catch (e) {
      print("Failed to save dock layout: $e");
    }
  }

  void _toggleWidgetInGrid(String widgetId, bool visible) {
    if (visible) {
      final exists = gridApps.any(
        (item) => item is WidgetGridItem && item.widgetId == widgetId,
      );
      if (!exists) {
        final slot = findFirstEmptySlot(gridApps, 2, 2);
        gridApps.add(
          WidgetGridItem(
            widgetId,
            page: slot.page,
            row: slot.row,
            col: slot.col,
          ),
        );
      }
    } else {
      gridApps.removeWhere(
        (item) => item is WidgetGridItem && item.widgetId == widgetId,
      );
    }
    _saveGridLayout();
  }

  void _handleItemDelete(GridItem item) {
    if (item is AppGridItem) {
      _showDeleteConfirmation(item.app);
    } else if (item is WidgetGridItem) {
      setState(() {
        gridApps.removeWhere((g) => g.id == item.id);
        if (item.widgetId == 'clock') {
          _showClockWidget = false;
        } else if (item.widgetId == 'weather') {
          _showWeatherWidget = false;
        } else if (item.widgetId == 'battery') {
          _showBatteryWidget = false;
        }
        _saveWidgetSettings();
        _saveGridLayout();
      });
    }
  }

  Future<void> _checkDefaultLauncher() async {
    try {
      final bool isDefault = await platform.invokeMethod('isDefaultLauncher');
      if (!isDefault && mounted) {
        _showDefaultLauncherDialog();
      }
    } on PlatformException catch (e) {
      print("Failed to check default launcher: '${e.message}'.");
    }
  }

  void _showDefaultLauncherDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (BuildContext context) {
        return Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  width: 270,
                  padding: const EdgeInsets.only(top: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xCC1E1E1E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Đặt làm Màn hình chính mặc định?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Để sử dụng tất cả các tính năng cử chỉ vuốt, thanh Dock và quản lý ứng dụng, hãy đặt iOS Launcher làm màn hình chính mặc định của bạn.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                height: 1.35,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        height: 0.5,
                        color: Colors.white.withOpacity(0.15),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text(
                                'Để sau',
                                style: TextStyle(
                                  color: Color(0xFF0A84FF),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 0.5,
                            height: 44,
                            color: Colors.white.withOpacity(0.15),
                          ),
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () async {
                                Navigator.of(context).pop();
                                try {
                                  await platform.invokeMethod(
                                    'openDefaultLauncherSettings',
                                  );
                                } on PlatformException catch (e) {
                                  print(
                                    "Failed to open launcher settings: '${e.message}'.",
                                  );
                                }
                              },
                              child: const Text(
                                'Thiết lập',
                                style: TextStyle(
                                  color: Color(0xFF0A84FF),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _uninstallApp(String packageName) async {
    try {
      await platform.invokeMethod('uninstallApp', {'packageName': packageName});
    } on PlatformException catch (e) {
      print("Failed to uninstall app: '${e.message}'.");
    }
  }

  void _showDeleteConfirmation(AppInfo app) {
    setState(() {
      _isContextMenuOpen = false;
      _isGlobalDragging = false;
      _activeDragInfo = null;
      _hoveredSlot = null;
    });

    final themeExt = Theme.of(context).extension<LauncherThemeExtension>()!;
    final bgColor = themeExt.dialogBgColor;
    final borderColor = themeExt.borderColor;
    final textColor = themeExt.textColor;
    final subTextColor = themeExt.subTextColor;
    final dividerColor = themeExt.dividerColor;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (BuildContext context) {
        return Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  width: 270,
                  padding: const EdgeInsets.only(top: 20),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor, width: 0.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Xóa "${app.label}"?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Xóa ứng dụng này cũng sẽ xóa tất cả dữ liệu của nó khỏi thiết bị của bạn.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: subTextColor,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(height: 0.5, color: dividerColor),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text(
                                'Hủy',
                                style: TextStyle(
                                  color: Color(0xFF0A84FF),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 0.5,
                            height: 44,
                            color: dividerColor,
                          ),
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                Navigator.of(context).pop();
                                _uninstallApp(app.packageName);
                              },
                              child: const Text(
                                'Xóa',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ).then((_) {
      setState(() {
        _isContextMenuOpen = false;
      });
    });
  }

  void _showAppContextMenu(
    BuildContext context,
    Offset position,
    AppInfo app,
    int globalIndex,
  ) {
    setState(() {
      _isContextMenuOpen = true;
      _isGlobalDragging = false;
      _activeDragInfo = null;
      _hoveredSlot = null;
    });

    final themeExt = Theme.of(context).extension<LauncherThemeExtension>()!;
    final bgColor = themeExt.menuBgColor;
    final borderColor = themeExt.borderColor;
    final textColor = themeExt.textColor;
    final dividerColor = themeExt.dividerColor;

    OverlayState? overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;

        double menuLeft = position.dx;
        double menuTop = position.dy;

        if (menuLeft + 220 > screenWidth) {
          menuLeft = screenWidth - 230;
        }
        if (menuLeft < 10) {
          menuLeft = 10;
        }
        if (menuTop + 110 > screenHeight) {
          menuTop = screenHeight - 120;
        }
        if (menuTop < 10) {
          menuTop = 10;
        }

        return Stack(
          children: [
            GestureDetector(
              onTap: () {
                overlayEntry.remove();
                setState(() {
                  _isContextMenuOpen = false;
                });
              },
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.black.withOpacity(0.2)),
            ),
            Positioned(
              left: menuLeft,
              top: menuTop,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.8, end: 1.0),
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    alignment: Alignment.topLeft,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          width: 220,
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor, width: 0.5),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  overlayEntry.remove();
                                  setState(() {
                                    _isContextMenuOpen = false;
                                    _isEditingMode = true;
                                  });
                                },
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Sửa Màn hình chính',
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w400,
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                      Icon(
                                        Icons.edit,
                                        color: textColor.withOpacity(0.8),
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Container(height: 0.5, color: dividerColor),
                              GestureDetector(
                                onTap: () {
                                  overlayEntry.remove();
                                  setState(() {
                                    _isContextMenuOpen = false;
                                  });
                                  _showDeleteConfirmation(app);
                                },
                                behavior: HitTestBehavior.opaque,
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Xóa ứng dụng',
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w400,
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                      Icon(
                                        Icons.delete_outline,
                                        color: Colors.redAccent,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );

    overlayState.insert(overlayEntry);
  }

  int _calculateTotalPages(List<GridItem> items) {
    if (items.isEmpty) return 1;
    int maxPage = 0;
    for (final item in items) {
      if (item.page > maxPage) {
        maxPage = item.page;
      }
    }
    return maxPage + 1;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_isGlobalDragging) return;

    final dx = event.position.dx;
    final dy = event.position.dy;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Nếu đang kéo ở khu vực dock thì không cho phép chuyển trang
    if (dy > screenHeight - 140) {
      _pageTurnTimer?.cancel();
      return;
    }

    int totalPages = _calculateTotalPages(gridApps);
    if (_isGlobalDragging) {
      totalPages += 1;
    }

    if (dx < 60) {
      if (_pageTurnTimer == null || !_pageTurnTimer!.isActive) {
        _pageTurnTimer = Timer(const Duration(milliseconds: 500), () {
          if (_pageController.page! > 0) {
            _pageController.previousPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        });
      }
    } else if (dx > screenWidth - 60) {
      if (_pageTurnTimer == null || !_pageTurnTimer!.isActive) {
        _pageTurnTimer = Timer(const Duration(milliseconds: 500), () {
          if (_pageController.page! < totalPages - 1) {
            _pageController.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        });
      }
    } else {
      _pageTurnTimer?.cancel();
    }
  }

  Future<bool> _launchApp(String packageName) async {
    try {
      final bool success = await platform.invokeMethod('launchApp', {
        'packageName': packageName,
      });
      return success;
    } on PlatformException catch (e) {
      print("Failed to launch app: '${e.message}'.");
      return false;
    }
  }

  void _animateAppLaunch(AppInfo app, Offset position, Size size) {
    if (_launchingApp != null) return;
    _recordAppLaunch(app.packageName);
    setState(() {
      _launchingApp = app;
      _launchStartBounds = position;
      _launchStartSize = size;
    });
    _launchAnimationController.forward().then((_) async {
      final currentLaunchingApp = _launchingApp;
      Timer(const Duration(milliseconds: 1500), () {
        if (mounted && _launchingApp == currentLaunchingApp) {
          setState(() {
            _launchingApp = null;
            _launchAnimationController.reset();
          });
        }
      });

      final success = await _launchApp(app.packageName);
      if (!success && mounted) {
        setState(() {
          _launchingApp = null;
          _launchAnimationController.reset();
        });
      }
    });
  }

  void _handleDrop(GridDragInfo dragInfo, GridCoordinate targetSlot) {
    _hoverTimer?.cancel();
    _hoverTimer = null;
    setState(() {
      _isGlobalDragging = false;
      _activeDragInfo = null;
      _hoveredSlot = null;

      final dragItem = dragInfo.item;
      int targetRowClamped = targetSlot.row.clamp(0, 6 - dragItem.height);
      int targetColClamped = targetSlot.col.clamp(0, 4 - dragItem.width);

      if (dragInfo.startPage == -1) {
        dockApps.removeWhere((app) => app.packageName == dragItem.id);
        gridApps.add(dragItem);
        dragItem.page = targetSlot.page;
        dragItem.row = targetRowClamped;
        dragItem.col = targetColClamped;
        resolveOverlaps(gridApps, fixedId: dragItem.id);
        _saveDockLayout();
      } else {
        final gridItemIndex = gridApps.indexWhere(
          (item) => item.id == dragItem.id,
        );
        if (gridItemIndex != -1) {
          gridApps[gridItemIndex].page = targetSlot.page;
          gridApps[gridItemIndex].row = targetRowClamped;
          gridApps[gridItemIndex].col = targetColClamped;
          resolveOverlaps(gridApps, fixedId: dragItem.id);
        }
      }
    });
    _saveGridLayout();
    _handleDockLeave();
  }

  void _handleDockHover(GridDragInfo dragInfo, int targetIndex) {
    if (dragInfo.item is! AppGridItem) return;

    if (dragInfo.startPage != -1) {
      bool changed = false;

      if (_displacedDockAppItem == null &&
          dockApps.length == 4 &&
          !dockApps.contains(_dockDummyApp)) {
        final displacedApp = dockApps.removeAt(targetIndex.clamp(0, 3));
        final draggedItem = dragInfo.item as AppGridItem;

        _displacedDockAppItem = AppGridItem(
          displacedApp,
          page: draggedItem.page,
          row: draggedItem.row,
          col: draggedItem.col,
        );
        gridApps.add(_displacedDockAppItem!);

        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final safeAreaTop = MediaQuery.of(context).padding.top;
        final gap = (screenWidth - 32 - 240) / 5;

        // Global dock item position
        final dockGlobalX = 16.0 + gap + targetIndex * (60.0 + gap);
        final dockGlobalY = screenHeight - 110.0;

        // Convert to AppGrid local coordinates
        final startX = dockGlobalX - 22.0;
        final startY = dockGlobalY - (safeAreaTop + 32.0);

        _displacedInitialOffsets = Map.from(_displacedInitialOffsets);
        _displacedInitialOffsets[_displacedDockAppItem!.id] = Offset(
          startX,
          startY,
        );

        changed = true;
      }

      int currentIndex = dockApps.indexOf(_dockDummyApp);
      if (currentIndex != targetIndex) {
        dockApps.remove(_dockDummyApp);
        dockApps.insert(targetIndex.clamp(0, dockApps.length), _dockDummyApp);
        changed = true;
      }

      if (changed) setState(() {});
    } else {
      bool changed = false;
      final draggedAppId = dragInfo.item.id;
      final currentIndex = dockApps.indexWhere(
        (app) => app.packageName == draggedAppId,
      );
      if (currentIndex != -1 && currentIndex != targetIndex) {
        final appToMove = dockApps.removeAt(currentIndex);
        dockApps.insert(targetIndex.clamp(0, dockApps.length), appToMove);
        changed = true;
      }
      if (changed) setState(() {});
    }
  }

  void _handleDockLeave() {
    bool changed = false;
    if (dockApps.contains(_dockDummyApp)) {
      dockApps.remove(_dockDummyApp);
      changed = true;
    }
    if (_displacedDockAppItem != null) {
      final gridPos = _displacedDockAppItem!;
      final screenHeight = MediaQuery.of(context).size.height;
      final safeAreaTop = MediaQuery.of(context).padding.top;

      // Global grid item position
      final gridGlobalX = 22.0 + gridPos.col * 72.0;
      final gridGlobalY = safeAreaTop + 32.0 + gridPos.row * 70.0;

      // Convert to Dock local coordinates
      final startX = gridGlobalX - 16.0;
      final startY = gridGlobalY - (screenHeight - 110.0);

      _dockInitialOffsets = Map.from(_dockInitialOffsets);
      _dockInitialOffsets[gridPos.app.packageName] = Offset(startX, startY);

      gridApps.remove(_displacedDockAppItem);
      dockApps.add(gridPos.app);
      _displacedInitialOffsets = Map.from(_displacedInitialOffsets);
      _displacedInitialOffsets.remove(gridPos.id);
      _displacedDockAppItem = null;
      changed = true;
    }
    if (changed) setState(() {});
  }

  void _handleDockDrop(GridDragInfo dragInfo, int targetIndex) {
    _hoverTimer?.cancel();
    _hoverTimer = null;
    setState(() {
      _isGlobalDragging = false;
      _activeDragInfo = null;
      _hoveredSlot = null;

      if (dragInfo.startPage == -1) {
        final appIndex = dockApps.indexWhere(
          (app) => app.packageName == dragInfo.item.id,
        );
        if (appIndex != -1) {
          final app = dockApps.removeAt(appIndex);
          if (targetIndex > appIndex) {
            targetIndex--;
          }
          dockApps.insert(targetIndex.clamp(0, dockApps.length), app);
        }
      } else {
        if (dragInfo.item is AppGridItem) {
          final app = (dragInfo.item as AppGridItem).app;
          gridApps.removeWhere((item) => item.id == dragInfo.item.id);

          dockApps.remove(_dockDummyApp);

          if (_displacedDockAppItem != null) {
            resolveOverlaps(gridApps);
            _displacedDockAppItem = null;
          } else if (dockApps.length >= 4) {
            final displacedApp = dockApps.removeLast();
            final draggedItem = dragInfo.item as AppGridItem;
            gridApps.add(
              AppGridItem(
                displacedApp,
                page: draggedItem.page,
                row: draggedItem.row,
                col: draggedItem.col,
              ),
            );
            resolveOverlaps(gridApps);
          }

          dockApps.insert(targetIndex.clamp(0, dockApps.length), app);
          _saveGridLayout();
        }
      }
    });
    _saveDockLayout();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final int totalPages = _calculateTotalPages(gridApps);
    final displayTotalPages = _isGlobalDragging ? totalPages + 1 : totalPages;

    return Scaffold(
      body: GestureDetector(
        onTap: () {
          if (_isEditingMode) {
            setState(() {
              _isEditingMode = false;
            });
          }
        },
        onLongPress: () {
          if (!_isEditingMode &&
              !_isContextMenuOpen &&
              !_isGlobalDragging &&
              _launchingApp == null) {
            setState(() {
              _isEditingMode = true;
            });
          }
        },
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // Background Wallpaper
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _launchAnimationController,
                builder: (context, child) {
                  final t = _launchAnimationController.value;
                  final curve = Curves.easeOutCubic.transform(t);
                  final scale = 1.0 - 0.05 * curve;

                  Widget wallpaperWidget;
                  if (_wallpaperType == 'image' &&
                      _wallpaperImagePath != null) {
                    wallpaperWidget = Image.file(
                      File(_wallpaperImagePath!),
                      fit: BoxFit.cover,
                    );
                  } else if (_wallpaperType == 'asset' &&
                      _wallpaperImagePath != null) {
                    wallpaperWidget = Image.asset(
                      _wallpaperImagePath!,
                      fit: BoxFit.cover,
                    );
                  } else {
                    wallpaperWidget = Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_color1, _color2],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    );
                  }

                  return Transform.scale(scale: scale, child: wallpaperWidget);
                },
              ),
            ),

            // Fullscreen Background Blur for App Library
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double blurAmount = 0.0;
                  double tintOpacity = 0.0;
                  if (_pageController.hasClients) {
                    final page = _pageController.page ?? 0.0;
                    final threshold = displayTotalPages - 1;
                    if (page > threshold) {
                      final factor = (page - threshold).clamp(0.0, 1.0);
                      blurAmount = factor * 20.0;
                      tintOpacity = factor * (isDarkMode ? 0.20 : 0.05);
                    }
                  }
                  if (blurAmount == 0.0) {
                    return const SizedBox.shrink();
                  }
                  return ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: blurAmount,
                        sigmaY: blurAmount,
                      ),
                      child: Container(
                        color: Colors.black.withOpacity(tintOpacity),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Main content
            SafeArea(
              child: AnimatedBuilder(
                animation: _launchAnimationController,
                builder: (context, child) {
                  final t = _launchAnimationController.value;
                  final curve = Curves.easeOutCubic.transform(t);
                  final opacity = 1.0 - curve;
                  final scale = 1.0 - 0.03 * curve;
                  return Opacity(
                    opacity: opacity,
                    child: Transform.scale(scale: scale, child: child),
                  );
                },
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    // AppGrid (placed first so it is rendered behind the Dock/Indicators)
                    Positioned.fill(
                      child: Listener(
                        onPointerMove: _handlePointerMove,
                        child: isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              )
                            : AppGrid(
                                gridApps: gridApps,
                                allApps: allApps,
                                launchCounts: _launchCounts,
                                totalPages: displayTotalPages,
                                pageController: _pageController,
                                activeDragInfo: _activeDragInfo,
                                hoveredSlot: _hoveredSlot,
                                isEditingMode: _isEditingMode,
                                isContextMenuOpen: _isContextMenuOpen,
                                dragDelay: dragDelay,
                                popupDelay: popupDelay,
                                onPageChanged: (index) {
                                  setState(() {
                                    _currentPage = index;
                                  });
                                },
                                onAppTap: _animateAppLaunch,
                                onDragStarted: (dragInfo) {
                                  setState(() {
                                    _isGlobalDragging = true;
                                    _activeDragInfo = dragInfo;
                                  });
                                },
                                onDragEnded: () {
                                  _hoverTimer?.cancel();
                                  _hoverTimer = null;
                                  setState(() {
                                    _isGlobalDragging = false;
                                    _activeDragInfo = null;
                                    _hoveredSlot = null;
                                  });
                                  _pageTurnTimer?.cancel();
                                  _saveGridLayout();
                                },
                                onHoverChanged: (slot) {
                                  if (_activeDragInfo == null || slot == null)
                                    return;
                                  if (_hoveredSlot != null &&
                                      _hoveredSlot!.page == slot.page &&
                                      _hoveredSlot!.row == slot.row &&
                                      _hoveredSlot!.col == slot.col) {
                                    return;
                                  }
                                  setState(() {
                                    _hoveredSlot = slot;
                                  });

                                  _hoverTimer?.cancel();
                                  _hoverTimer = Timer(
                                    const Duration(milliseconds: 400),
                                    () {
                                      if (!mounted ||
                                          _activeDragInfo == null ||
                                          _hoveredSlot == null)
                                        return;
                                      setState(() {
                                        final dragItem = _activeDragInfo!.item;
                                        final gridItemIndex = gridApps
                                            .indexWhere(
                                              (item) => item.id == dragItem.id,
                                            );
                                        if (gridItemIndex != -1) {
                                          gridApps[gridItemIndex].page =
                                              _hoveredSlot!.page;
                                          gridApps[gridItemIndex].row =
                                              _hoveredSlot!.row;
                                          gridApps[gridItemIndex].col =
                                              _hoveredSlot!.col;
                                          resolveOverlaps(
                                            gridApps,
                                            fixedId: dragItem.id,
                                          );
                                        }
                                      });
                                    },
                                  );
                                },
                                onDrop: _handleDrop,
                                onAppLongPress: _showAppContextMenu,
                                onItemDeleteTap: _handleItemDelete,
                                forcedInitialOffsets: _displacedInitialOffsets,
                              ),
                      ),
                    ),

                    // Paging indicators
                    if (!isLoading)
                      Positioned(
                        bottom: 118,
                        left: 0,
                        right: 0,
                        child: AnimatedBuilder(
                          animation: _pageController,
                          builder: (context, child) {
                            double opacity = 1.0;
                            if (_pageController.hasClients) {
                              final page = _pageController.page ?? 0.0;
                              final threshold = displayTotalPages - 1;
                              if (page > threshold) {
                                opacity = (1.0 - (page - threshold)).clamp(
                                  0.0,
                                  1.0,
                                );
                              }
                            }
                            return Opacity(opacity: opacity, child: child);
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              displayTotalPages,
                              (index) => Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 16,
                                ),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: index == _currentPage
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Dock
                    if (!isLoading && dockApps.isNotEmpty)
                      Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: AnimatedBuilder(
                          animation: _pageController,
                          builder: (context, child) {
                            double opacity = 1.0;
                            double offsetMultiplier = 0.0;
                            if (_pageController.hasClients) {
                              final page = _pageController.page ?? 0.0;
                              final threshold = displayTotalPages - 1;
                              if (page > threshold) {
                                opacity = (1.0 - (page - threshold)).clamp(
                                  0.0,
                                  1.0,
                                );
                                offsetMultiplier = (page - threshold).clamp(
                                  0.0,
                                  1.0,
                                );
                              }
                            }
                            return Transform.translate(
                              offset: Offset(
                                -MediaQuery.of(context).size.width *
                                    offsetMultiplier,
                                0,
                              ),
                              child: Dock(
                                apps: dockApps,
                                opacity: opacity,
                                onAppTap: _animateAppLaunch,
                                isEditingMode: _isEditingMode,
                                popupDelay: popupDelay,
                                dragDelay: dragDelay,
                                onAppLongPress: _showAppContextMenu,
                                onAppDeleteTap: _showDeleteConfirmation,
                                onDockDragStarted: (dragInfo) {
                                  setState(() {
                                    _isGlobalDragging = true;
                                    _activeDragInfo = dragInfo;
                                  });
                                },
                                onDockDragEnded: () {
                                  _hoverTimer?.cancel();
                                  _hoverTimer = null;
                                  setState(() {
                                    _isGlobalDragging = false;
                                    _activeDragInfo = null;
                                    _hoveredSlot = null;
                                  });
                                  _pageTurnTimer?.cancel();
                                  _saveDockLayout();
                                },
                                onDockDrop: _handleDockDrop,
                                onDockHover: _handleDockHover,
                                onDockLeave: _handleDockLeave,
                                forcedInitialOffsets: _dockInitialOffsets,
                                activeDragInfo: _activeDragInfo,
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),

            if (_isEditingMode)
              Positioned(
                bottom: 120, // Float above the Dock area
                left: 20,
                right: 20,
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.black.withOpacity(0.35)
                              : Colors.white.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.15)
                                : Colors.black.withOpacity(0.15),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildPanelButton(
                              icon: Icons.palette_outlined,
                              label: 'Hình nền',
                              onTap: _showWallpaperSelector,
                              isDarkMode: isDarkMode,
                            ),
                            Container(
                              height: 24,
                              width: 1,
                              color: isDarkMode
                                  ? Colors.white24
                                  : Colors.black26,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                            ),
                            _buildPanelButton(
                              icon: Icons.add_to_home_screen_outlined,
                              label: 'Tiện ích',
                              onTap: _showWidgetSelector,
                              isDarkMode: isDarkMode,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            if (_launchingApp != null)
              AnimatedBuilder(
                animation: _launchAnimationController,
                builder: (context, child) {
                  final t = _launchAnimationController.value;
                  final curve = Curves.easeInOutCubic.transform(t);

                  final screenWidth = MediaQuery.of(context).size.width;
                  final screenHeight = MediaQuery.of(context).size.height;

                  final width = lerpDouble(
                    _launchStartSize!.width,
                    screenWidth,
                    curve,
                  )!;
                  final height = lerpDouble(
                    _launchStartSize!.height,
                    screenHeight,
                    curve,
                  )!;
                  final left = lerpDouble(_launchStartBounds!.dx, 0.0, curve)!;
                  final top = lerpDouble(_launchStartBounds!.dy, 0.0, curve)!;
                  final borderRadius = lerpDouble(14.0, 0.0, curve)!;

                  return Positioned(
                    left: left,
                    top: top,
                    width: width,
                    height: height,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Color.lerp(
                            Colors.transparent,
                            isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
                            curve,
                          ),
                          borderRadius: BorderRadius.circular(borderRadius),
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 60 * lerpDouble(1.0, 2.0, curve)!,
                            height: 60 * lerpDouble(1.0, 2.0, curve)!,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                14 * lerpDouble(1.0, 2.0, curve)!,
                              ),
                              child: _launchingApp!.icon.isNotEmpty
                                  ? Image.memory(
                                      _launchingApp!.icon,
                                      fit: BoxFit.cover,
                                    )
                                  : const Icon(
                                      Icons.android,
                                      color: Colors.grey,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: textColor, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWallpaperSelector() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final themeExt = Theme.of(context).extension<LauncherThemeExtension>()!;
    final bgColor = themeExt.sheetBgColor;
    final textColor = themeExt.textColor;
    final dividerColor = themeExt.dividerColor;
    final borderColor = themeExt.borderColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black38,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                border: Border.all(color: borderColor, width: 0.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: dividerColor,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Thay đổi hình nền',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Màu sắc',
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 120,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                // Gallery Picker Card
                                Builder(
                                  builder: (context) {
                                    final iconBgColor = isDarkMode
                                        ? Colors.white.withOpacity(0.08)
                                        : Colors.black.withOpacity(0.05);
                                    final subTextColor = isDarkMode
                                        ? Colors.white70
                                        : Colors.black54;
                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.pop(context);
                                        _changeWallpaperToGallery();
                                      },
                                      child: Container(
                                        width: 80,
                                        margin: const EdgeInsets.only(
                                          right: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: iconBgColor,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: isDarkMode
                                                ? Colors.white.withOpacity(0.15)
                                                : Colors.black.withOpacity(0.1),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.photo_library_outlined,
                                              color: textColor,
                                              size: 28,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Thư viện',
                                              style: TextStyle(
                                                color: subTextColor,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                _buildGradientOption(
                                  const Color(0xFF1D2671),
                                  const Color(0xFFC33764),
                                  'iOS Classic',
                                ),
                                _buildGradientOption(
                                  const Color(0xFF00B4DB),
                                  const Color(0xFF0083B0),
                                  'Aurora',
                                ),
                                _buildGradientOption(
                                  const Color(0xFFF12711),
                                  const Color(0xFFF5AF19),
                                  'Sunset',
                                ),
                                _buildGradientOption(
                                  const Color(0xFF0F2027),
                                  const Color(0xFF2C5364),
                                  'Midnight',
                                ),
                                _buildGradientOption(
                                  const Color(0xFF11998E),
                                  const Color(0xFF38EF7D),
                                  'Emerald',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Phong cảnh',
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 180,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                _buildAssetOption(
                                  'assets/wallpapers/landscape_1.png',
                                  'Biển',
                                ),
                                _buildAssetOption(
                                  'assets/wallpapers/landscape_2.png',
                                  'Núi',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Cây cối',
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 180,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                _buildAssetOption(
                                  'assets/wallpapers/plant_1.png',
                                  'Hoa',
                                ),
                                _buildAssetOption(
                                  'assets/wallpapers/plant_2.png',
                                  'Trầu bà Nam Mỹ',
                                ),
                                _buildAssetOption(
                                  'assets/wallpapers/plant_3.png',
                                  'Lá dương xỉ',
                                ),
                                _buildAssetOption(
                                  'assets/wallpapers/plant_4.png',
                                  'Hoa Tulip',
                                ),
                                _buildAssetOption(
                                  'assets/wallpapers/plant_5.png',
                                  'Cây trúc',
                                ),
                                _buildAssetOption(
                                  'assets/wallpapers/plant_6.png',
                                  'Oải hương',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Khác',
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 180,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                _buildAssetOption(
                                  'assets/wallpapers/other_1.png',
                                  'Ảnh 1',
                                ),
                                _buildAssetOption(
                                  'assets/wallpapers/other_2.png',
                                  'Ảnh 2',
                                ),
                                _buildAssetOption(
                                  'assets/wallpapers/other_3.png',
                                  'Ảnh 3',
                                ),
                                _buildAssetOption(
                                  'assets/wallpapers/other_4.png',
                                  'Ảnh 4',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGradientOption(Color c1, Color c2, String label) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isSelected =
        _wallpaperType == 'gradient' &&
        _color1.value == c1.value &&
        _color2.value == c2.value;
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _changeWallpaperToGradient(c1, c2);
      },
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0A84FF)
                : (isDarkMode
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.1)),
            width: isSelected ? 2.0 : 0.8,
          ),
          gradient: LinearGradient(
            colors: [c1, c2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssetOption(String assetPath, String label) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isSelected =
        _wallpaperType == 'asset' && _wallpaperImagePath == assetPath;
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _changeWallpaperToAsset(assetPath);
      },
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0A84FF)
                : (isDarkMode
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.1)),
            width: isSelected ? 2.0 : 0.8,
          ),
          image: DecorationImage(
            image: AssetImage(assetPath),
            fit: BoxFit.cover,
          ),
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  void _showWidgetSelector() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final themeExt = Theme.of(context).extension<LauncherThemeExtension>()!;
    final bgColor = themeExt.sheetBgColor;
    final textColor = themeExt.textColor;
    final dividerColor = themeExt.dividerColor;
    final borderColor = themeExt.borderColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black38,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                    border: Border.all(color: borderColor, width: 0.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 5,
                          decoration: BoxDecoration(
                            color: dividerColor,
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Tiện ích màn hình',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildWidgetToggleRow(
                        icon: Icons.access_time_filled,
                        color: Colors.orange,
                        title: 'Đồng hồ',
                        subtitle: 'Hiển thị thời gian và ngày tháng',
                        value: _showClockWidget,
                        onChanged: (val) {
                          setState(() {
                            _showClockWidget = val;
                            _toggleWidgetInGrid('clock', val);
                          });
                          setSheetState(() {
                            _showClockWidget = val;
                          });
                          _saveWidgetSettings();
                        },
                        isDarkMode: isDarkMode,
                      ),
                      Divider(color: dividerColor),
                      _buildWidgetToggleRow(
                        icon: Icons.cloud_queue,
                        color: Colors.blue,
                        title: 'Thời tiết',
                        subtitle: 'Xem thời tiết và nhiệt độ hiện tại',
                        value: _showWeatherWidget,
                        onChanged: (val) {
                          setState(() {
                            _showWeatherWidget = val;
                            _toggleWidgetInGrid('weather', val);
                          });
                          setSheetState(() {
                            _showWeatherWidget = val;
                          });
                          _saveWidgetSettings();
                        },
                        isDarkMode: isDarkMode,
                      ),
                      Divider(color: dividerColor),
                      _buildWidgetToggleRow(
                        icon: Icons.battery_charging_full,
                        color: Colors.green,
                        title: 'Tình trạng pin',
                        subtitle: 'Xem phần trăm pin hiện tại',
                        value: _showBatteryWidget,
                        onChanged: (val) {
                          setState(() {
                            _showBatteryWidget = val;
                            _toggleWidgetInGrid('battery', val);
                          });
                          setSheetState(() {
                            _showBatteryWidget = val;
                          });
                          _saveWidgetSettings();
                        },
                        isDarkMode: isDarkMode,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWidgetToggleRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDarkMode,
  }) {
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = isDarkMode ? Colors.white54 : Colors.black54;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: subTextColor, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: const Color(0xFF0A84FF),
            activeTrackColor: const Color(0xFF0A84FF).withOpacity(0.3),
            inactiveThumbColor: isDarkMode ? Colors.white : Colors.white,
            inactiveTrackColor: isDarkMode ? Colors.white24 : Colors.black12,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
