// lib/widgets.dart
//
// Reusable primitives. Every domain page composes these three widgets only:
// StandardLineChart, StandardBarChart, RawDataTable. Unit labels are derived
// live from FieldSpec.unitLabel(unitSettings), so toggling metric/imperial
// updates every chart's axis/title text without touching any mode-specific
// code.
//
// Panels no longer carry a fixed pixel height -- they're always placed
// inside a GridView cell sized by _DynamicGrid's aspect ratio (screens.dart),
// so they now simply fill whatever space that cell gives them. Line/bar
// charts also take an optional `times` list so the x-axis can show actual
// timestamps instead of being hidden.
//
// AXIS FIX: bottom-axis labels used to use a fixed "show ~4 labels, always
// MM/DD HH:mm" rule regardless of how wide the chart actually rendered or
// how long the selected date range was. That produced two failure modes at
// once -- on a narrow panel the 4 labels still overlapped and became
// unreadable, and on a multi-year Historical/Climate range every label
// printed the same "0:00" over and over because the format never adapted
// to the span. planAxisLabels() below fixes both: it's handed the chart's
// REAL measured width (via LayoutBuilder) and picks (a) the largest label
// count that still fits without collision and (b) a date format scaled to
// the actual span (time-of-day for <2 days, MM/DD for <2 years, MM/YYYY
// beyond that), so labels are always visible and always distinct.

import 'dart:convert';
import 'dart:js_interop';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:web/web.dart' as web;
import 'models.dart';
import 'theme.dart' as theme;

const bgColor = theme.AppColors.bg;
const panelColor = theme.AppColors.panel;
const gridColor = theme.AppColors.border;
const monoStyle = theme.monoStyle;

// ---------------------------------------------------------------------------
// Dynamic x-axis label planning -- shared by EVERY chart in the app
// (StandardLineChart/StandardBarChart here, MetricPanel in
// forecast_widgets.dart, FanChart, AqiGauge's trend chart) so "how many
// labels fit" and "what format reads best for this span" are computed
// identically everywhere, and so no chart ever formats a date itself.
// All dates are day-first, 24-hour ("DD/MM", "HH:mm") -- Indian
// convention, never MM/DD.
// ---------------------------------------------------------------------------

String _pad2(int n) => n.toString().padLeft(2, '0');

const _monthAbbr = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _weekdayAbbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// 24-hour clock, "HH:mm".
String indianTime(DateTime d) => '${_pad2(d.hour)}:${_pad2(d.minute)}';

/// Day-first short date, "DD/MM".
String indianDateShort(DateTime d) => '${_pad2(d.day)}/${_pad2(d.month)}';

/// "MMM YYYY", e.g. "Jul 2026" -- used once a span is long enough that
/// day-level labels would all collapse into duplicates.
String indianMonthYear(DateTime d) => '${_monthAbbr[d.month - 1]} ${d.year}';

/// Full weekday + day-first date + 24h time, e.g. "Fri, 31/07/2026, 14:30".
/// This is what every chart's hover/tap tooltip shows, regardless of how
/// compressed the axis labels themselves are.
String indianFullDateTime(DateTime d) => '${_weekdayAbbr[d.weekday - 1]}, ${_pad2(d.day)}/${_pad2(d.month)}/${d.year}, ${indianTime(d)}';

String _emptyFormat(DateTime d) => '';

/// interval = how many data-point steps between shown labels.
/// axisFormat = compact format used ON the axis (scales with span).
/// tooltipFormat = always the full day-first-24h timestamp, for hover/tap.
class AxisLabelPlan {
  final double interval;
  final String Function(DateTime) axisFormat;
  final String Function(DateTime) tooltipFormat;
  const AxisLabelPlan(this.interval, this.axisFormat, {this.tooltipFormat = indianFullDateTime});
}

/// Picks a label interval and date format so x-axis labels never overlap --
/// spaced by the chart's ACTUAL measured pixel width, not a fixed count --
/// and never repeat the same-looking value back to back. The pixel budget
/// per label scales with how wide that format's text actually renders (a
/// bare "14:30" needs far less room than "31/07 14:30"), which is what
/// stops dense ranges from letting labels collide into an unreadable grey
/// smear the way a single fixed budget (or no width check at all, as
/// FanChart/AqiGauge previously did) used to.
AxisLabelPlan planAxisLabels(List<DateTime> times, double availableWidth) {
  if (times.isEmpty) return const AxisLabelPlan(1, _emptyFormat);
  final spanHours = times.last.difference(times.first).inMinutes.abs() / 60;
  final String Function(DateTime) fmt;
  final double minPxPerLabel;
  if (spanHours < 48) {
    fmt = indianTime;
    minPxPerLabel = 46;
  } else if (spanHours < 24 * 5) {
    fmt = (d) => '${indianDateShort(d)} ${indianTime(d)}';
    minPxPerLabel = 92;
  } else if (spanHours < 24 * 730) {
    fmt = indianDateShort;
    minPxPerLabel = 56;
  } else {
    fmt = indianMonthYear;
    minPxPerLabel = 74;
  }
  if (times.length < 2 || availableWidth <= 0) return AxisLabelPlan(1, fmt);
  final maxLabels = (availableWidth / minPxPerLabel).floor().clamp(2, times.length);
  final interval = (times.length / maxLabels).ceilToDouble().clamp(1, times.length.toDouble());
  return AxisLabelPlan(interval.toDouble(), fmt);
}

class StandardLineChart extends StatelessWidget {
  final FieldSpec spec;
  final UnitSettings units;
  final List<FlSpot> points;
  final List<DateTime>? times;
  const StandardLineChart({super.key, required this.spec, required this.units, required this.points, this.times});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: '${spec.label} (${spec.unitLabel(units)})',
      child: points.isEmpty
          ? const _NoDataPlaceholder()
          : LayoutBuilder(builder: (context, constraints) {
              final t = times;
              final plan = (t != null && t.isNotEmpty) ? planAxisLabels(t, constraints.maxWidth) : null;
              return LineChart(LineChartData(
                gridData: FlGridData(show: true, getDrawingHorizontalLine: (_) => FlLine(color: gridColor, strokeWidth: 0.5)),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, m) => Text(v.toStringAsFixed(0), style: monoStyle.copyWith(fontSize: 10, color: theme.AppColors.grey)))),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: plan != null,
                      reservedSize: 26,
                      interval: plan?.interval,
                      getTitlesWidget: (v, m) {
                        if (plan == null || t == null) return const SizedBox.shrink();
                        final i = v.round();
                        if (i < 0 || i >= t.length) return const SizedBox.shrink();
                        return Padding(padding: const EdgeInsets.only(top: 4), child: Text(plan.axisFormat(t[i]), style: monoStyle.copyWith(fontSize: 9, color: theme.AppColors.grey)));
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
                      final valueLabel = '${s.y.toStringAsFixed(1)}${spec.unitLabel(units)}';
                      return LineTooltipItem(dateLabel.isEmpty ? valueLabel : '$dateLabel\n$valueLabel', monoStyle.copyWith(fontSize: 11, color: theme.AppColors.white, fontWeight: FontWeight.bold));
                    }).toList(),
                  ),
                ),
                lineBarsData: [LineChartBarData(spots: points, isCurved: false, barWidth: 1.4, color: spec.tier == FieldTier.primary ? theme.AppColors.amber : theme.AppColors.grey, dotData: const FlDotData(show: false))],
              ));
            }),
    );
  }
}

class StandardBarChart extends StatelessWidget {
  final FieldSpec spec;
  final UnitSettings units;
  final List<double> values;
  final List<DateTime>? times;
  const StandardBarChart({super.key, required this.spec, required this.units, required this.values, this.times});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: '${spec.label} (${spec.unitLabel(units)})',
      child: values.isEmpty
          ? const _NoDataPlaceholder()
          : LayoutBuilder(builder: (context, constraints) {
              final t = times;
              final plan = (t != null && t.isNotEmpty) ? planAxisLabels(t, constraints.maxWidth) : null;
              return BarChart(BarChartData(
                gridData: FlGridData(show: true, getDrawingHorizontalLine: (_) => FlLine(color: gridColor, strokeWidth: 0.5)),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: plan != null,
                      reservedSize: 26,
                      interval: plan?.interval,
                      getTitlesWidget: (v, m) {
                        if (plan == null || t == null) return const SizedBox.shrink();
                        final i = v.round();
                        if (i < 0 || i >= t.length) return const SizedBox.shrink();
                        return Padding(padding: const EdgeInsets.only(top: 4), child: Text(plan.axisFormat(t[i]), style: monoStyle.copyWith(fontSize: 9, color: theme.AppColors.grey)));
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final i = group.x.toInt();
                      final dateLabel = (plan != null && t != null && i >= 0 && i < t.length) ? plan.tooltipFormat(t[i]) : '';
                      final valueLabel = '${rod.toY.toStringAsFixed(1)}${spec.unitLabel(units)}';
                      return BarTooltipItem(dateLabel.isEmpty ? valueLabel : '$dateLabel\n$valueLabel', monoStyle.copyWith(fontSize: 11, color: theme.AppColors.white, fontWeight: FontWeight.bold));
                    },
                  ),
                ),
                barGroups: [for (var i = 0; i < values.length; i++) BarChartGroupData(x: i, barRods: [BarChartRodData(toY: values[i], color: spec.tier == FieldTier.primary ? theme.AppColors.amber : theme.AppColors.grey, width: 3)])],
              ));
            }),
    );
  }
}

class _NoDataPlaceholder extends StatelessWidget {
  const _NoDataPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('NO DATA AVAILABLE', style: monoStyle.copyWith(fontSize: 11, color: theme.AppColors.greyDim)));
  }
}

/// Mode-agnostic table + CSV/JSON download. Only columns/rows change per mode.
class RawDataTable extends StatelessWidget {
  final List<String> columns;
  final List<List<dynamic>> rows;
  const RawDataTable({super.key, required this.columns, required this.rows});

  void _download(String content, String filename, String mime) {
    final bytes = utf8.encode(content);
    final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = filename;
    anchor.click();
    web.URL.revokeObjectURL(url);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Spacer(),
          TextButton.icon(
            onPressed: () => _download(const ListToCsvConverter().convert([columns, ...rows]), 'data.csv', 'text/csv'),
            icon: const Icon(Icons.download, size: 16),
            label: const Text('CSV'),
          ),
          TextButton.icon(
            onPressed: () => _download(jsonEncode({'columns': columns, 'rows': rows}), 'data.json', 'application/json'),
            icon: const Icon(Icons.download, size: 16),
            label: const Text('JSON'),
          ),
        ]),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(panelColor),
              columns: [for (final c in columns) DataColumn(label: Text(c, style: monoStyle))],
              rows: [for (final r in rows) DataRow(cells: [for (final v in r) DataCell(Text('$v', style: monoStyle))])],
            ),
          ),
        ),
      ],
    );
  }
}

/// Metric/Imperial toggle, mounted once in the dashboard app bar. Reused as
/// the only unit-control widget in the whole app.
class UnitToggle extends StatelessWidget {
  final UnitSystem active;
  final void Function(UnitSystem) onChanged;
  const UnitToggle({super.key, required this.active, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<UnitSystem>(
      segments: const [
        ButtonSegment(value: UnitSystem.metric, label: Text('METRIC')),
        ButtonSegment(value: UnitSystem.imperial, label: Text('IMPERIAL')),
      ],
      selected: {active},
      onSelectionChanged: (s) => onChanged(s.first),
      style: ButtonStyle(
        textStyle: WidgetStateProperty.all(monoStyle.copyWith(fontSize: 11)),
        foregroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? theme.AppColors.bg : theme.AppColors.grey),
        backgroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? theme.AppColors.amber : theme.AppColors.panel),
        side: WidgetStateProperty.all(BorderSide(color: theme.AppColors.border)),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final Widget child;
  const _Panel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    // No fixed height: this always sits inside a GridView cell whose size is
    // set by the caller's aspect ratio (see _DynamicGrid in screens.dart),
    // so the chart genuinely scales with available screen space.
    return Container(
      decoration: BoxDecoration(color: panelColor, border: Border.all(color: gridColor)),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: monoStyle.copyWith(fontSize: 12, color: theme.AppColors.grey)),
          const SizedBox(height: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}
