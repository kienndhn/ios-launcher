import 'package:flutter/material.dart';
import 'liquid_glass_container.dart';

class WeatherWidget extends StatelessWidget {
  const WeatherWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return LiquidGlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      glassColor: Colors.blue.shade400.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'THỜI TIẾT',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              Icon(Icons.cloud_queue, color: Colors.white, size: 16),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Hà Nội',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Text(
            '28°C',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          const Text(
            'Nhiều mây',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                'C:31°',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 10,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'T:24°',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
