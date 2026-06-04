import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class WeatherInfo {
  final String city;
  final String condition;
  final int tempC;

  WeatherInfo({
    required this.city,
    required this.condition,
    required this.tempC,
  });

  factory WeatherInfo.fromJson(Map<String, dynamic> json) {
    return WeatherInfo(
      city: json['city'] ?? '',
      condition: json['condition'] ?? '',
      tempC: json['temp_c'] ?? 0,
    );
  }

  String get display => '$city · $condition, $tempC°';
}

final weatherProvider = FutureProvider<WeatherInfo>((ref) async {
  final api = ref.read(apiClientProvider);
  final data = await api.getWeather();
  return WeatherInfo.fromJson(data);
});
