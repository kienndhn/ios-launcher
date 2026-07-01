import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Represents all possible states of the location permission.
enum LocationStatus {
  /// GPS/location service is turned off on the device.
  serviceDisabled,

  /// Permission not yet granted — can still ask.
  denied,

  /// User permanently denied permission — must go to app Settings.
  deniedForever,

  /// Permission granted, ready to use.
  granted,
}

/// Data class holding current weather information.
class WeatherData {
  final double temperature;
  final double temperatureMax;
  final double temperatureMin;
  final double windSpeed;
  final int weatherCode;
  final String cityName;
  final String condition;
  final String emoji;

  const WeatherData({
    required this.temperature,
    required this.temperatureMax,
    required this.temperatureMin,
    required this.windSpeed,
    required this.weatherCode,
    required this.cityName,
    required this.condition,
    required this.emoji,
  });
}

class WeatherService {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();

  WeatherData? _cached;
  DateTime? _lastFetch;
  static const _cacheDuration = Duration(minutes: 30);

  Future<WeatherData?> getWeather({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cached != null &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < _cacheDuration) {
      return _cached;
    }

    try {
      print('WeatherService: determining position...');
      double lat = 21.0285;
      double lon = 105.8542;

      final position = await _determinePosition();
      if (position != null) {
        lat = position.latitude;
        lon = position.longitude;
        print('WeatherService: position found: $lat, $lon');
      } else {
        print('WeatherService: position is null, falling back to default (Hà Nội)');
      }

      // Fetch weather + daily min/max from Open-Meteo (no API key required)
      final weatherUri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lon'
        '&current=temperature_2m,weather_code,wind_speed_10m'
        '&daily=temperature_2m_max,temperature_2m_min'
        '&timezone=auto'
        '&forecast_days=1',
      );

      // Reverse geocode via Nominatim (OpenStreetMap)
      final geoUri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$lat&lon=$lon&format=json&accept-language=vi',
      );

      print('WeatherService: making HTTP requests...');
      final results = await Future.wait([
        http.get(weatherUri, headers: {'Accept': 'application/json'}),
        http.get(geoUri, headers: {
          'Accept': 'application/json',
          'User-Agent': 'ios_launcher_app',
        }),
      ]);

      final weatherRes = results[0];
      final geoRes = results[1];
      print('WeatherService: weather status = ${weatherRes.statusCode}, geo status = ${geoRes.statusCode}');

      if (weatherRes.statusCode != 200) {
        print('WeatherService: weather API failed: ${weatherRes.body}');
        return null;
      }

      final weatherJson = jsonDecode(weatherRes.body) as Map<String, dynamic>;
      final current = weatherJson['current'] as Map<String, dynamic>;
      final daily = weatherJson['daily'] as Map<String, dynamic>;

      final code = (current['weather_code'] as num).toInt();
      final temp = (current['temperature_2m'] as num).toDouble();
      final wind = (current['wind_speed_10m'] as num).toDouble();
      final tMax = (daily['temperature_2m_max'] as List).first as num;
      final tMin = (daily['temperature_2m_min'] as List).first as num;

      String city = 'Vị trí của bạn';
      if (geoRes.statusCode == 200) {
        final geoJson = jsonDecode(geoRes.body) as Map<String, dynamic>;
        final address = geoJson['address'] as Map<String, dynamic>?;
        city = address?['city'] ??
            address?['town'] ??
            address?['county'] ??
            address?['state'] ??
            'Vị trí của bạn';
      }
      print('WeatherService: parsing successful ($city, $temp°C)');

      final (condition, emoji) = _decodeWeatherCode(code);

      _cached = WeatherData(
        temperature: temp,
        temperatureMax: tMax.toDouble(),
        temperatureMin: tMin.toDouble(),
        windSpeed: wind,
        weatherCode: code,
        cityName: city,
        condition: condition,
        emoji: emoji,
      );
      _lastFetch = DateTime.now();
      return _cached;
    } catch (e) {
      debugPrint('WeatherService error: $e');
      return null;
    }
  }

  /// Checks the current permission state without requesting anything.
  Future<LocationStatus> checkLocationStatus() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationStatus.serviceDisabled;

    final perm = await Geolocator.checkPermission();
    return switch (perm) {
      LocationPermission.denied => LocationStatus.denied,
      LocationPermission.deniedForever => LocationStatus.deniedForever,
      _ => LocationStatus.granted,
    };
  }

  /// Requests location permission and returns the resulting status.
  Future<LocationStatus> requestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationStatus.serviceDisabled;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return switch (perm) {
      LocationPermission.denied => LocationStatus.denied,
      LocationPermission.deniedForever => LocationStatus.deniedForever,
      _ => LocationStatus.granted,
    };
  }

  /// Returns device position after handling all permission edge-cases.
  Future<Position?> _determinePosition() async {
    final status = await checkLocationStatus();
    if (status != LocationStatus.granted) return null;

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      print('WeatherService: getCurrentPosition failed ($e), trying getLastKnownPosition...');
      return await Geolocator.getLastKnownPosition();
    }
  }

  /// Maps Open-Meteo WMO weather code to a Vietnamese description + emoji.
  static (String, String) _decodeWeatherCode(int code) {
    return switch (code) {
      0 => ('Trời trong', '☀️'),
      1 => ('Mostly clear', '🌤️'),
      2 => ('Có mây', '⛅'),
      3 => ('Nhiều mây', '☁️'),
      45 || 48 => ('Sương mù', '🌫️'),
      51 || 53 || 55 => ('Mưa phùn', '🌦️'),
      56 || 57 => ('Mưa phùn lạnh', '🌧️'),
      61 || 63 => ('Mưa nhẹ', '🌧️'),
      65 => ('Mưa to', '🌧️'),
      71 || 73 || 75 => ('Tuyết rơi', '❄️'),
      77 => ('Hạt tuyết', '🌨️'),
      80 || 81 => ('Mưa rào', '🌦️'),
      82 => ('Mưa rào mạnh', '⛈️'),
      85 || 86 => ('Mưa tuyết', '🌨️'),
      95 => ('Giông bão', '⛈️'),
      96 || 99 => ('Giông có đá', '⛈️'),
      _ => ('Không rõ', '🌡️'),
    };
  }
}
