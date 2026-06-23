import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BatteryWidget extends StatefulWidget {
  const BatteryWidget({super.key});

  @override
  State<BatteryWidget> createState() => _BatteryWidgetState();
}

class _BatteryWidgetState extends State<BatteryWidget> {
  int _batteryLevel = 100;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _updateBatteryLevel();
    _timer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _updateBatteryLevel();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _updateBatteryLevel() async {
    try {
      const platform = MethodChannel('com.example.ios_launcher/apps');
      final int level = await platform.invokeMethod('getBatteryLevel');
      if (mounted) {
        setState(() {
          _batteryLevel = level;
        });
      }
    } catch (e) {
      print("Failed to get battery level: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCharging = _batteryLevel < 100;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PIN',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const Spacer(),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    value: _batteryLevel / 100.0,
                    strokeWidth: 6,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _batteryLevel > 20
                          ? Colors.green.shade400
                          : Colors.red.shade400,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_batteryLevel%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isCharging)
                      const Icon(Icons.bolt, color: Colors.green, size: 12),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            _batteryLevel > 20 ? 'Bình thường' : 'Pin yếu',
            style: TextStyle(
              color: _batteryLevel > 20 ? Colors.white70 : Colors.redAccent,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
