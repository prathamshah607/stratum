// lib/fan_chart_widget.dart
//
// Ensemble mode's response comes back as `<field>_member00`.._memberNN` --
// dozens of independent model runs of the same variable. A single line
// throws that away. This widget shows the min-max envelope shaded behind a
// bold mean line, with individual members drawn faint if there are few
// enough to read (>12 members, they're dropped in favor of the band alone --
// spaghetti with 30 strands is noise, not signal).
//
// Text-first: header row states current mean, current spread (max-min) and
// the signed delta vs. the previous point, before the chart renders at all.
// No fixed pixel height anymore -- fills whatever cell _DynamicGrid gives it.

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'theme.dart';
import 'widgets.dart' show planAxisLabels, AxisLabelPlan, indianFullDateTime;

/// Scans a series map for `<baseKey>_memberNN` keys and returns each
/// member's value list, null-filtered per member, in member-index order.
/// [stride] downsamples every member by taking every Nth point (plus the
/// final point, so "current" stays accurate) -- pass the same stride used
/// to downsample the `times` list passed into FanChart so the two stay
/// aligned. Long ranges with 20-30 members and thousands of hourly points
/// each is what was making Ensemble mode laggy.
List<List<double>> extractEnsembleMembers(Map<String, dynamic> series, String baseKey, {int stride = 1}) {
  final pattern = RegExp('^${RegExp.escape(baseKey)}_member(\\d+)\$');
  final matches = <int, List<double>>{};
  for (final key in series.keys) {
    final m = pattern.firstMatch(key);
    if (m == null) continue;
    final idx = int.parse(m.group(1)!);
    final raw = (series[key] as List?)?.cast<num?>() ?? [];
    final filtered = [for (final v in raw) if (v != null) v.toDouble()];
    matches[idx] = _strideKeepLast(filtered, stride);
  }
  final ordered = matches.keys.toList()..sort();
  return [for (final i in ordered) matches[i]!];
}

List<double> _strideKeepLast(List<double> list, int stride) {
  if (stride <= 1 || list.isEmpty) return list;
  final out = [for (var i = 0; i < list.length; i += stride) list[i]];
  if (out.last != list.last) out.add(list.last);
  return out;
}

class FanChart extends StatelessWidget {
  final String label;
  final String unit;
  final List<List<double>> members;
  final List<DateTime>? times; // raw response 'time' array, index-aligned
  const FanChart({super.key, required this.label, required this.unit, required this.members, this.times});

  @override
  Widget build(BuildContext context) {
    final usable = members.where((m) => m.isNotEmpty).toList();
    if (usable.isEmpty) {
      return Container(
        decoration: BoxDecoration(color: AppColors.panel, border: Border.all(color: AppColors.border)),
        alignment: Alignment.center,
        child: Text('NO DATA AVAILABLE', style: monoStyle.copyWith(color: AppColors.greyDim, fontSize: 11)),
      );
    }
    final length = usable.map((m) => m.length).reduce((a, b) => a < b ? a : b);
    final mean = <double>[], lo = <double>[], hi = <double>[];
    for (var i = 0; i < length; i++) {
      final atI = [for (final m in usable) m[i]];
      mean.add(atI.reduce((a, b) => a + b) / atI.length);
      lo.add(atI.reduce((a, b) => a < b ? a : b));
      hi.add(atI.reduce((a, b) => a > b ? a : b));
    }
    final currentMean = mean.last;
    final currentSpread = hi.last - lo.last;
    final delta = length >= 2 ? mean.last - mean[length - 2] : 0.0;

    return Container(
      decoration: BoxDecoration(color: AppColors.panel, border: Border.all(color: AppColors.border)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(label.toUpperCase(), style: monoStyle.copyWith(fontSize: 12, color: AppColors.grey, letterSpacing: 1)),
            const Spacer(),
            Text('${usable.length} MODELS', style: monoStyle.copyWith(fontSize: 10, color: AppColors.grey)),
          ]),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${currentMean.toStringAsFixed(1)}$unit', style: monoStyle.copyWith(fontSize: 24, color: AppColors.amber, fontWeight: FontWeight.bold)),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Icon(delta > 0 ? Icons.arrow_drop_up : (delta < 0 ? Icons.arrow_drop_down : Icons.remove), color: deltaColor(delta), size: 16),
                Text('${delta.abs().toStringAsFixed(1)}$unit', style: monoStyle.copyWith(fontSize: 11, color: deltaColor(delta))),
                const SizedBox(width: 12),
                Text('SPREAD ±${(currentSpread / 2).toStringAsFixed(1)}$unit', style: monoStyle.copyWith(fontSize: 11, color: AppColors.grey)),
              ]),
            ),
          ]),
          const SizedBox(height: 8),
          Expanded(child: LayoutBuilder(builder: (context, constraints) => _chart(mean, lo, hi, usable, length, constraints.maxWidth))),
        ],
      ),
    );
  }

  Widget _chart(List<double> mean, List<double> lo, List<double> hi, List<List<double>> usable, int length, double width) {
    final memberLines = usable.length <= 12
        ? [
            for (final m in usable)
              LineChartBarData(
                spots: [for (var i = 0; i < length; i++) FlSpot(i.toDouble(), m[i])],
                isCurved: false,
                barWidth: 0.8,
                color: AppColors.grey.withOpacity(0.35),
                dotData: const FlDotData(show: false),
              ),
          ]
        : <LineChartBarData>[];

    final loLine = LineChartBarData(
      spots: [for (var i = 0; i < length; i++) FlSpot(i.toDouble(), lo[i])],
      isCurved: false,
      barWidth: 0,
      color: Colors.transparent,
      dotData: const FlDotData(show: false),
    );
    final hiLine = LineChartBarData(
      spots: [for (var i = 0; i < length; i++) FlSpot(i.toDouble(), hi[i])],
      isCurved: false,
      barWidth: 0,
      color: Colors.transparent,
      dotData: const FlDotData(show: false),
    );
    final meanLine = LineChartBarData(
      spots: [for (var i = 0; i < length; i++) FlSpot(i.toDouble(), mean[i])],
      isCurved: false,
      barWidth: 2,
      color: AppColors.amber,
      dotData: const FlDotData(show: false),
    );

    final bars = [...memberLines, loLine, hiLine, meanLine];
    final loIdx = bars.length - 3;
    final hiIdx = bars.length - 2;
    final meanIdx = bars.length - 1;

    final hasTimes = times != null && times!.length >= length && length > 0;
    final t = hasTimes ? times!.sublist(0, length) : null;
    final plan = t != null ? planAxisLabels(t, width) : null;

    return LineChart(LineChartData(
      gridData: FlGridData(show: true, getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 0.5)),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: plan != null,
            reservedSize: 24,
            interval: plan?.interval,
            getTitlesWidget: (v, m) {
              if (plan == null || t == null) return const SizedBox.shrink();
              final i = v.round();
              if (i < 0 || i >= t.length) return const SizedBox.shrink();
              return Padding(padding: const EdgeInsets.only(top: 3), child: Text(plan.axisFormat(t[i]), style: monoStyle.copyWith(fontSize: 8, color: AppColors.grey)));
            },
          ),
        ),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, m) => Text(v.toStringAsFixed(0), style: monoStyle.copyWith(fontSize: 10, color: AppColors.grey)))),
      ),
      borderData: FlBorderData(show: false),
      betweenBarsData: [BetweenBarsData(fromIndex: loIdx, toIndex: hiIdx, color: AppColors.amberDim.withOpacity(0.18))],
      lineTouchData: LineTouchData(
        touchSpotThreshold: 20,
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) => spots.map((s) {
            if (s.barIndex != meanIdx) return null; // only tooltip the mean line
            final i = s.x.round();
            final dateLabel = (plan != null && t != null && i >= 0 && i < t.length) ? plan.tooltipFormat(t[i]) : '';
            final valueLabel = 'MEAN ${s.y.toStringAsFixed(1)}$unit';
            return LineTooltipItem(dateLabel.isEmpty ? valueLabel : '$dateLabel\n$valueLabel', monoStyle.copyWith(fontSize: 11, color: AppColors.white, fontWeight: FontWeight.bold));
          }).toList(),
        ),
      ),
      lineBarsData: bars,
    ));
  }
}
