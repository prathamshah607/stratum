// lib/theme.dart
//
// The ENTIRE color vocabulary for this app. Bloomberg Terminal discipline:
// near-black backgrounds, amber as the default data/text color, white/grey
// for structure and secondary text, and green/red used ONLY for signed
// deltas (an up move, a down move, a severe-weather flag) -- never to
// differentiate arbitrary data series from each other. If a new color
// feels needed anywhere in the app, it's a sign the layout needs a label
// or a delta indicator instead, not a new hue.

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Structure
  static const bg = Color(0xFF000000);
  static const panel = Color(0xFF0A0A0A);
  static const panelAlt = Color(0xFF111111);
  static const border = Color(0xFF2A2A2A);

  // Data (default)
  static const amber = Color(0xFFFFB000);
  static const amberDim = Color(0xFFB37D00);

  // Structure / secondary text
  static const white = Color(0xFFE8E8E8);
  static const grey = Color(0xFF8A8A8A);
  static const greyDim = Color(0xFF4A4A4A);

  // Signed deltas ONLY -- rising/positive vs falling/negative/severe.
  // Never assign these to a chart just to distinguish it from another chart.
  static const green = Color(0xFF00C805);
  static const red = Color(0xFFFF3B30);
}

const monoStyle = TextStyle(
  fontFamily: 'JetBrainsMono',
  fontFeatures: [FontFeature.tabularFigures()],
  color: AppColors.white,
);

/// Color for a signed change -- the only legitimate use of green/red.
Color deltaColor(num change) {
  if (change > 0) return AppColors.green;
  if (change < 0) return AppColors.red;
  return AppColors.grey;
}

/// Shared low->high diverging scale (green -> amber -> red) for magnitude
/// visualizations (heatmap cells, wave-rose sectors). [t] is 0..1.
Color divergingColor(double t) {
  final clamped = t.clamp(0.0, 1.0);
  if (clamped < 0.5) return Color.lerp(AppColors.green, AppColors.amber, clamped / 0.5)!;
  return Color.lerp(AppColors.amber, AppColors.red, (clamped - 0.5) / 0.5)!;
}

/// Precipitation: Blue -> White -> Red
Color precipDivergingColor(double t) {
  final clamped = t.clamp(0.0, 1.0);
  const blue = Color(0xFF007AFF);
  if (clamped < 0.5) return Color.lerp(blue, AppColors.white, clamped / 0.5)!;
  return Color.lerp(AppColors.white, AppColors.red, (clamped - 0.5) / 0.5)!;
}

/// Wind: Dark Grey -> Mid Green -> Bright Green
Color windDivergingColor(double t) {
  final clamped = t.clamp(0.0, 1.0);
  const midGreen = Color(0xFF008800);
  if (clamped < 0.5) return Color.lerp(AppColors.border, midGreen, clamped / 0.5)!;
  return Color.lerp(midGreen, AppColors.green, (clamped - 0.5) / 0.5)!;
}
