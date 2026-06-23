import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/app_info.dart';
import 'app_icon.dart';
import 'wiggle_wrapper.dart';

class Dock extends StatelessWidget {
  final List<AppInfo> apps;
  final Function(AppInfo, Offset, Size) onAppTap;
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
          width: 0.8,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            height: 94,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: apps.map((app) {
                return Expanded(
                  child: Center(
                    child: DockAppGestureDetector(
                      app: app,
                      onAppTap: onAppTap,
                      isEditingMode: isEditingMode,
                      onAppLongPress: onAppLongPress,
                      onAppDeleteTap: onAppDeleteTap,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class DockAppGestureDetector extends StatelessWidget {
  final AppInfo app;
  final Function(AppInfo, Offset, Size) onAppTap;
  final bool isEditingMode;
  final Function(BuildContext, Offset, AppInfo, int) onAppLongPress;
  final Function(AppInfo) onAppDeleteTap;

  const DockAppGestureDetector({
    super.key,
    required this.app,
    required this.onAppTap,
    required this.isEditingMode,
    required this.onAppLongPress,
    required this.onAppDeleteTap,
  });

  @override
  Widget build(BuildContext context) {
    return WiggleWrapper(
      isWiggling: isEditingMode,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTapDown: (_) {},
            onTap: isEditingMode
                ? null
                : () {
                    final renderBox = context.findRenderObject() as RenderBox?;
                    if (renderBox != null) {
                      final pos = renderBox.localToGlobal(Offset.zero);
                      final size = renderBox.size;
                      onAppTap(app, pos, size);
                    }
                  },
            onLongPressStart: isEditingMode
                ? null
                : (details) {
                    onAppLongPress(context, details.globalPosition, app, -1);
                  },
            child: SizedBox(
              width: 60,
              height: 60,
              child: AppIcon(
                app: app,
                showLabel: false,
              ),
            ),
          ),
          if (isEditingMode)
            Positioned(
              top: -2,
              left: -2,
              child: GestureDetector(
                onTap: () => onAppDeleteTap(app),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E5EA),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
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
  }
}
