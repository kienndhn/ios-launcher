import 'dart:ui';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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

class _HomeScreenState extends State<HomeScreen> {
  static const platform = MethodChannel('com.example.ios_launcher/apps');
  List<AppInfo> dockApps = [];
  List<AppInfo?> gridApps = [];
  bool isLoading = true;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  bool _isGlobalDragging = false;
  AppDragInfo? _activeDragInfo;
  int? _hoveredGlobalIndex;
  Timer? _pageTurnTimer;

  @override
  void initState() {
    super.initState();
    _loadApps();
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
      body: Stack(
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
                  Dock(apps: dockApps, onAppTap: _launchApp),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
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
  final Function(int) onPageChanged;
  final Function(String) onAppTap;
  final Function(AppDragInfo) onDragStarted;
  final VoidCallback onDragEnded;
  final Function(int?) onHoverChanged;
  final Function(AppDragInfo, int) onDrop;

  const AppGrid({
    super.key,
    required this.gridApps,
    required this.pageController,
    required this.activeDragInfo,
    required this.hoveredGlobalIndex,
    required this.onPageChanged,
    required this.onAppTap,
    required this.onDragStarted,
    required this.onDragEnded,
    required this.onHoverChanged,
    required this.onDrop,
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
          onAppTap: onAppTap,
          onDragStarted: onDragStarted,
          onDragEnded: onDragEnded,
          onHoverChanged: onHoverChanged,
          onDrop: onDrop,
        );
      },
    );
  }
}

class _AppGridPage extends StatelessWidget {
  final int pageIndex;
  final List<AppInfo?> gridApps;
  final AppDragInfo? activeDragInfo;
  final int? hoveredGlobalIndex;
  final Function(String) onAppTap;
  final Function(AppDragInfo) onDragStarted;
  final VoidCallback onDragEnded;
  final Function(int?) onHoverChanged;
  final Function(AppDragInfo, int) onDrop;

  const _AppGridPage({
    required this.pageIndex,
    required this.gridApps,
    required this.activeDragInfo,
    required this.hoveredGlobalIndex,
    required this.onAppTap,
    required this.onDragStarted,
    required this.onDragEnded,
    required this.onHoverChanged,
    required this.onDrop,
  });

  @override
  Widget build(BuildContext context) {
    final int startIndex = pageIndex * 24;

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
                    onHoverChanged(globalIndex);
                    return true;
                  },
                  onLeave: (data) {
                    if (hoveredGlobalIndex == globalIndex) {
                      onHoverChanged(null);
                    }
                  },
                  onAcceptWithDetails: (details) {
                    onDrop(details.data, globalIndex);
                  },
                  builder: (context, candidateData, rejectedData) {
                    final isHovered = hoveredGlobalIndex == globalIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: activeDragInfo != null
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
          if (globalIndex >= gridApps.length) return const SizedBox.shrink();
          final app = gridApps[globalIndex];
          if (app == null) return const SizedBox.shrink();

          final row = localIndex ~/ 4;
          final col = localIndex % 4;
          final left = 22.0 + col * (cellWidth + 12);
          final top = 32.0 + row * (cellHeight + 10);

          final isBeingDragged = activeDragInfo?.app.packageName == app.packageName;

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
              child: isBeingDragged
                  ? const SizedBox.shrink()
                  : LongPressDraggable<AppDragInfo>(
                      data: AppDragInfo(globalIndex: globalIndex, app: app),
                      maxSimultaneousDrags: 1,
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
                      onDragStarted: () => onDragStarted(
                        AppDragInfo(globalIndex: globalIndex, app: app),
                      ),
                      onDragEnd: (details) => onDragEnded(),
                      child: AppIcon(
                        app: app,
                        onTap: () => onAppTap(app.packageName),
                      ),
                    ),
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

  const Dock({super.key, required this.apps, required this.onAppTap});

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
                return AppIcon(
                  app: app,
                  onTap: () => onAppTap(app.packageName),
                  showLabel: false,
                );
              }).toList(),
            ),
          ),
        ),
      ),
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
