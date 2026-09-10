// lib/heatmap_widget.dart
//
// Day-of-year x year grid. Built for Historical/Climate: the question those
// modes answer is "how has this variable trended and where are the outlier
// years/seasons", which a single scrolling line chart hides once you're past
// a year or two of daily data. A calendar heatmap puts every year in view
// at once.
//
// Color encodes deviation from the period mean (green = below average,
// amber = near average, red = above average) -- this stays inside the
// strict palette by treating "how far from normal" as a signed delta,
// the same rule used for MetricPanel's up/down indicators.
//
// PERF FIX: this used to build one Tooltip+Container PER CALENDAR DAY PER
// YEAR (up to 366 x ~8 years x ~5 primary fields => 10,000+ Tooltip
// widgets on a single Historical/Climate page). Tooltip is not cheap --
// each instance wires up its own gesture recognizers and registers with
// the overlay/tooltip-manager machinery -- and that widget count is what
// was making the whole page (including unrelated scrolling) janky. The
// grid is now a single CustomPaint per field that draws every cell as a
// plain canvas rect in one paint pass. Hover feedback is kept (so you
// don't lose the ability to read an exact day's value) but is implemented
// as one MouseRegion computing row/col from cursor position and updating a
// small text readout -- NOT by rebuilding or repainting the grid itself,
// so hovering never costs a repaint of the (expensive-to-draw) canvas.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'theme.dart';

class CalendarHeatmap extends StatefulWidget {
  final String label;
  final String unit;
  final List<DateTime> dates;
  final List<double> values; // same length as dates, chronological
  const CalendarHeatmap({super.key, required this.label, required this.dates, required this.values, required this.unit});

  @override
  State<CalendarHeatmap> createState() => _CalendarHeatmapState();
}

class _CalendarHeatmapState extends State<CalendarHeatmap> {
  static const _cell = 11.0;
  static const _gap = 2.0;
  static const _leftLabel = 40.0;
  static const _topHeader = 16.0;

  String? _hoverText;

  int _dayOfYear(DateTime d) => d.difference(DateTime.utc(d.year, 1, 1)).inDays + 1;

  void _handleHover(Offset local, List<int> years, Map<int, Map<int, double>> byYear) {
    final col = ((local.dx - _leftLabel) / (_cell + _gap)).floor();
    final row = ((local.dy - _topHeader) / (_cell + _gap)).floor();
    String? text;
    if (col >= 0 && col < 366 && row >= 0 && row < years.length) {
      final year = years[row];
      final day = col + 1;
      final v = byYear[year]?[day];
      if (v != null) {
        final date = DateTime.utc(year, 1, 1).add(Duration(days: day - 1));
        final dd = date.day.toString().padLeft(2, '0');
        final mm = date.month.toString().padLeft(2, '0');
        text = '$dd/$mm/${date.year}  ${v.toStringAsFixed(1)}${widget.unit}';
      }
    }
    if (text != _hoverText) setState(() => _hoverText = text);
  }

  @override
  Widget build(BuildContext context) {
    final dates = widget.dates;
    final values = widget.values;
    if (dates.isEmpty || values.isEmpty) {
      return Container(
        height: 160,
        alignment: Alignment.center,
        color: AppColors.panel,
        child: Text('NO DATA AVAILABLE', style: monoStyle.copyWith(color: AppColors.greyDim, fontSize: 11)),
      );
    }

    // Group by year -> day-of-year.
    final byYear = <int, Map<int, double>>{};
    for (var i = 0; i < dates.length && i < values.length; i++) {
      final d = dates[i];
      byYear.putIfAbsent(d.year, () => {})[_dayOfYear(d)] = values[i];
    }
    final years = byYear.keys.toList()..sort();
    final mean = values.reduce((a, b) => a + b) / values.length;
    final maxDev = values.map((v) => (v - mean).abs()).reduce((a, b) => a > b ? a : b);

    final gridWidth = _leftLabel + 366 * (_cell + _gap);
    final gridHeight = _topHeader + years.length * (_cell + _gap);

    return Container(
      decoration: BoxDecoration(color: AppColors.panel, border: Border.all(color: AppColors.border)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('${widget.label} (${widget.unit.isEmpty ? '' : widget.unit})', style: monoStyle.copyWith(fontSize: 13, color: AppColors.white)),
            const Spacer(),
            SizedBox(
              width: 220,
              child: Text(_hoverText ?? '', textAlign: TextAlign.right, style: monoStyle.copyWith(fontSize: 11, color: AppColors.amber)),
            ),
            const SizedBox(width: 12),
            Text('MEAN ${mean.toStringAsFixed(1)}', style: monoStyle.copyWith(fontSize: 11, color: AppColors.grey)),
            const SizedBox(width: 12),
            _legend(),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            height: (years.length * (_cell + _gap) + 24).clamp(0, 420).toDouble(),
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: MouseRegion(
                  onHover: (e) => _handleHover(e.localPosition, years, byYear),
                  onExit: (_) {
                    if (_hoverText != null) setState(() => _hoverText = null);
                  },
                  child: SizedBox(
                    width: gridWidth,
                    height: gridHeight,
                    // RepaintBoundary keeps this canvas isolated from the
                    // hover-text setState above -- hovering repaints only
                    // that small Text widget, never the grid itself.
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _HeatmapPainter(
                          label: widget.label,
                          years: years,
                          byYear: byYear,
                          mean: mean,
                          maxDev: maxDev,
                          cell: _cell,
                          gap: _gap,
                          leftLabel: _leftLabel,
                          topHeader: _topHeader,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend() {
    final isPrecip = widget.label.toLowerCase().contains('precipitation');
    final isWind = widget.label.toLowerCase().contains('wind');
    
    final Color lowColor = isPrecip ? const Color(0xFF007AFF) : (isWind ? AppColors.border : AppColors.green);
    final Color midColor = isPrecip ? AppColors.white : (isWind ? const Color(0xFF008800) : AppColors.amber);
    final Color highColor = isPrecip ? AppColors.red : (isWind ? AppColors.green : AppColors.red);

    return Row(children: [
      Text('LOW', style: monoStyle.copyWith(fontSize: 9, color: lowColor)),
      Container(width: 40, height: 8, margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(gradient: LinearGradient(colors: [lowColor, midColor, highColor]))),
      Text('HIGH', style: monoStyle.copyWith(fontSize: 9, color: highColor)),
    ]);
  }
}

/// Draws month header, year labels, and all day-cells for one heatmap in a
/// single paint pass -- replaces what used to be hundreds/thousands of
/// separate Container/Text/Tooltip widgets per field.
class _HeatmapPainter extends CustomPainter {
  final List<int> years;
  final Map<int, Map<int, double>> byYear;
  final double mean;
  final double maxDev;
  final double cell;
  final double gap;
  final double leftLabel;
  final double topHeader;
  final String label;

  _HeatmapPainter({
    required this.years,
    required this.byYear,
    required this.mean,
    required this.maxDev,
    required this.cell,
    required this.gap,
    required this.leftLabel,
    required this.topHeader,
    required this.label,
  });

  static const _months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
  static const _monthStarts = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];

  Color _colorFor(double v) {
    if (maxDev == 0) return AppColors.amber;
    final t = ((v - mean) / maxDev + 1) / 2; // map -1..1 -> 0..1
    final l = label.toLowerCase();
    if (l.contains('precipitation')) return precipDivergingColor(t);
    if (l.contains('wind')) return windDivergingColor(t);
    return divergingColor(t);
  }

  void _drawText(Canvas canvas, String text, Offset pos, {double fontSize = 9, Color color = AppColors.grey}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: monoStyle.copyWith(fontSize: fontSize, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Month header.
    for (var m = 0; m < 12; m++) {
      _drawText(canvas, _months[m], Offset(leftLabel + _monthStarts[m] * (cell + gap), 2), fontSize: 8);
    }

    final cellPaint = Paint();
    for (var row = 0; row < years.length; row++) {
      final year = years[row];
      final days = byYear[year]!;
      final y = topHeader + row * (cell + gap);

      // Year label.
      _drawText(canvas, '$year', Offset(0, y + 1), fontSize: 9);

      // 366 day cells for this year, one rect each -- still a loop, but
      // pure canvas drawing (no widget/element/render-object overhead),
      // which is orders of magnitude cheaper than a Container per cell.
      for (var d = 1; d <= 366; d++) {
        final x = leftLabel + (d - 1) * (cell + gap);
        final v = days[d];
        cellPaint.color = v != null ? _colorFor(v) : AppColors.border;
        canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), cellPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) =>
      oldDelegate.years != years || oldDelegate.byYear != byYear || oldDelegate.mean != mean || oldDelegate.maxDev != maxDev || oldDelegate.label != label;
}