import 'app_info.dart';

abstract class GridItem {
  String get id;
  String get label;
  int get width;
  int get height;

  int get page;
  set page(int value);

  int get row;
  set row(int value);

  int get col;
  set col(int value);
}

class AppGridItem implements GridItem {
  final AppInfo app;

  @override
  int page;
  @override
  int row;
  @override
  int col;

  AppGridItem(this.app, {this.page = 0, this.row = 0, this.col = 0});

  @override
  String get id => app.packageName;

  @override
  String get label => app.label;

  @override
  int get height => 1;

  @override
  int get width => 1;
}

class WidgetGridItem implements GridItem {
  final String widgetId; // 'clock', 'weather', 'battery'

  @override
  int page;
  @override
  int row;
  @override
  int col;

  WidgetGridItem(this.widgetId, {this.page = 0, this.row = 0, this.col = 0});

  @override
  String get id => widgetId;

  @override
  String get label {
    switch (widgetId) {
      case 'clock':
        return 'Đồng hồ';
      case 'weather':
        return 'Thời tiết';
      case 'battery':
        return 'Pin';
      default:
        return 'Tiện ích';
    }
  }

  @override
  int get height => 2;

  @override
  int get width => 2;
}

class GridDragInfo {
  final int globalIndex;
  final GridItem item;
  final int startPage;

  GridDragInfo({required this.globalIndex, required this.item, required this.startPage});
}

class PackedItem {
  final GridItem item;
  final int page;
  final int row;
  final int col;

  PackedItem({
    required this.item,
    required this.page,
    required this.row,
    required this.col,
  });
}
