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

/// Compact axis label for a timestamp -- e.g. "3/14 09h" for hourly series,
/// falls back gracefully for daily/longer-range series (hour is still shown
/// but reads as "00h" for daily data, which is an acceptable trade-off vs.
/// threading a separate "isDaily" flag through every chart call site).
String formatAxisDate(DateTime d) => '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}h';

Widget _timeTitle(double value, List<DateTime>? times) {
  if (times == null || times.isEmpty) return const SizedBox.shrink();
  final i = value.round();
  if (i < 0 || i >= times.length) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(formatAxisDate(times[i]), style: monoStyle.copyWith(fontSize: 9, color: theme.AppColors.grey)),
  );
}

double? _axisInterval(List<DateTime>? times) {
  if (times == null || times.length < 2) return null;
  // Aim for ~4-5 labels across the chart regardless of series length.
  return (times.length / 4).ceilToDouble().clamp(1, times.length.toDouble());
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
          : LineChart(LineChartData(
        gridData: FlGridData(show: true, getDrawingHorizontalLine: (_) => FlLine(color: gridColor, strokeWidth: 0.5)),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, m) => Text(v.toStringAsFixed(0), style: monoStyle.copyWith(fontSize: 10, color: theme.AppColors.grey)))),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: times != null && times!.isNotEmpty,
              reservedSize: 26,
              interval: _axisInterval(times),
              getTitlesWidget: (v, m) => _timeTitle(v, times),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [LineChartBarData(spots: points, isCurved: false, barWidth: 1.4, color: spec.tier == FieldTier.primary ? theme.AppColors.amber : theme.AppColors.grey, dotData: const FlDotData(show: false))],
      )),
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
          : BarChart(BarChartData(
        gridData: FlGridData(show: true, getDrawingHorizontalLine: (_) => FlLine(color: gridColor, strokeWidth: 0.5)),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: times != null && times!.isNotEmpty,
              reservedSize: 26,
              interval: _axisInterval(times),
              getTitlesWidget: (v, m) => _timeTitle(v, times),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [for (var i = 0; i < values.length; i++) BarChartGroupData(x: i, barRods: [BarChartRodData(toY: values[i], color: spec.tier == FieldTier.primary ? theme.AppColors.amber : theme.AppColors.grey, width: 3)])],
      )),
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