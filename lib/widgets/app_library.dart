import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ios_launcher/models/app_info.dart';
import 'package:ios_launcher/utils/theme.dart';
import 'app_icon.dart';
import 'liquid_glass_container.dart';

class AppLibrary extends StatefulWidget {
  final List<AppInfo> apps;
  final Map<String, int> launchCounts;
  final Function(AppInfo, Offset, Size) onAppTap;

  const AppLibrary({
    super.key,
    required this.apps,
    required this.launchCounts,
    required this.onAppTap,
  });

  @override
  State<AppLibrary> createState() => _AppLibraryState();
}

class _AppLibraryState extends State<AppLibrary> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _expandedCategory;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, List<AppInfo>> _getCategoryMap() {
    final Map<String, List<AppInfo>> categories = {
      'Gợi ý': [],
      'Mạng xã hội': [],
      'Giải trí': [],
      'Tài chính': [],
      'Tiện ích': [],
      'Khác': [],
    };

    // 1. Identify common apps for Suggestions (Sorted by launchCount first)
    final List<AppInfo> suggestions = [];

    // Sort all apps by launch count descending
    final List<AppInfo> sortedApps = List.from(widget.apps);
    sortedApps.sort((a, b) {
      final countA = widget.launchCounts[a.packageName] ?? 0;
      final countB = widget.launchCounts[b.packageName] ?? 0;
      return countB.compareTo(countA); // Descending
    });

    // Take apps that have been launched at least once
    for (final app in sortedApps) {
      final count = widget.launchCounts[app.packageName] ?? 0;
      if (count > 0) {
        suggestions.add(app);
        if (suggestions.length >= 4) break;
      }
    }

    // If suggestions are fewer than 4, fill with default common apps
    if (suggestions.length < 4) {
      final suggestionPkgNames = [
        'com.android.chrome',
        'com.android.browser',
        'org.mozilla.firefox',
        'com.apple.mobilesafari',
        'com.android.vending',
        'com.apple.appstore',
        'com.zing.zalo',
        'com.facebook.katana',
        'com.facebook.orca',
        'com.google.android.youtube',
        'com.spotify.music',
        'com.netflix.mediaclient',
        'com.zhiliaoapp.musically',
        'com.apple.music',
      ];

      for (final pkg in suggestionPkgNames) {
        final app = widget.apps.firstWhere(
          (a) => a.packageName.toLowerCase().contains(pkg) || a.packageName.toLowerCase() == pkg,
          orElse: () => AppInfo(packageName: '', label: '', icon: Uint8List(0)),
        );
        if (app.packageName.isNotEmpty && !suggestions.any((s) => s.packageName == app.packageName)) {
          suggestions.add(app);
          if (suggestions.length >= 4) break;
        }
      }
    }

    // Still fewer than 4? Fill with remaining apps
    if (suggestions.length < 4) {
      for (final app in widget.apps) {
        if (!suggestions.any((s) => s.packageName == app.packageName)) {
          suggestions.add(app);
          if (suggestions.length >= 4) break;
        }
      }
    }
    categories['Gợi ý'] = suggestions;

    // 2. Classify all apps into categories
    for (final app in widget.apps) {
      final label = app.label.toLowerCase();
      final pkg = app.packageName.toLowerCase();

      // check Finance (Tài chính) first so that zalopay/shopeepay aren't miscategorized as Social
      if (pkg.contains('bank') ||
          pkg.contains('momo') ||
          pkg.contains('vnpay') ||
          pkg.contains('zalopay') ||
          pkg.contains('shopeepay') ||
          pkg.contains('viettelpay') ||
          pkg.contains('pay') ||
          pkg.contains('wallet') ||
          pkg.contains('finance') ||
          pkg.contains('timo') ||
          pkg.contains('vcb') ||
          pkg.contains('acb') ||
          pkg.contains('bidv') ||
          pkg.contains('tpb') ||
          pkg.contains('mbb') ||
          pkg.contains('vib') ||
          pkg.contains('techcom') ||
          label.contains('tài chính') ||
          label.contains('ví') ||
          label.contains('ngân hàng') ||
          label.contains('momo') ||
          label.contains('pay') ||
          label.contains('tiền')) {
        categories['Tài chính']!.add(app);
      } else if (pkg.contains('zalo') ||
          pkg.contains('facebook') ||
          pkg.contains('messenger') ||
          pkg.contains('instagram') ||
          pkg.contains('tiktok') ||
          pkg.contains('whatsapp') ||
          pkg.contains('telegram') ||
          pkg.contains('twitter') ||
          pkg.contains('snapchat') ||
          pkg.contains('viber') ||
          pkg.contains('discord') ||
          label.contains('zalo') ||
          label.contains('facebook') ||
          label.contains('messenger') ||
          label.contains('instagram') ||
          label.contains('tiktok') ||
          label.contains('tin nhắn') ||
          label.contains('viber') ||
          label.contains('discord')) {
        categories['Mạng xã hội']!.add(app);
      } else if (pkg.contains('youtube') ||
          pkg.contains('netflix') ||
          pkg.contains('spotify') ||
          pkg.contains('music') ||
          pkg.contains('nhac') ||
          pkg.contains('sing') ||
          pkg.contains('game') ||
          pkg.contains('video') ||
          pkg.contains('play') ||
          label.contains('youtube') ||
          label.contains('netflix') ||
          label.contains('spotify') ||
          label.contains('nhạc') ||
          label.contains('music') ||
          label.contains('trò chơi') ||
          label.contains('game') ||
          label.contains('video') ||
          label.contains('nghe nhạc')) {
        categories['Giải trí']!.add(app);
      } else if (pkg.contains('setting') ||
          pkg.contains('camera') ||
          pkg.contains('weather') ||
          pkg.contains('clock') ||
          pkg.contains('calendar') ||
          pkg.contains('map') ||
          pkg.contains('calculator') ||
          pkg.contains('phone') ||
          pkg.contains('contact') ||
          pkg.contains('gallery') ||
          pkg.contains('photo') ||
          pkg.contains('file') ||
          pkg.contains('download') ||
          pkg.contains('browser') ||
          pkg.contains('safari') ||
          pkg.contains('store') ||
          label.contains('cài đặt') ||
          label.contains('máy ảnh') ||
          label.contains('thời tiết') ||
          label.contains('đồng hồ') ||
          label.contains('lịch') ||
          label.contains('bản đồ') ||
          label.contains('máy tính') ||
          label.contains('điện thoại') ||
          label.contains('danh bạ') ||
          label.contains('ảnh') ||
          label.contains('tệp') ||
          label.contains('safari') ||
          label.contains('cửa hàng') ||
          label.contains('chợ')) {
        categories['Tiện ích']!.add(app);
      } else {
        categories['Khác']!.add(app);
      }
    }

    // Clean up empty categories (except Suggestions)
    categories.removeWhere((key, value) => value.isEmpty && key != 'Gợi ý');

    return categories;
  }

  @override
  Widget build(BuildContext context) {
    final themeExt = Theme.of(context).extension<LauncherThemeExtension>()!;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final categories = _getCategoryMap();
    final List<AppInfo> filteredApps = widget.apps
        .where((app) => app.label.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Stack(
      children: [
        // App Library Layout
        SafeArea(
          child: Column(
            children: [
              // Search Bar
              Container(
                margin: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                height: 44,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.03),
                    width: 0.5,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  style: TextStyle(color: themeExt.textColor, fontSize: 16),
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.search,
                      color: themeExt.textColor.withOpacity(0.5),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                            child: Icon(
                              Icons.cancel,
                              color: themeExt.textColor.withOpacity(0.5),
                            ),
                          )
                        : null,
                    hintText: 'Thư viện Ứng dụng',
                    hintStyle: TextStyle(
                      color: themeExt.textColor.withOpacity(0.7),
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),

              // Categories or Search Results
              Expanded(
                child: _searchQuery.isNotEmpty
                    ? _buildSearchResults(filteredApps, themeExt)
                    : _buildCategoriesGrid(categories, themeExt, isDarkMode),
              ),
            ],
          ),
        ),

        // Expanded Folder Overlay
        if (_expandedCategory != null)
          _buildFolderOverlay(
            _expandedCategory!,
            categories[_expandedCategory!] ?? [],
            themeExt,
            isDarkMode,
          ),
      ],
    );
  }

  Widget _buildSearchResults(List<AppInfo> apps, LauncherThemeExtension themeExt) {
    if (apps.isEmpty) {
      return Center(
        child: Text(
          'Không tìm thấy ứng dụng',
          style: TextStyle(color: themeExt.textColor.withOpacity(0.6), fontSize: 16),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 20,
        childAspectRatio: 0.75,
      ),
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final app = apps[index];
        return AppIcon(
          app: app,
          showLabel: true,
          onTap: () {
            // Get screen tap position for zoom animations
            final renderBox = context.findRenderObject() as RenderBox?;
            final size = renderBox?.size ?? const Size(60, 60);
            final position = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
            widget.onAppTap(app, position, size);
          },
        );
      },
    );
  }

  Widget _buildCategoriesGrid(
    Map<String, List<AppInfo>> categories,
    LauncherThemeExtension themeExt,
    bool isDarkMode,
  ) {
    final keys = categories.keys.toList();

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 167 / 195,
      ),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        final catName = keys[index];
        final catApps = categories[catName] ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Category Card (Square 167x167px approx)
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: LiquidGlassContainer(
                  padding: const EdgeInsets.all(12),
                  glassColor: isDarkMode
                      ? const Color(0x10FFFFFF)
                      : const Color(0x08000000),
                  child: _buildCategoryItemGrid(catName, catApps, context),
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Label below the Card
            Text(
              catName,
              style: TextStyle(
                fontSize: 12,
                color: themeExt.textColor.withOpacity(0.9),
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryItemGrid(
    String categoryName,
    List<AppInfo> apps,
    BuildContext context,
  ) {
    final hasMiniFolder = apps.length > 4;
    final displayCount = hasMiniFolder ? 3 : apps.length;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: hasMiniFolder ? 4 : displayCount,
      itemBuilder: (context, index) {
        if (hasMiniFolder && index == 3) {
          // Render Mini Folder Grid representing apps from index 3 onwards
          return GestureDetector(
            onTap: () {
              setState(() {
                _expandedCategory = categoryName;
              });
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(6),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: (apps.length - 3).clamp(1, 4),
                itemBuilder: (ctx, subIndex) {
                  final app = apps[subIndex + 3];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: app.icon.isNotEmpty
                        ? Image.memory(app.icon, fit: BoxFit.cover)
                        : Container(color: Colors.grey),
                  );
                },
              ),
            ),
          );
        }

        final app = apps[index];
        return AppIcon(
          app: app,
          showLabel: false,
          onTap: () {
            final renderBox = context.findRenderObject() as RenderBox?;
            final size = renderBox?.size ?? const Size(60, 60);
            final position = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
            widget.onAppTap(app, position, size);
          },
        );
      },
    );
  }

  Widget _buildFolderOverlay(
    String categoryName,
    List<AppInfo> apps,
    LauncherThemeExtension themeExt,
    bool isDarkMode,
  ) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _expandedCategory = null;
        });
      },
      child: Container(
        color: Colors.black45,
        width: double.infinity,
        height: double.infinity,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Center(
            child: GestureDetector(
              onTap: () {}, // Prevent tap through
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                height: MediaQuery.of(context).size.height * 0.6,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.black.withOpacity(0.5)
                      : Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.08),
                    width: 0.5,
                  ),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Close Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          categoryName,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: themeExt.textColor,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _expandedCategory = null;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDarkMode
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.black.withOpacity(0.05),
                            ),
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              Icons.close,
                              color: themeExt.textColor,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Grid of Apps
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: apps.length,
                        itemBuilder: (context, index) {
                          final app = apps[index];
                          return AppIcon(
                            app: app,
                            showLabel: true,
                            onTap: () {
                              setState(() {
                                _expandedCategory = null;
                              });
                              final renderBox = context.findRenderObject() as RenderBox?;
                              final size = renderBox?.size ?? const Size(60, 60);
                              final position = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
                              widget.onAppTap(app, position, size);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
