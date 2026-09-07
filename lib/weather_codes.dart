// lib/weather_codes.dart
//
// Maps Open-Meteo's `weather_code` (WMO 4677 table, verified against
// Open-Meteo's own docs) to a Material icon, a short label, and a color.
// Color follows the same rule as everywhere else: amber for normal
// conditions, grey for visibility-only conditions (fog), red ONLY for
// conditions severe enough to actually matter operationally (heavy rain,
// heavy snow, freezing rain, thunderstorms/hail). No other hues.

import 'package:flutter/material.dart';
import 'theme.dart';

class WeatherCodeInfo {
  final IconData icon;
  final String label;
  final Color color;
  const WeatherCodeInfo(this.icon, this.label, this.color);
}

const Map<int, WeatherCodeInfo> weatherCodes = {
  0: WeatherCodeInfo(Icons.wb_sunny, 'Clear', AppColors.amber),
  1: WeatherCodeInfo(Icons.wb_sunny_outlined, 'Mainly Clear', AppColors.amber),
  2: WeatherCodeInfo(Icons.cloud_queue, 'Partly Cloudy', AppColors.white),
  3: WeatherCodeInfo(Icons.cloud, 'Overcast', AppColors.white),
  45: WeatherCodeInfo(Icons.foggy, 'Fog', AppColors.grey),
  48: WeatherCodeInfo(Icons.foggy, 'Freezing Fog', AppColors.grey),
  51: WeatherCodeInfo(Icons.grain, 'Light Drizzle', AppColors.amber),
  53: WeatherCodeInfo(Icons.grain, 'Drizzle', AppColors.amber),
  55: WeatherCodeInfo(Icons.grain, 'Heavy Drizzle', AppColors.amber),
  56: WeatherCodeInfo(Icons.ac_unit, 'Light Freezing Drizzle', AppColors.amber),
  57: WeatherCodeInfo(Icons.ac_unit, 'Freezing Drizzle', AppColors.red),
  61: WeatherCodeInfo(Icons.water_drop_outlined, 'Light Rain', AppColors.amber),
  63: WeatherCodeInfo(Icons.water_drop, 'Rain', AppColors.amber),
  65: WeatherCodeInfo(Icons.water_drop, 'Heavy Rain', AppColors.red),
  66: WeatherCodeInfo(Icons.ac_unit, 'Light Freezing Rain', AppColors.amber),
  67: WeatherCodeInfo(Icons.ac_unit, 'Freezing Rain', AppColors.red),
  71: WeatherCodeInfo(Icons.ac_unit, 'Light Snow', AppColors.amber),
  73: WeatherCodeInfo(Icons.ac_unit, 'Snow', AppColors.amber),
  75: WeatherCodeInfo(Icons.ac_unit, 'Heavy Snow', AppColors.red),
  77: WeatherCodeInfo(Icons.grain, 'Snow Grains', AppColors.amber),
  80: WeatherCodeInfo(Icons.water_drop_outlined, 'Light Rain Showers', AppColors.amber),
  81: WeatherCodeInfo(Icons.water_drop, 'Rain Showers', AppColors.amber),
  82: WeatherCodeInfo(Icons.water_drop, 'Heavy Rain Showers', AppColors.red),
  85: WeatherCodeInfo(Icons.ac_unit, 'Snow Showers', AppColors.amber),
  86: WeatherCodeInfo(Icons.ac_unit, 'Heavy Snow Showers', AppColors.red),
  95: WeatherCodeInfo(Icons.thunderstorm, 'Thunderstorm', AppColors.red),
  96: WeatherCodeInfo(Icons.thunderstorm, 'Thunderstorm, Hail', AppColors.red),
  99: WeatherCodeInfo(Icons.thunderstorm, 'Severe Thunderstorm, Hail', AppColors.red),
};

const _fallback = WeatherCodeInfo(Icons.help_outline, 'Unknown', AppColors.grey);

WeatherCodeInfo weatherCodeInfo(num? code) =>
    code == null ? _fallback : (weatherCodes[code.toInt()] ?? _fallback);
