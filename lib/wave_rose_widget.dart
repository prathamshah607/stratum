// lib/wave_rose_widget.dart
//
// Marine's wave_direction is in degrees (0-360) -- plotting that as a line
// chart is close to meaningless (0deg and 359deg are neighbors, not
// opposites). The actual question a mariner asks is "which direction is
// the swell coming from, and how big is it from that direction" -- a
// compass rose answers that directly. Sector length = average height from
// that direction, color = same low->high scale used everywhere else.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';

class WaveRose extends StatelessWidget {
  final String label;
  final String heightUnit;
  final List<double> directions; // degrees, paired 1:1 with heights
  final List<double> heights;
  final double? currentHeight;
  final double? currentPeriod;
  const WaveRose({
    super.key,
    required this.label,
    required this.heightUnit,
    required this.directions,
    required this.heights,
    this.currentHeight,
    this.currentPeriod,
  });

  static const _compass = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', 'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'];

  @override
  Widget build(BuildContext context) {
    final n = math.min(directions.length, heights.length);
    if (n == 0) {
      return Container(
        decoration: BoxDecoration(color: AppColors.panel, border: Border.all(color: AppColors.border)),
        alignment: Alignment.center,
        child: Text('NO DATA AVAILABLE', style: monoStyle.copyWith(color: AppColors.greyDim, fontSize: 11)),
      );
    }

    final bins = List<double>.filled(16, 0);
    final counts = List<int>.filled(16, 0);
    for (var i = 0; i < n; i++) {
      final bin = (((directions[i] % 360) / 22.5).round()) % 16;
      bins[bin] += heights[i];
      counts[bin]++;
    }
    final avg = [for (var i = 0; i < 16; i++) counts[i] == 0 ? 0.0 : bins[i] / counts[i]];
    final maxAvg = avg.reduce((a, b) => a > b ? a : b);
    final dominantBin = avg.indexOf(maxAvg);

    return Container(
      decoration: BoxDecoration(color: AppColors.panel, border: Border.all(color: AppColors.border)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: monoStyle.copyWith(fontSize: 12, color: AppColors.grey, letterSpacing: 1)),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (currentHeight != null) Text('${currentHeight!.toStringAsFixed(1)}$heightUnit', style: monoStyle.copyWith(fontSize: 22, color: AppColors.amber, fontWeight: FontWeight.bold)),
            const SizedBox(width: 10),
            if (currentPeriod != null) Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('${currentPeriod!.toStringAsFixed(0)}s PERIOD', style: monoStyle.copyWith(fontSize: 11, color: AppColors.grey))),
            const SizedBox(width: 10),
            if (maxAvg > 0) Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('DOMINANT ${_compass[dominantBin]}', style: monoStyle.copyWith(fontSize: 11, color: AppColors.grey))),
          ]),
          const SizedBox(height: 6),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: CustomPaint(painter: _RosePainter(avg: avg, maxAvg: maxAvg, compass: _compass)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RosePainter extends CustomPainter {
  final List<double> avg;
  final double maxAvg;
  final List<String> compass;
  _RosePainter({required this.avg, required this.maxAvg, required this.compass});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2 - 18;
    final ringPaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (var r = 1; r <= 3; r++) {
      canvas.drawCircle(center, maxRadius * r / 3, ringPaint);
    }

    for (var i = 0; i < 16; i++) {
      if (maxAvg == 0 || avg[i] == 0) continue;
      final radius = maxRadius * (avg[i] / maxAvg);
      // Sector centered on i * 22.5deg, 0deg = north = straight up.
      final startAngle = (i * 22.5 - 90 - 10) * math.pi / 180;
      final sweep = 20 * math.pi / 180;
      final t = avg[i] / maxAvg;
      final paint = Paint()..color = divergingColor(t).withOpacity(0.85);
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(Rect.fromCircle(center: center, radius: radius), startAngle, sweep, false)
        ..close();
      canvas.drawPath(path, paint);
    }

    // Compass labels at N/E/S/W.
    _label(canvas, center, maxRadius + 12, -90, 'N');
    _label(canvas, center, maxRadius + 12, 0, 'E');
    _label(canvas, center, maxRadius + 12, 90, 'S');
    _label(canvas, center, maxRadius + 12, 180, 'W');
  }

  void _label(Canvas canvas, Offset center, double radius, double angleDeg, String text) {
    final rad = angleDeg * math.pi / 180;
    final pos = center + Offset(math.cos(rad), math.sin(rad)) * radius;
    final tp = TextPainter(
      text: TextSpan(text: text, style: monoStyle.copyWith(fontSize: 10, color: AppColors.grey)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _RosePainter oldDelegate) => oldDelegate.avg != avg;
}
