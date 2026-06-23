import 'package:flutter/material.dart';
import 'package:ios_launcher/models/app_info.dart';

class AppIcon extends StatelessWidget {
  final AppInfo app;
  final VoidCallback? onTap;
  final bool showLabel;

  const AppIcon({
    super.key,
    required this.app,
    this.onTap,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final iconColumn = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: app.icon.isNotEmpty
                ? Image.memory(
                    app.icon,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Icon(Icons.android, color: Colors.grey, size: 40),
                  )
                : Icon(Icons.android, color: Colors.grey, size: 40),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 6),
          Text(
            app.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );

    final centeredIconColumn = Center(child: iconColumn);
    if (onTap == null) {
      return centeredIconColumn;
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: iconColumn,
    );
  }
}
