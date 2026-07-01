import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/weather_service.dart';
import 'liquid_glass_container.dart';

/// Possible states the WeatherWidget can be in.
enum _WidgetState { checkingPermission, needsPermission, serviceOff, permanentlyDenied, loading, error, ready }

class WeatherWidget extends StatefulWidget {
  final bool isFeedback;
  const WeatherWidget({super.key, this.isFeedback = false});

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  final _service = WeatherService();
  _WidgetState _state = _WidgetState.checkingPermission;
  WeatherData? _data;

  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _state = _WidgetState.checkingPermission);
    final status = await _service.checkLocationStatus();
    _handleStatus(status);
  }

  void _handleStatus(LocationStatus status) {
    switch (status) {
      case LocationStatus.granted:
        _fetchWeather();
      case LocationStatus.denied:
        setState(() => _state = _WidgetState.needsPermission);
      case LocationStatus.deniedForever:
        setState(() => _state = _WidgetState.permanentlyDenied);
      case LocationStatus.serviceDisabled:
        setState(() => _state = _WidgetState.serviceOff);
    }
  }

  Future<void> _requestPermission() async {
    setState(() => _state = _WidgetState.checkingPermission);
    final status = await _service.requestPermission();
    _handleStatus(status);
  }

  Future<void> _fetchWeather({bool forceRefresh = false}) async {
    setState(() {
      _state = _WidgetState.loading;
      _errorMsg = null;
    });
    try {
      final data = await _service.getWeather(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _data = data;
          if (data != null) {
            _state = _WidgetState.ready;
          } else {
            _state = _WidgetState.error;
            _errorMsg = 'Lỗi không xác định (data null)';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _WidgetState.error;
          _errorMsg = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LiquidGlassContainer(
      isFeedback: widget.isFeedback,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: switch (_state) {
        _WidgetState.checkingPermission || _WidgetState.loading => _buildLoading(),
        _WidgetState.needsPermission => _buildNeedsPermission(),
        _WidgetState.permanentlyDenied => _buildPermanentlyDenied(),
        _WidgetState.serviceOff => _buildServiceOff(),
        _WidgetState.error => _buildError(),
        _WidgetState.ready => _buildContent(_data!),
      },
    );
  }

  // ── Loading ──────────────────────────────────────────────────────────────

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hourglass_empty_rounded, color: Colors.white54, size: 20),
          SizedBox(height: 4),
          Text(
            'Đang tải...',
            style: TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }

  // ── Needs permission (can still ask) ─────────────────────────────────────

  Widget _buildNeedsPermission() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('📍', style: TextStyle(fontSize: 22)),
        const SizedBox(height: 6),
        const Text(
          'Cần quyền\nvị trí',
          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _requestPermission,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Cho phép',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Permanently denied (must go to Settings) ─────────────────────────────

  Widget _buildPermanentlyDenied() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('🔒', style: TextStyle(fontSize: 20)),
        const SizedBox(height: 6),
        const Text(
          'Quyền vị trí\nbị từ chối',
          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            await Geolocator.openAppSettings();
            // Re-check after user returns from Settings
            await Future.delayed(const Duration(seconds: 1));
            _init();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Mở Cài đặt',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── GPS/Location service off ──────────────────────────────────────────────

  Widget _buildServiceOff() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('📡', style: TextStyle(fontSize: 20)),
        const SizedBox(height: 6),
        const Text(
          'GPS đang tắt',
          style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            await Geolocator.openLocationSettings();
            await Future.delayed(const Duration(seconds: 1));
            _init();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Bật vị trí',
              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  // ── Network/fetch error ───────────────────────────────────────────────────

  Widget _buildError() {
    return GestureDetector(
      onTap: () => _fetchWeather(forceRefresh: true),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white54, size: 18),
          const SizedBox(height: 4),
          Text(
            _errorMsg ?? 'Lỗi không xác định',
            style: const TextStyle(color: Colors.white54, fontSize: 8),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          const Text(
            'Thử lại',
            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ── Content ───────────────────────────────────────────────────────────────

  Widget _buildContent(WeatherData d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'THỜI TIẾT',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
            GestureDetector(
              onTap: () => _fetchWeather(forceRefresh: true),
              child: Text(d.emoji, style: const TextStyle(fontSize: 15)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          d.cityName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${d.temperature.round()}°',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
        const Spacer(),
        Text(
          d.condition,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Text(
              'C:${d.temperatureMax.round()}°',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 10,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'T:${d.temperatureMin.round()}°',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
