import 'dart:ui';
import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/app_info.dart';
import '../models/grid_item.dart';
import 'app_icon.dart';
import 'wiggle_wrapper.dart';
import 'liquid_glass_container.dart';

class Dock extends StatefulWidget {
  final List<AppInfo> apps;
  final Function(AppInfo, Offset, Size) onAppTap;
  final bool isEditingMode;
  final Duration popupDelay;
  final Duration dragDelay;
  final Function(BuildContext, Offset, AppInfo, int) onAppLongPress;
  final Function(AppInfo) onAppDeleteTap;
  final Function(GridDragInfo) onDockDragStarted;
  final VoidCallback onDockDragEnded;
  final Function(GridDragInfo, int) onDockDrop;
  final Function(GridDragInfo, int) onDockHover;
  final VoidCallback onDockLeave;
  final Map<String, Offset>? forcedInitialOffsets;
  final GridDragInfo? activeDragInfo;
  final double opacity;

  const Dock({
    Key? key,
    required this.apps,
    required this.onAppTap,
    required this.isEditingMode,
    required this.popupDelay,
    required this.dragDelay,
    required this.onAppLongPress,
    required this.onAppDeleteTap,
    required this.onDockDragStarted,
    required this.onDockDragEnded,
    required this.onDockDrop,
    required this.onDockHover,
    required this.onDockLeave,
    this.forcedInitialOffsets,
    this.activeDragInfo,
    this.opacity = 1.0,
  }) : super(key: key);

  @override
  State<Dock> createState() => _DockState();
}

class _DockState extends State<Dock> {
  final Map<String, Offset> _tempDropPositions = {};

  @override
  void initState() {
    super.initState();
    if (widget.forcedInitialOffsets != null) {
      _tempDropPositions.addAll(widget.forcedInitialOffsets!);
    }
  }

  @override
  void didUpdateWidget(covariant Dock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.forcedInitialOffsets != null) {
      widget.forcedInitialOffsets!.forEach((key, value) {
        if (oldWidget.forcedInitialOffsets?[key] == null) {
          _tempDropPositions[key] = value;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 94,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: LiquidGlassContainer(
              borderRadius: 30,
              padding: EdgeInsets.zero,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned.fill(
            child: DragTarget<GridDragInfo>(
              onWillAcceptWithDetails: (details) {
                final isApp = details.data.item is AppGridItem;
                if (!isApp) return false;
                return true;
              },
              onMove: (details) {
                final RenderBox renderBox =
                    context.findRenderObject() as RenderBox;
                final localOffset = renderBox.globalToLocal(details.offset);
                final width = renderBox.size.width;
                final dropZoneWidth = width / 4;
                int index = (localOffset.dx / dropZoneWidth).floor().clamp(
                  0,
                  widget.apps.length,
                );
                widget.onDockHover(details.data, index);
              },
              onLeave: (data) {
                widget.onDockLeave();
              },
              onAcceptWithDetails: (details) {
                final RenderBox renderBox =
                    context.findRenderObject() as RenderBox;
                final localOffset = renderBox.globalToLocal(details.offset);
                final width = renderBox.size.width;
                final dropZoneWidth = width / 4;
                int index = (localOffset.dx / dropZoneWidth).floor().clamp(
                  0,
                  widget.apps.length,
                );
                widget.onDockDrop(details.data, index);
              },
              builder: (context, candidateData, rejectedData) {
                return Opacity(
                  opacity: widget.opacity,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final isDisplacing = widget.apps.length > 4;
                        final n = isDisplacing ? 4 : widget.apps.length;
                        final gap = n == 0 ? 0.0 : (width - n * 60) / (n + 1);

                        return Stack(
                          clipBehavior: Clip.none,
                          children: widget.apps.asMap().entries.map((entry) {
                            final index = entry.key;
                            final app = entry.value;

                            int visualIndex = index;
                            bool isDisplaced = false;

                            if (isDisplacing &&
                                index == widget.apps.length - 1) {
                              isDisplaced = true;
                              visualIndex = 3;
                            }

                            final left =
                                (visualIndex + 1) * gap + visualIndex * 60;
                            double top = 0;
                            double opacity = 1.0;
                            final bool isBeingDragged =
                                widget.activeDragInfo != null &&
                                widget.activeDragInfo!.item.id ==
                                    app.packageName;

                            if (isDisplaced) {
                              top = -120;
                              opacity = 0.0;
                            }

                            final Offset? tempOffset =
                                _tempDropPositions[app.packageName];
                            final double finalLeft = tempOffset != null
                                ? tempOffset.dx
                                : left;
                            final double finalTop = tempOffset != null
                                ? tempOffset.dy
                                : top;
                            final Duration animationDuration =
                                tempOffset != null
                                ? Duration.zero
                                : const Duration(milliseconds: 350);

                            if (tempOffset != null) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  setState(() {
                                    _tempDropPositions.remove(app.packageName);
                                  });
                                }
                              });
                            }

                            if (app.packageName == 'dock_dummy') {
                              return AnimatedPositioned(
                                key: const ValueKey('dock_dummy'),
                                duration: animationDuration,
                                curve: Curves.easeOutCubic,
                                left: finalLeft,
                                top: finalTop,
                                bottom: -finalTop,
                                width: 60,
                                child: const SizedBox(width: 60, height: 60),
                              );
                            }

                            return AnimatedPositioned(
                              key: ValueKey(app.packageName),
                              duration: animationDuration,
                              curve: Curves.easeOutCubic,
                              left: finalLeft,
                              top: finalTop,
                              bottom: -finalTop,
                              width: 60,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 250),
                                opacity: opacity,
                                child: Center(
                                  child: DockAppGestureDetector(
                                    app: app,
                                    index: index,
                                    onAppTap: widget.onAppTap,
                                    isEditingMode: widget.isEditingMode,
                                    popupDelay: widget.popupDelay,
                                    dragDelay: widget.dragDelay,
                                    onAppLongPress: widget.onAppLongPress,
                                    onAppDeleteTap: widget.onAppDeleteTap,
                                    onDockDragStarted: widget.onDockDragStarted,
                                    onDockDragEnded: widget.onDockDragEnded,
                                    isBeingDragged: isBeingDragged,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class DockAppGestureDetector extends StatefulWidget {
  final AppInfo app;
  final int index;
  final Function(AppInfo, Offset, Size) onAppTap;
  final bool isEditingMode;
  final Duration popupDelay;
  final Duration dragDelay;
  final Function(BuildContext, Offset, AppInfo, int) onAppLongPress;
  final Function(AppInfo) onAppDeleteTap;
  final Function(GridDragInfo) onDockDragStarted;
  final VoidCallback onDockDragEnded;
  final bool isBeingDragged;

  const DockAppGestureDetector({
    super.key,
    required this.app,
    required this.index,
    required this.onAppTap,
    required this.isEditingMode,
    required this.popupDelay,
    required this.dragDelay,
    required this.onAppLongPress,
    required this.onAppDeleteTap,
    required this.onDockDragStarted,
    required this.onDockDragEnded,
    required this.isBeingDragged,
  });

  @override
  State<DockAppGestureDetector> createState() => _DockAppGestureDetectorState();
}

class _DockAppGestureDetectorState extends State<DockAppGestureDetector> {
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
    final dragInfo = GridDragInfo(
      globalIndex: -1,
      item: AppGridItem(widget.app, page: -1, row: -1, col: -1),
      startPage: -1,
    );

    Widget childWidget = SizedBox(
      width: 60,
      height: 60,
      child: AppIcon(app: widget.app, showLabel: false),
    );

    Widget content = Listener(
      onPointerDown: (event) {
        _currentPointerPosition = event.position;
        _activePointerId = event.pointer;
      },
      onPointerMove: (event) {
        _currentPointerPosition = event.position;
      },
      child: LongPressDraggable<GridDragInfo>(
        data: dragInfo,
        maxSimultaneousDrags: 1,
        delay: widget.isEditingMode ? Duration.zero : widget.dragDelay,
        feedback: Material(
          type: MaterialType.transparency,
          child: Transform.rotate(
            angle: 0.05,
            child: Transform.scale(scale: 1.1, child: childWidget),
          ),
        ),
        childWhenDragging: const SizedBox(width: 60, height: 60),
        onDragStarted: () {
          widget.onDockDragStarted(dragInfo);
          if (!widget.isEditingMode) {
            _popupTimer?.cancel();
            _popupTimer = Timer(widget.popupDelay - widget.dragDelay, () {
              _popupTimer = null;
              if (_activePointerId != null) {
                GestureBinding.instance.cancelPointer(_activePointerId!);
                _activePointerId = null;
              }
              widget.onAppLongPress(
                context,
                _currentPointerPosition,
                widget.app,
                -1,
              );
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
          widget.onDockDragEnded();
        },
        child: Opacity(
          opacity: widget.isBeingDragged ? 0.0 : 1.0,
          child: Builder(
            builder: (context) => GestureDetector(
              onTap: widget.isEditingMode
                  ? () {}
                  : () {
                      final renderBox =
                          context.findRenderObject() as RenderBox?;
                      if (renderBox != null) {
                        final pos = renderBox.localToGlobal(Offset.zero);
                        final size = renderBox.size;
                        widget.onAppTap(widget.app, pos, size);
                      }
                    },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  childWidget,
                  if (widget.isEditingMode)
                    Positioned(
                      top: -2,
                      left: -2,
                      child: GestureDetector(
                        onTap: () => widget.onAppDeleteTap(widget.app),
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
            ),
          ),
        ),
      ),
    );

    return WiggleWrapper(isWiggling: widget.isEditingMode, child: content);
  }
}
