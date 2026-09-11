// lib/aqi_gauge_widget.dart
//
// Air Quality's `us_aqi` field is already a computed index (0-500+), so the
// headline widget for this mode is a gauge reading that index, not a line
// chart of it. Banding follows the EPA's published breakpoints, collapsed
// into the strict 3-color palette: green (good/moderate, 0-100), amber
// (unhealthy for sensitive groups/unhealthy, 101-200), red (very
// unhealthy/hazardous, 201+).
//
// FIX: the gauge used to render tiny and squashed -- its CustomPaint was
// wrapped in a SizedBox with only a width set, inside a non-stretching Row,
// so with no explicit height CustomPaint just shrink-wrapped to fit its
// child (the "60" text). The actual paint canvas ended up barely bigger
// than the number itself. Now the Row stretches to the panel's full height,
// the gauge is drawn via Positioned.fill inside a Stack (guaranteeing it
// gets the full box), and the leftover width -- which used to just be
// blank -- now holds a real trend line of the AQI history.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'theme.dart';
import 'widgets.dart' show planAxisLabels;

class AqiGauge extends StatelessWidget {
  final double? current;
  final List<double> history; // for the trend chart alongside the gauge
  final List<DateTime>?
      times; // paired 1:1 with history, for the trend's x-axis
  const AqiGauge(
      {super.key, required this.current, this.history = const [], this.times});

  static const _maxScale = 300.0;

  @override
  Widget build(BuildContext context) {
    final value = current;
    final label = value == null
        ? '--'
        : value <= 50
            ? 'GOOD'
            : value <= 100
                ? 'MODERATE'
                : value <= 150
                    ? 'UNHEALTHY (SENSITIVE)'
                    : value <= 200
                        ? 'UNHEALTHY'
                        : value <= 300
                            ? 'VERY UNHEALTHY'
                            : 'HAZARDOUS';
    final color = value == null
        ? AppColors.grey
        : (value <= 100
            ? AppColors.green
            : (value <= 200 ? AppColors.amber : AppColors.red));

    return Container(
      decoration: BoxDecoration(
          color: AppColors.panel, border: Border.all(color: AppColors.border)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('US AQI',
              style: monoStyle.copyWith(
                  fontSize: 12, color: AppColors.grey, letterSpacing: 1)),
          const SizedBox(height: 6),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(builder: (context, constraints) {
                  final side = constraints.maxHeight.clamp(140, 320);
                  return SizedBox(
                    width: constraints.maxHeight.clamp(140, 320),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                            child: CustomPaint(
                                painter:
                                    _GaugePainter(value: value, color: color))),
                        Padding(
                          padding: EdgeInsets.only(top: side * 0.18),
                          child: Text(
                              value == null ? '--' : value.toStringAsFixed(0),
                              style: monoStyle.copyWith(
                                  fontSize: 32,
                                  color: color,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(width: 20),
                SizedBox(
                  width: 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(label,
                          style: monoStyle.copyWith(
                              fontSize: 14,
                              color: color,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      _bandRow('0-50', 'Good', AppColors.green),
                      _bandRow('51-100', 'Moderate', AppColors.green),
                      _bandRow('101-200', 'Unhealthy', AppColors.amber),
                      _bandRow(
                          '201+', 'Very Unhealthy / Hazardous', AppColors.red),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // Previously blank space -- now a real trend of the AQI
                // history over the selected window, filling the rest of
                // the panel's width instead of leaving it empty.
                Expanded(
                  child: history.length < 2
                      ? Center(
                          child: Text('NOT ENOUGH DATA FOR TREND',
                              style: monoStyle.copyWith(
                                  fontSize: 11, color: AppColors.greyDim)))
                      : _TrendChart(
                          history: history, times: times, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bandRow(String range, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(children: [
        Container(width: 8, height: 8, color: color),
        const SizedBox(width: 6),
        Text('$range  $label',
            style: monoStyle.copyWith(fontSize: 10, color: AppColors.grey)),
      ]),
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<double> history;
  final List<DateTime>? times;
  final Color color;
  const _TrendChart({required this.history, required this.times, required this.color});

  @override
  Widget build(BuildContext context) {
    final hasTimes = times != null && times!.length >= history.length;
    return LayoutBuilder(builder: (context, constraints) {
      final t = hasTimes ? times!.sublist(0, history.length) : null;
      final plan = t != null ? planAxisLabels(t, constraints.maxWidth) : null;
      return LineChart(LineChartData(
        gridData: FlGridData(show: true, getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 0.5)),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, getTitlesWidget: (v, m) => Text(v.toStringAsFixed(0), style: monoStyle.copyWith(fontSize: 9, color: AppColors.grey)))),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: plan != null,
              reservedSize: 22,
              interval: plan?.interval,
              getTitlesWidget: (v, m) {
                if (plan == null || t == null) return const SizedBox.shrink();
                final i = v.round();
                if (i < 0 || i >= t.length) return const SizedBox.shrink();
                return Padding(padding: const EdgeInsets.only(top: 3), child: Text(plan.axisFormat(t[i]), style: monoStyle.copyWith(fontSize: 8, color: AppColors.grey)));
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((s) {
              final i = s.x.round();
              final dateLabel = (plan != null && t != null && i >= 0 && i < t.length) ? plan.tooltipFormat(t[i]) : '';
              final valueLabel = 'AQI ${s.y.toStringAsFixed(0)}';
              return LineTooltipItem(dateLabel.isEmpty ? valueLabel : '$dateLabel\n$valueLabel', monoStyle.copyWith(fontSize: 11, color: AppColors.white, fontWeight: FontWeight.bold));
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [for (var i = 0; i < history.length; i++) FlSpot(i.toDouble(), history[i])],
            isCurved: false,
            barWidth: 1.4,
            color: color,
            dotData: const FlDotData(show: false),
          ),
        ],
      ));
    });
  }
}

class _GaugePainter extends CustomPainter {
  final double? value;
  final Color color;
  _GaugePainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.6);
    final radius = math.min(size.width / 2, size.height * 0.5) - 8;
    const startAngle = math.pi; // 180deg, left side
    const sweep = math.pi; // half circle to right side

    // Three color bands across the 180deg arc: green(0-100/300), amber, red.
    final bandPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.butt;
    final bands = [
      (0.0, 1 / 3, AppColors.green),
      (1 / 3, 2 / 3, AppColors.amber),
      (2 / 3, 1.0, AppColors.red),
    ];
    for (final (from, to, c) in bands) {
      bandPaint.color = c.withOpacity(0.7);
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
          startAngle + sweep * from, sweep * (to - from), false, bandPaint);
    }

    if (value != null) {
      final t = (value! / AqiGauge._maxScale).clamp(0.0, 1.0);
      final angle = startAngle + sweep * t;
      final needle =
          center + Offset(math.cos(angle), math.sin(angle)) * (radius - 4);
      final needlePaint = Paint()
        ..color = AppColors.white
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(center, needle, needlePaint);
      canvas.drawCircle(center, 4, Paint()..color = AppColors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.color != color;
}
