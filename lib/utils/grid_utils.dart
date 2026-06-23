import '../models/grid_item.dart';

class GridCoordinate {
  final int page;
  final int row;
  final int col;
  GridCoordinate(this.page, this.row, this.col);
}

/// Kiểm tra xem một vùng ô lưới (width x height) tại tọa độ (page, row, col) có bị chiếm dụng bởi vật thể khác hay không.
bool isCellOccupied(
  List<GridItem> items,
  int page,
  int row,
  int col,
  int width,
  int height, {
  String? excludeId,
}) {
  // Giới hạn biên của lưới (4x6)
  if (row < 0 || row + height > 6 || col < 0 || col + width > 4) {
    return true;
  }

  for (final item in items) {
    if (excludeId != null && item.id == excludeId) continue;
    if (item.page == page) {
      // Vùng bao của vật thể hiện tại trên lưới
      final itemLeft = item.col;
      final itemRight = item.col + item.width;
      final itemTop = item.row;
      final itemBottom = item.row + item.height;

      // Vùng bao của tọa độ mới cần kiểm tra
      final newLeft = col;
      final newRight = col + width;
      final newTop = row;
      final newBottom = row + height;

      // Kiểm tra va chạm (overlap) giữa hai hình chữ nhật
      final overlapX = newLeft < itemRight && newRight > itemLeft;
      final overlapY = newTop < itemBottom && newBottom > itemTop;

      if (overlapX && overlapY) {
        return true;
      }
    }
  }
  return false;
}

/// Tìm ô trống đầu tiên có thể chứa một vật thể với kích thước (width x height).
GridCoordinate findFirstEmptySlot(
  List<GridItem> items,
  int width,
  int height, {
  int startPage = 0,
  String? excludeId,
}) {
  int page = startPage;
  while (true) {
    for (int r = 0; r <= 6 - height; r++) {
      for (int c = 0; c <= 4 - width; c++) {
        if (!isCellOccupied(items, page, r, c, width, height, excludeId: excludeId)) {
          return GridCoordinate(page, r, c);
        }
      }
    }
    page++;
  }
}

/// Giải quyết các trường hợp va chạm tọa độ trong danh sách, ưu tiên giữ nguyên vị trí của vật thể có ID là fixedId.
void resolveOverlaps(List<GridItem> items, {String? fixedId}) {
  final List<GridItem> resolved = [];

  // Tạo bản sao danh sách để xử lý
  final listToResolve = List<GridItem>.from(items);

  // Đưa vật thể cố định (vừa được thả) lên đầu để được ưu tiên chiếm chỗ trước
  if (fixedId != null) {
    final fixedIndex = listToResolve.indexWhere((item) => item.id == fixedId);
    if (fixedIndex != -1) {
      final fixedItem = listToResolve.removeAt(fixedIndex);
      listToResolve.insert(0, fixedItem);
    }
  } else {
    // Sắp xếp mặc định theo thứ tự vị trí hiển thị
    listToResolve.sort((a, b) {
      if (a.page != b.page) return a.page.compareTo(b.page);
      if (a.row != b.row) return a.row.compareTo(b.row);
      return a.col.compareTo(b.col);
    });
  }

  for (final item in listToResolve) {
    // Nếu là vật thể cố định hoặc ô lưới còn trống, đưa vào danh sách kết quả
    if (item.id == fixedId || !isCellOccupied(resolved, item.page, item.row, item.col, item.width, item.height)) {
      resolved.add(item);
    } else {
      // Nếu va chạm, tìm ô trống gần nhất để xếp vật thể bị đè vào
      final emptySlot = findFirstEmptySlot(resolved, item.width, item.height, startPage: item.page);
      item.page = emptySlot.page;
      item.row = emptySlot.row;
      item.col = emptySlot.col;
      resolved.add(item);
    }
  }

  // Đồng bộ lại danh sách gốc
  items.clear();
  items.addAll(resolved);
}
