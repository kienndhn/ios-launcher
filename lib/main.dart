import 'dart:ui';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.top]);
  runApp(const IOSLauncherApp());
}

class IOSLauncherApp extends StatelessWidget {
  const IOSLauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iOS Launcher',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const platform = MethodChannel('com.example.ios_launcher/apps');
  
  // Configurable hold delays
  static const Duration dragDelay = Duration(milliseconds: 500);
  static const Duration popupDelay = Duration(milliseconds: 1000); // Always dragDelay * 2

  List<AppInfo> dockApps = [];
  List<AppInfo?> gridApps = [];
  bool isLoading = true;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  bool _isGlobalDragging = false;
  AppDragInfo? _activeDragInfo;
  int? _hoveredGlobalIndex;
  Timer? _pageTurnTimer;
  bool _isEditingMode = false;
  bool _isContextMenuOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadApps();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadApps();
    }
  }

  Future<void> _loadApps() async {
    try {
      final List<dynamic> result = await platform.invokeMethod(
        'getInstalledApps',
      );
      setState(() {
        final List<AppInfo> loaded = result.map((app) {
          final map = app as Map<dynamic, dynamic>;
          return AppInfo(
            packageName: map['packageName'] as String,
            label: map['label'] as String,
            icon: map['icon'] as Uint8List,
          );
        }).toList();

        if (loaded.length >= 4) {
          dockApps = loaded.sublist(0, 4);
          gridApps = List<AppInfo?>.from(loaded.sublist(4));
        } else {
          dockApps = loaded;
          gridApps = [];
        }

        _padGridApps();
        isLoading = false;
      });

      // Kiểm tra trạng thái mặc định của launcher sau khi tải ứng dụng xong
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
                    color: const Color(0xCC1E1E1E), // iOS Dark Alert Background
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
                                padding: const EdgeInsets.symmetric(vertical: 12),
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
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () async {
                                Navigator.of(context).pop();
                                try {
                                  await platform.invokeMethod('openDefaultLauncherSettings');
                                } on PlatformException catch (e) {
                                  print("Failed to open launcher settings: '${e.message}'.");
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
      _isContextMenuOpen = true;
      _isGlobalDragging = false;
      _activeDragInfo = null;
      _hoveredGlobalIndex = null;
    });
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
                    color: const Color(0xCC1E1E1E), // iOS Alert Dark
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
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Xóa "${app.label}"?',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Xóa ứng dụng này cũng sẽ xóa tất cả dữ liệu của nó khỏi thiết bị của bạn.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 13,
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
                                padding: const EdgeInsets.symmetric(vertical: 12),
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
                            color: Colors.white.withOpacity(0.15),
                          ),
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
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

  void _showAppContextMenu(BuildContext context, Offset position, AppInfo app, int globalIndex) {
    setState(() {
      _isContextMenuOpen = true;
      _isGlobalDragging = false;
      _activeDragInfo = null;
      _hoveredGlobalIndex = null;
    });
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
              child: Container(
                color: Colors.black.withOpacity(0.2),
              ),
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
                            color: const Color(0xCC252525),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 0.5,
                            ),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Sửa Màn hình chính',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w400,
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                      Icon(
                                        Icons.edit,
                                        color: Colors.white.withOpacity(0.8),
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Container(
                                height: 0.5,
                                color: Colors.white.withOpacity(0.1),
                              ),
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
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

  void _padGridApps() {
    int remainder = gridApps.length % 24;
    if (remainder != 0 || gridApps.isEmpty) {
      int fillCount = 24 - remainder;
      for (int i = 0; i < fillCount; i++) {
        gridApps.add(null);
      }
    }
  }

  void _cleanUpTrailingEmptyPages() {
    while (gridApps.length > 24) {
      bool lastPageIsEmpty = true;
      int lastPageStartIndex = gridApps.length - 24;
      for (int i = lastPageStartIndex; i < gridApps.length; i++) {
        if (gridApps[i] != null) {
          lastPageIsEmpty = false;
          break;
        }
      }
      if (lastPageIsEmpty) {
        gridApps.removeRange(lastPageStartIndex, gridApps.length);
      } else {
        break;
      }
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_isGlobalDragging) return;

    final dx = event.position.dx;
    final screenWidth = MediaQuery.of(context).size.width;
    final int totalPages = gridApps.length ~/ 24;

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
          } else {
            // Drag to right edge on last page -> Add new page dynamically
            setState(() {
              for (int i = 0; i < 24; i++) {
                gridApps.add(null);
              }
            });
            Future.delayed(const Duration(milliseconds: 100), () {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            });
          }
        });
      }
    } else {
      _pageTurnTimer?.cancel();
    }
  }

  Future<void> _launchApp(String packageName) async {
    try {
      await platform.invokeMethod('launchApp', {'packageName': packageName});
    } on PlatformException catch (e) {
      print("Failed to launch app: '${e.message}'.");
    }
  }

  void _handleDrop(AppDragInfo dragInfo, int targetGlobalIndex) {
    setState(() {
      _isGlobalDragging = false;
      _activeDragInfo = null;
      _hoveredGlobalIndex = null;
      _cleanUpTrailingEmptyPages();
    });
  }

  @override
  Widget build(BuildContext context) {
    final int totalPages = gridApps.isEmpty ? 1 : (gridApps.length ~/ 24);

    return Scaffold(
      body: GestureDetector(
        onTap: () {
          if (_isEditingMode) {
            setState(() {
              _isEditingMode = false;
            });
          }
        },
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // Background Wallpaper
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1D2671), Color(0xFFC33764)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),

            // Main content
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: Listener(
                      onPointerMove: _handlePointerMove,
                      child: isLoading
                          ? const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            )
                          : AppGrid(
                              gridApps: gridApps,
                              pageController: _pageController,
                              activeDragInfo: _activeDragInfo,
                              hoveredGlobalIndex: _hoveredGlobalIndex,
                              isEditingMode: _isEditingMode,
                              isContextMenuOpen: _isContextMenuOpen,
                              dragDelay: dragDelay,
                              popupDelay: popupDelay,
                              onPageChanged: (index) {
                                setState(() {
                                  _currentPage = index;
                                });
                              },
                              onAppTap: _launchApp,
                              onDragStarted: (dragInfo) {
                                setState(() {
                                  _isGlobalDragging = true;
                                  _activeDragInfo = dragInfo;
                                });
                              },
                              onDragEnded: () {
                                setState(() {
                                  _isGlobalDragging = false;
                                  _activeDragInfo = null;
                                  _hoveredGlobalIndex = null;
                                  _cleanUpTrailingEmptyPages();
                                });
                                _pageTurnTimer?.cancel();
                              },
                              onHoverChanged: (targetGlobalIndex) {
                                if (targetGlobalIndex == null || _activeDragInfo == null) {
                                  setState(() {
                                    _hoveredGlobalIndex = null;
                                  });
                                  return;
                                }
                                
                                final sourceGlobalIndex = _activeDragInfo!.globalIndex;
                                if (sourceGlobalIndex != targetGlobalIndex) {
                                  setState(() {
                                    // Perform reordering shift
                                    final app = gridApps.removeAt(sourceGlobalIndex);
                                    gridApps.insert(targetGlobalIndex, app);
                                    
                                    // Update index of active dragging app
                                    _activeDragInfo = AppDragInfo(
                                      globalIndex: targetGlobalIndex,
                                      app: _activeDragInfo!.app,
                                    );
                                    _hoveredGlobalIndex = targetGlobalIndex;
                                  });
                                } else {
                                  setState(() {
                                    _hoveredGlobalIndex = targetGlobalIndex;
                                  });
                                }
                              },
                              onDrop: _handleDrop,
                              onAppLongPress: _showAppContextMenu,
                              onAppDeleteTap: _showDeleteConfirmation,
                            ),
                    ),
                  ),

                  // Paging indicators
                  if (!isLoading)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        totalPages,
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

                  // Dock
                  if (!isLoading && dockApps.isNotEmpty)
                    Dock(
                      apps: dockApps,
                      onAppTap: _launchApp,
                      isEditingMode: _isEditingMode,
                      popupDelay: popupDelay,
                      onAppLongPress: _showAppContextMenu,
                      onAppDeleteTap: _showDeleteConfirmation,
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppDragInfo {
  final int globalIndex;
  final AppInfo app;

  AppDragInfo({required this.globalIndex, required this.app});
}

class AppGrid extends StatelessWidget {
  final List<AppInfo?> gridApps;
  final PageController pageController;
  final AppDragInfo? activeDragInfo;
  final int? hoveredGlobalIndex;
  final bool isEditingMode;
  final bool isContextMenuOpen;
  final Duration dragDelay;
  final Duration popupDelay;
  final Function(int) onPageChanged;
  final Function(String) onAppTap;
  final Function(AppDragInfo) onDragStarted;
  final VoidCallback onDragEnded;
  final Function(int?) onHoverChanged;
  final Function(AppDragInfo, int) onDrop;
  final Function(BuildContext, Offset, AppInfo, int) onAppLongPress;
  final Function(AppInfo) onAppDeleteTap;

  const AppGrid({
    super.key,
    required this.gridApps,
    required this.pageController,
    required this.activeDragInfo,
    required this.hoveredGlobalIndex,
    required this.isEditingMode,
    required this.isContextMenuOpen,
    required this.dragDelay,
    required this.popupDelay,
    required this.onPageChanged,
    required this.onAppTap,
    required this.onDragStarted,
    required this.onDragEnded,
    required this.onHoverChanged,
    required this.onDrop,
    required this.onAppLongPress,
    required this.onAppDeleteTap,
  });

  @override
  Widget build(BuildContext context) {
    final int pageCount = gridApps.length ~/ 24;

    return PageView.builder(
      controller: pageController,
      onPageChanged: onPageChanged,
      physics: activeDragInfo != null
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(),
      itemCount: pageCount == 0 ? 1 : pageCount,
      itemBuilder: (context, pageIndex) {
        return _AppGridPage(
          pageIndex: pageIndex,
          gridApps: gridApps,
          activeDragInfo: activeDragInfo,
          hoveredGlobalIndex: hoveredGlobalIndex,
          isEditingMode: isEditingMode,
          isContextMenuOpen: isContextMenuOpen,
          dragDelay: dragDelay,
          popupDelay: popupDelay,
          onAppTap: onAppTap,
          onDragStarted: onDragStarted,
          onDragEnded: onDragEnded,
          onHoverChanged: onHoverChanged,
          onDrop: onDrop,
          onAppLongPress: onAppLongPress,
          onAppDeleteTap: onAppDeleteTap,
        );
      },
    );
  }
}

class _AppGridPage extends StatefulWidget {
  final int pageIndex;
  final List<AppInfo?> gridApps;
  final AppDragInfo? activeDragInfo;
  final int? hoveredGlobalIndex;
  final bool isEditingMode;
  final bool isContextMenuOpen;
  final Duration dragDelay;
  final Duration popupDelay;
  final Function(String) onAppTap;
  final Function(AppDragInfo) onDragStarted;
  final VoidCallback onDragEnded;
  final Function(int?) onHoverChanged;
  final Function(AppDragInfo, int) onDrop;
  final Function(BuildContext, Offset, AppInfo, int) onAppLongPress;
  final Function(AppInfo) onAppDeleteTap;

  const _AppGridPage({
    required this.pageIndex,
    required this.gridApps,
    required this.activeDragInfo,
    required this.hoveredGlobalIndex,
    required this.isEditingMode,
    required this.isContextMenuOpen,
    required this.dragDelay,
    required this.popupDelay,
    required this.onAppTap,
    required this.onDragStarted,
    required this.onDragEnded,
    required this.onHoverChanged,
    required this.onDrop,
    required this.onAppLongPress,
    required this.onAppDeleteTap,
  });

  @override
  State<_AppGridPage> createState() => _AppGridPageState();
}

class _AppGridPageState extends State<_AppGridPage> {
  Timer? _popupTimer;
  Offset _currentPointerPosition = Offset.zero;
  int? _activePointerId;

  @override
  void dispose() {
    _popupTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int startIndex = widget.pageIndex * 24;

    final screenWidth = MediaQuery.of(context).size.width;
    final gridWidth = screenWidth - 44; // 22 * 2 padding
    final cellWidth = (gridWidth - 3 * 12) / 4;
    final cellHeight = cellWidth / 0.85;

    return Stack(
      children: [
        // 1. Static DragTargets (Background grid)
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.only(
              left: 22,
              right: 22,
              top: 32,
              bottom: 0,
            ),
            child: GridView.count(
              crossAxisCount: 4,
              childAspectRatio: 0.85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 10,
              physics: const NeverScrollableScrollPhysics(),
              children: List.generate(24, (localIndex) {
                final globalIndex = startIndex + localIndex;
                return DragTarget<AppDragInfo>(
                  onWillAcceptWithDetails: (details) {
                    widget.onHoverChanged(globalIndex);
                    return true;
                  },
                  onLeave: (data) {
                    if (widget.hoveredGlobalIndex == globalIndex) {
                      widget.onHoverChanged(null);
                    }
                  },
                  onAcceptWithDetails: (details) {
                    widget.onDrop(details.data, globalIndex);
                  },
                  builder: (context, candidateData, rejectedData) {
                    final isHovered = widget.hoveredGlobalIndex == globalIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: widget.activeDragInfo != null
                            ? Border.all(
                                color: isHovered
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.15),
                                width: isHovered ? 2.5 : 1.5,
                              )
                            : null,
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ),

        // 2. Animated Positioned Apps (Foreground grid)
        ...List.generate(24, (localIndex) {
          final globalIndex = startIndex + localIndex;
          if (globalIndex >= widget.gridApps.length) return const SizedBox.shrink();
          final app = widget.gridApps[globalIndex];
          if (app == null) return const SizedBox.shrink();

          final row = localIndex ~/ 4;
          final col = localIndex % 4;
          final left = 22.0 + col * (cellWidth + 12);
          final top = 32.0 + row * (cellHeight + 10);

          final isBeingDragged = widget.activeDragInfo?.app.packageName == app.packageName;

          final appWidget = AppIcon(
            app: app,
            onTap: widget.isEditingMode ? () {} : () => widget.onAppTap(app.packageName),
          );

          final currentChild = widget.isContextMenuOpen
              ? Opacity(
                  opacity: isBeingDragged ? 0.0 : 1.0,
                  child: GestureDetector(
                    onTap: widget.isEditingMode ? () {} : () => widget.onAppTap(app.packageName),
                    child: appWidget,
                  ),
                )
              : Listener(
                  onPointerDown: (event) {
                    _currentPointerPosition = event.position;
                    _activePointerId = event.pointer;
                  },
                  onPointerMove: (event) {
                    _currentPointerPosition = event.position;
                  },
                  child: LongPressDraggable<AppDragInfo>(
                    data: AppDragInfo(globalIndex: globalIndex, app: app),
                    maxSimultaneousDrags: 1,
                    delay: widget.isEditingMode ? Duration.zero : widget.dragDelay,
                    feedback: Material(
                      type: MaterialType.transparency,
                      child: Transform.rotate(
                        angle: 0.05,
                        child: Transform.scale(
                          scale: 1.1,
                          child: AppIcon(
                            app: app,
                            onTap: () {},
                          ),
                        ),
                      ),
                    ),
                    childWhenDragging: const SizedBox.shrink(),
                    onDragStarted: () {
                      widget.onDragStarted(AppDragInfo(globalIndex: globalIndex, app: app));
                      if (!widget.isEditingMode) {
                        _popupTimer?.cancel();
                        _popupTimer = Timer(widget.popupDelay - widget.dragDelay, () {
                          _popupTimer = null;
                          if (_activePointerId != null) {
                            GestureBinding.instance.cancelPointer(_activePointerId!);
                            _activePointerId = null;
                          }
                          widget.onAppLongPress(context, _currentPointerPosition, app, globalIndex);
                        });
                      }
                    },
                    onDragUpdate: (details) {
                      if (details.delta.dx.abs() > 1 || details.delta.dy.abs() > 1) {
                        _popupTimer?.cancel();
                        _popupTimer = null;
                      }
                    },
                    onDraggableCanceled: (velocity, offset) {},
                    onDragEnd: (details) {
                      _popupTimer?.cancel();
                      _popupTimer = null;
                      widget.onDragEnded();
                    },
                    child: Opacity(
                      opacity: isBeingDragged ? 0.0 : 1.0,
                      child: GestureDetector(
                        onTap: widget.isEditingMode ? () {} : () => widget.onAppTap(app.packageName),
                        child: appWidget,
                      ),
                    ),
                  ),
                );

          final cellChild = WiggleWrapper(
            isWiggling: widget.isEditingMode,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                currentChild,
                if (widget.isEditingMode && !isBeingDragged)
                  Positioned(
                    top: -2,
                    left: -2,
                    child: GestureDetector(
                      onTap: () => widget.onAppDeleteTap(app),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E5EA),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.remove,
                          color: Color(0xFF3A3A3C),
                          size: 14,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );

          return AnimatedPositioned(
            key: ValueKey(app.packageName),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            left: left,
            top: top,
            width: cellWidth,
            height: cellHeight,
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: cellChild,
            ),
          );
        }),
      ],
    );
  }
}

class Dock extends StatelessWidget {
  final List<AppInfo> apps;
  final Function(String) onAppTap;
  final bool isEditingMode;
  final Duration popupDelay;
  final Function(BuildContext, Offset, AppInfo, int) onAppLongPress;
  final Function(AppInfo) onAppDeleteTap;

  const Dock({
    super.key,
    required this.apps,
    required this.onAppTap,
    required this.isEditingMode,
    required this.popupDelay,
    required this.onAppLongPress,
    required this.onAppDeleteTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(34),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: apps.map((app) {
                final appWidget = AppIcon(
                  app: app,
                  onTap: isEditingMode ? () {} : () => onAppTap(app.packageName),
                  showLabel: false,
                );

                final wiggledApp = WiggleWrapper(
                  isWiggling: isEditingMode,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      appWidget,
                      if (isEditingMode)
                        Positioned(
                          top: -2,
                          left: -2,
                          child: GestureDetector(
                            onTap: () => onAppDeleteTap(app),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5E5EA),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.remove,
                                color: Color(0xFF3A3A3C),
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );

                return isEditingMode
                    ? wiggledApp
                    : DockAppGestureDetector(
                        popupDelay: popupDelay,
                        onShowPopup: (position) {
                          onAppLongPress(context, position, app, -1);
                        },
                        onTap: () => onAppTap(app.packageName),
                        child: wiggledApp,
                      );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class DockAppGestureDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Function(Offset) onShowPopup;
  final Duration popupDelay;

  const DockAppGestureDetector({
    super.key,
    required this.child,
    required this.onTap,
    required this.onShowPopup,
    required this.popupDelay,
  });

  @override
  State<DockAppGestureDetector> createState() => _DockAppGestureDetectorState();
}

class _DockAppGestureDetectorState extends State<DockAppGestureDetector> {
  Timer? _timer;
  Offset? _startPosition;
  bool _moved = false;
  bool _fired = false;
  int? _activePointerId;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        _moved = false;
        _fired = false;
        _startPosition = event.position;
        _activePointerId = event.pointer;
        _timer?.cancel();
        _timer = Timer(widget.popupDelay, () {
          if (!_moved && mounted) {
            _fired = true;
            if (_activePointerId != null) {
              GestureBinding.instance.cancelPointer(_activePointerId!);
              _activePointerId = null;
            }
            widget.onShowPopup(event.position);
          }
        });
      },
      onPointerMove: (event) {
        if (_startPosition != null) {
          final distance = (event.position - _startPosition!).distance;
          if (distance > 15) {
            _moved = true;
            _timer?.cancel();
          }
        }
      },
      onPointerUp: (event) {
        _timer?.cancel();
        if (!_moved && !_fired) {
          widget.onTap();
        }
      },
      onPointerCancel: (event) {
        _timer?.cancel();
      },
      child: widget.child,
    );
  }
}

class AppIcon extends StatelessWidget {
  final AppInfo app;
  final VoidCallback onTap;
  final bool showLabel;

  const AppIcon({
    super.key,
    required this.app,
    required this.onTap,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: app.icon.isNotEmpty
                  ? Image.memory(
                      app.icon,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.android, color: Colors.grey, size: 40),
                    )
                  : const Icon(Icons.android, color: Colors.grey, size: 40),
            ),
          ),
          if (showLabel) ...[
            const SizedBox(height: 6),
            Text(
              app.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                shadows: [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 2,
                    color: Colors.black87,
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class AppInfo {
  final String packageName;
  final String label;
  final Uint8List icon;

  AppInfo({required this.packageName, required this.label, required this.icon});
}

class WiggleWrapper extends StatefulWidget {
  final Widget child;
  final bool isWiggling;

  const WiggleWrapper({super.key, required this.child, required this.isWiggling});

  @override
  State<WiggleWrapper> createState() => _WiggleWrapperState();
}

class _WiggleWrapperState extends State<WiggleWrapper> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    if (widget.isWiggling) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(WiggleWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isWiggling && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isWiggling && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final angle = (widget.isWiggling)
            ? (0.015 * (0.5 - _controller.value))
            : 0.0;
        final dy = (widget.isWiggling)
            ? (0.8 * (0.5 - _controller.value).abs())
            : 0.0;

        return Transform(
          transform: Matrix4.identity()
            ..rotateZ(angle)
            ..translate(0.0, dy, 0.0),
          alignment: Alignment.center,
          child: widget.child,
        );
      },
    );
  }
}
