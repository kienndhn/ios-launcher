import 'package:flutter/material.dart';

class BottomSheetContainer extends StatelessWidget {
  final Widget child;
  const BottomSheetContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(28),
        topRight: Radius.circular(28),
      ),
      child: child,
    );
  }
}
