import 'package:flutter/material.dart';
import 'package:ios_launcher/utils/bottom_sheet_container.dart';

class WidgetSelector extends StatelessWidget {
  const WidgetSelector({super.key});

  static Future<void> showWidgetSelector(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      builder: (context) => const WidgetSelector(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomSheetContainer(child: const Placeholder());
  }
}
