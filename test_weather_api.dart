import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  // Hardcoded Hanoi coords for testing
  final lat = 21.0285;
  final lon = 105.8542;

  final weatherUri = Uri.parse(
    'https://api.open-meteo.com/v1/forecast'
    '?latitude=$lat&longitude=$lon'
    '&current=temperature_2m,weather_code,wind_speed_10m'
    '&daily=temperature_2m_max,temperature_2m_min'
    '&timezone=auto'
    '&forecast_days=1',
  );

  final geoUri = Uri.parse(
    'https://nominatim.openstreetmap.org/reverse'
    '?lat=$lat&lon=$lon&format=json&accept-language=vi',
  );

  try {
    print('Fetching weather...');
    final weatherRes = await http.get(weatherUri, headers: {'Accept': 'application/json'});
    print('Weather status: ${weatherRes.statusCode}');
    print('Weather body: ${weatherRes.body}');
    
    print('Fetching geocode...');
    final geoRes = await http.get(geoUri, headers: {
      'Accept': 'application/json',
      'User-Agent': 'ios_launcher_app',
    });
    print('Geo status: ${geoRes.statusCode}');
    print('Geo body: ${geoRes.body}');
  } catch (e) {
    print('Error: $e');
  }
}
