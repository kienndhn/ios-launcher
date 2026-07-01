import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/app_info.dart';
import '../models/grid_item.dart';
import '../utils/grid_utils.dart';
import 'app_icon.dart';
import 'wiggle_wrapper.dart';
import 'clock_widget.dart';
import 'weather_widget.dart';
import 'battery_widget.dart';
import 'app_library.dart';

class AppGrid extends StatelessWidget {
  final List<GridItem> gridApps;
  final List<AppInfo> allApps;
  final Map<String, int> launchCounts;
  final int totalPages;
  final PageController pageController;
  final GridDragInfo? activeDragInfo;
  final GridCoordinate? hoveredSlot;
  final bool isEditingMode;
  final bool isContextMenuOpen;
  final Duration dragDelay;
  final Duration popupDelay;
  final Function(int) onPageChanged;
  final Function(AppInfo, Offset, Size) onAppTap;
  final Function(GridDragInfo) onDragStarted;
  final VoidCallback onDragEnded;
  final Function(GridCoordinate?) onHoverChanged;
  final Function(GridDragInfo, GridCoordinate) onDrop;
  final Function(BuildContext, Offset, AppInfo, int) onAppLongPress;
  final Function(GridItem) onItemDeleteTap;
  final Map<String, Offset>? forcedInitialOffsets;

  const AppGrid({
    super.key,
    required this.gridApps,
    required this.allApps,
    required this.launchCounts,
    required this.totalPages,
    required this.pageController,
    required this.activeDragInfo,
    required this.hoveredSlot,
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
    required this.onItemDeleteTap,
    this.forcedInitialOffsets,
  });

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      clipBehavior: Clip.none,
      controller: pageController,
      onPageChanged: onPageChanged,
      physics: activeDragInfo != null
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(),
      itemCount: isEditingMode ? totalPages : totalPages + 1,
      itemBuilder: (context, pageIndex) {
        if (pageIndex == totalPages) {
          return AppLibrary(
            apps: allApps,
            launchCounts: launchCounts,
            onAppTap: onAppTap,
          );
        }
        return _AppGridPage(
          pageIndex: pageIndex,
          gridApps: gridApps,
          activeDragInfo: activeDragInfo,
          hoveredSlot: hoveredSlot,
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
          onItemDeleteTap: onItemDeleteTap,
          forcedInitialOffsets: forcedInitialOffsets,
        );
      },
    );
  }
}

class _AppGridPage extends StatefulWidget {
  final int pageIndex;
  final List<GridItem> gridApps;
  final GridDragInfo? activeDragInfo;
  final GridCoordinate? hoveredSlot;
  final bool isEditingMode;
  final bool isContextMenuOpen;
  final Duration dragDelay;
  final Duration popupDelay;
  final Function(AppInfo, Offset, Size) onAppTap;
  final Function(GridDragInfo) onDragStarted;
  final VoidCallback onDragEnded;
  final Function(GridCoordinate?) onHoverChanged;
  final Function(GridDragInfo, GridCoordinate) onDrop;
  final Function(BuildContext, Offset, AppInfo, int) onAppLongPress;
  final Function(GridItem) onItemDeleteTap;
  final Map<String, Offset>? forcedInitialOffsets;

  const _AppGridPage({
    required this.pageIndex,
    required this.gridApps,
    required this.activeDragInfo,
    required this.hoveredSlot,
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
    required this.onItemDeleteTap,
    this.forcedInitialOffsets,
  });

  @override
  State<_AppGridPage> createState() => _AppGridPageState();
}

class _AppGridPageState extends State<_AppGridPage> with AutomaticKeepAliveClientMixin {
  Timer? _popupTimer;
  Offset _currentPointerPosition = Offset.zero;
  int? _activePointerId;
  final Map<String, Offset> _tempDropPositions = {};
  int _touchColOffset = 0;
  int _touchRowOffset = 0;

  @override
  void initState() {
    super.initState();
    if (widget.forcedInitialOffsets != null) {
      _tempDropPositions.addAll(widget.forcedInitialOffsets!);
    }
  }

  @override
  void didUpdateWidget(covariant _AppGridPage oldWidget) {
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
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _popupTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final gridWidth = screenWidth - 44;
    final cellWidth = (gridWidth - 3 * 12) / 4;
    final cellHeight = cellWidth + 8;

    // Lọc ra các vật thể thuộc trang hiện tại (giữ vật thể đang kéo ở trang bắt đầu)
    final pageItems = widget.gridApps.where((item) {
      final isDraggedItem = widget.activeDragInfo?.item.id == item.id;
      if (isDraggedItem) {
        return widget.activeDragInfo!.startPage == widget.pageIndex;
      }
      return item.page == widget.pageIndex;
    }).toList();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 1. Lưới tĩnh nhận sự kiện thả (Background Grid DragTargets)
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.only(
              left: 22,
              right: 22,
              top: 32,
              bottom: 130,
            ),
            child: GridView.count(
              crossAxisCount: 4,
              childAspectRatio: cellWidth / cellHeight,
              crossAxisSpacing: 12,
              mainAxisSpacing: 10,
              physics: const NeverScrollableScrollPhysics(),
              children: List.generate(24, (localIndex) {
                final cellRow = localIndex ~/ 4;
                final cellCol = localIndex % 4;

                // Kiểm tra xem ô này có nằm trong vùng bao xem trước của vật thể đang kéo hay không
                bool isHighlighted = false;
                if (widget.activeDragInfo != null &&
                    widget.hoveredSlot != null &&
                    widget.hoveredSlot!.page == widget.pageIndex) {
                  final dragItem = widget.activeDragInfo!.item;
                  final hRow = widget.hoveredSlot!.row;
                  final hCol = widget.hoveredSlot!.col;

                  if (cellRow >= hRow &&
                      cellRow < hRow + dragItem.height &&
                      cellCol >= hCol &&
                      cellCol < hCol + dragItem.width) {
                    isHighlighted = true;
                  }
                }

                return DragTarget<GridDragInfo>(
                  onWillAcceptWithDetails: (details) {
                    final targetRow = (cellRow - _touchRowOffset).clamp(0, 6 - details.data.item.height);
                    final targetCol = (cellCol - _touchColOffset).clamp(0, 4 - details.data.item.width);
                    widget.onHoverChanged(GridCoordinate(widget.pageIndex, targetRow, targetCol));
                    return true;
                  },
                  onLeave: (data) {
                    // Khi rời khỏi ô, ta không vội xóa hover nếu vật thể vẫn đang di chuyển trong trang.
                  },
                  onAcceptWithDetails: (details) {
                    final targetRow = (cellRow - _touchRowOffset).clamp(0, 6 - details.data.item.height);
                    final targetCol = (cellCol - _touchColOffset).clamp(0, 4 - details.data.item.width);

                    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
                    if (renderBox != null) {
                      final localOffset = renderBox.globalToLocal(details.offset);
                      setState(() {
                        _tempDropPositions[details.data.item.id] = localOffset;
                      });
                    }

                    widget.onDrop(details.data, GridCoordinate(widget.pageIndex, targetRow, targetCol));
                  },
                  builder: (context, candidateData, rejectedData) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: isHighlighted
                            ? Border.all(
                                color: Colors.white.withOpacity(0.8),
                                width: 2.5,
                              )
                            : (widget.activeDragInfo != null
                                ? Border.all(
                                    color: Colors.white.withOpacity(0.15),
                                    width: 1.5,
                                  )
                                : null),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ),

        // 2. Các vật thể hiển thị nổi lên trên (Foreground grid)
        ...pageItems.map((item) {
          final left = 22.0 + item.col * (cellWidth + 12);

          // Nếu là 1x1 thì lấy cellHeight, nếu là 2x2 thì lấy width để tạo thành hình vuông hoàn hảo
          final width = item.width * cellWidth + (item.width - 1) * 12;
          final height = item.height == 1 ? cellHeight : width;

          final cellAreaHeight = item.height * cellHeight + (item.height - 1) * 10;
          final topOffset = (cellAreaHeight - height) / 2;
          final top = 32.0 + item.row * (cellHeight + 10) + topOffset;

          final globalIndex = widget.gridApps.indexWhere((g) => g.id == item.id);
          if (globalIndex == -1) return const SizedBox.shrink();

          final isBeingDragged = widget.activeDragInfo?.item.id == item.id;

          Widget childWidget;
          Widget feedbackWidget;
          if (item is AppGridItem) {
            childWidget = AppIcon(app: item.app);
            feedbackWidget = childWidget;
          } else {
            final widgetId = (item as WidgetGridItem).widgetId;
            if (widgetId == 'clock') {
              childWidget = const ClockWidget();
              feedbackWidget = const ClockWidget(isFeedback: true);
            } else if (widgetId == 'weather') {
              childWidget = const WeatherWidget();
              feedbackWidget = const WeatherWidget(isFeedback: true);
            } else {
              childWidget = const BatteryWidget();
              feedbackWidget = const BatteryWidget(isFeedback: true);
            }
          }

          childWidget = Container(
            color: Colors.transparent,
            child: childWidget,
          );

          final currentChild = widget.isContextMenuOpen
              ? Opacity(
                  opacity: isBeingDragged ? 0.0 : 1.0,
                  child: Builder(
                    builder: (context) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.isEditingMode
                          ? () {}
                          : () {
                              if (item is AppGridItem) {
                                final renderBox = context.findRenderObject() as RenderBox?;
                                if (renderBox != null) {
                                  final pos = renderBox.localToGlobal(Offset.zero);
                                  final size = renderBox.size;
                                  widget.onAppTap(item.app, pos, size);
                                }
                              }
                            },
                      child: childWidget,
                    ),
                  ),
                )
              : Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (event) {
                    _currentPointerPosition = event.position;
                    _activePointerId = event.pointer;

                    final colOffset = (event.localPosition.dx / (cellWidth + 12)).floor();
                    final rowOffset = (event.localPosition.dy / (cellHeight + 10)).floor();
                    _touchColOffset = colOffset.clamp(0, item.width - 1);
                    _touchRowOffset = rowOffset.clamp(0, item.height - 1);
                  },
                  onPointerMove: (event) {
                    _currentPointerPosition = event.position;
                  },
                  child: LongPressDraggable<GridDragInfo>(
                    data: GridDragInfo(globalIndex: globalIndex, item: item, startPage: widget.pageIndex),
                    maxSimultaneousDrags: 1,
                    delay: widget.isEditingMode ? Duration.zero : widget.dragDelay,
                    feedback: Material(
                      type: MaterialType.transparency,
                      child: Transform.rotate(
                        angle: 0.05,
                        child: Transform.scale(
                          scale: 1.1,
                          child: SizedBox(
                            width: width,
                            height: height,
                            child: feedbackWidget,
                          ),
                        ),
                      ),
                    ),
                    childWhenDragging: const SizedBox.shrink(),
                    onDragStarted: () {
                      widget.onDragStarted(GridDragInfo(globalIndex: globalIndex, item: item, startPage: widget.pageIndex));
                      if (!widget.isEditingMode && item is AppGridItem) {
                        _popupTimer?.cancel();
                        _popupTimer = Timer(widget.popupDelay - widget.dragDelay, () {
                          _popupTimer = null;
                          if (_activePointerId != null) {
                            GestureBinding.instance.cancelPointer(_activePointerId!);
                            _activePointerId = null;
                          }
                          widget.onAppLongPress(context, _currentPointerPosition, item.app, globalIndex);
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
                      child: Builder(
                        builder: (context) => GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: widget.isEditingMode
                              ? () {}
                              : () {
                                  if (item is AppGridItem) {
                                    final renderBox = context.findRenderObject() as RenderBox?;
                                    if (renderBox != null) {
                                      final pos = renderBox.localToGlobal(Offset.zero);
                                      final size = renderBox.size;
                                      widget.onAppTap(item.app, pos, size);
                                    }
                                  }
                                },
                          child: childWidget,
                        ),
                      ),
                    ),
                  ),
                );

          final cellChild = WiggleWrapper(
            isWiggling: widget.isEditingMode,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(child: currentChild),
                if (widget.isEditingMode && !isBeingDragged)
                  Positioned(
                    top: -2,
                    left: -2,
                    child: GestureDetector(
                      onTap: () => widget.onItemDeleteTap(item),
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

          final Offset? tempOffset = _tempDropPositions[item.id];
          final double finalLeft = tempOffset != null ? tempOffset.dx : left;
          final double finalTop = tempOffset != null ? tempOffset.dy : top;
          final Duration animationDuration = tempOffset != null ? Duration.zero : const Duration(milliseconds: 300);

          if (tempOffset != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _tempDropPositions.remove(item.id);
                });
              }
            });
          }

          return AnimatedPositioned(
            key: ValueKey(item.id),
            duration: animationDuration,
            curve: Curves.easeOutCubic,
            left: finalLeft,
            top: finalTop,
            width: width,
            height: height,
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
