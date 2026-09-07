// lib/forecast_widgets.dart
//
// Two widgets that replace "just a grid of charts" with text-first, dense
// panels in the Bloomberg mold:
//
// - MetricPanel: every primary-tier field gets a big current value, a
//   colored delta vs. the previous point, and min/max/mean stats sitting
//   directly next to its chart -- never a bare chart alone. No fixed pixel
//   height anymore: it fills whatever cell _DynamicGrid gives it, and its
//   mini chart shows real timestamps along the bottom when `times` is
//   supplied.
// - ForecastStrip: the 14-day-outlook + tap-to-expand-hourly view, built
//   from WMO weather codes (see weather_codes.dart) with Material icons.

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'theme.dart';
import 'weather_codes.dart';

// ---------------------------------------------------------------------------
// MetricPanel
// ---------------------------------------------------------------------------

class MetricPanel extends StatelessWidget {
  final String label;
  final String unit;
  final List<double> values; // already null-filtered, chronological order
  final bool isBar;
  final List<DateTime>? times; // paired 1:1 with values, for the x-axis
  const MetricPanel({super.key, required this.label, required this.unit, required this.values, this.isBar = false, this.times});

  @override
  Widget build(BuildContext context) {
    final hasData = values.length >= 2;
    final current = values.isEmpty ? null : values.last;
    final delta = hasData ? values.last - values[values.length - 2] : null;
    final min = values.isEmpty ? null : values.reduce((a, b) => a < b ? a : b);
    final max = values.isEmpty ? null : values.reduce((a, b) => a > b ? a : b);
    final mean = values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length;

    return Container(
      decoration: BoxDecoration(color: AppColors.panel, border: Border.all(color: AppColors.border)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: monoStyle.copyWith(fontSize: 12, color: AppColors.grey, letterSpacing: 1)),
          const SizedBox(height: 6),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 108,
                  child: values.isEmpty
                      ? Text('--', style: monoStyle.copyWith(fontSize: 28, color: AppColors.grey))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Text('${current!.toStringAsFixed(1)}$unit', style: monoStyle.copyWith(fontSize: 26, color: AppColors.amber, fontWeight: FontWeight.bold)),
                            if (delta != null)
                              Row(children: [
                                Icon(delta > 0 ? Icons.arrow_drop_up : (delta < 0 ? Icons.arrow_drop_down : Icons.remove), color: deltaColor(delta), size: 18),
                                Text('${delta.abs().toStringAsFixed(1)}$unit', style: monoStyle.copyWith(fontSize: 12, color: deltaColor(delta))),
                              ]),
                            const SizedBox(height: 10),
                            _statRow('HI', max, unit),
                            _statRow('LO', min, unit),
                            _statRow('AVG', mean, unit),
                          ],
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: values.isEmpty
                      ? Center(child: Text('NO DATA AVAILABLE', style: monoStyle.copyWith(fontSize: 11, color: AppColors.greyDim)))
                      : (isBar ? _bar() : _line()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRow(String label, double? v, String unit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: monoStyle.copyWith(fontSize: 10, color: AppColors.grey)),
        Text(v == null ? '--' : '${v.toStringAsFixed(1)}$unit', style: monoStyle.copyWith(fontSize: 11, color: AppColors.white)),
      ]),
    );
  }

  AxisTitles _bottomTitles() {
    return AxisTitles(
      sideTitles: SideTitles(
        showTitles: times != null && times!.isNotEmpty,
        reservedSize: 20,
        interval: times != null && times!.length > 1 ? (times!.length / 3).ceilToDouble().clamp(1, times!.length.toDouble()) : null,
        getTitlesWidget: (v, m) {
          final t = times;
          if (t == null || t.isEmpty) return const SizedBox.shrink();
          final i = v.round();
          if (i < 0 || i >= t.length) return const SizedBox.shrink();
          final d = t[i];
          return Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}h', style: monoStyle.copyWith(fontSize: 8, color: AppColors.grey)),
          );
        },
      ),
    );
  }

  Widget _line() {
    return LineChart(LineChartData(
      gridData: FlGridData(show: true, getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 0.5)),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: _bottomTitles(),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
          isCurved: false,
          barWidth: 1.6,
          color: AppColors.amber,
          dotData: const FlDotData(show: false),
        ),
      ],
    ));
  }

  Widget _bar() {
    return BarChart(BarChartData(
      gridData: FlGridData(show: true, getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 0.5)),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: _bottomTitles(),
      ),
      borderData: FlBorderData(show: false),
      barGroups: [for (var i = 0; i < values.length; i++) BarChartGroupData(x: i, barRods: [BarChartRodData(toY: values[i], color: AppColors.amber, width: 3)])],
    ));
  }
}

// ---------------------------------------------------------------------------
// ForecastStrip
// ---------------------------------------------------------------------------

class HourForecast {
  final DateTime time;
  final double temp;
  final int weatherCode;
  final double? precipProbability;
  const HourForecast({required this.time, required this.temp, required this.weatherCode, this.precipProbability});
}

class DayForecast {
  final DateTime date;
  final int weatherCode;
  final double tempMax;
  final double tempMin;
  final List<HourForecast> hours; // empty if hourly data isn't loaded
  const DayForecast({required this.date, required this.weatherCode, required this.tempMax, required this.tempMin, this.hours = const []});
}

class ForecastStrip extends StatefulWidget {
  final List<DayForecast> days;
  final String tempUnit;
  const ForecastStrip({super.key, required this.days, required this.tempUnit});

  @override
  State<ForecastStrip> createState() => _ForecastStripState();
}

class _ForecastStripState extends State<ForecastStrip> {
  int? expanded;

  static const _weekday = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  @override
  Widget build(BuildContext context) {
    if (widget.days.isEmpty) {
      return Container(
        height: 90,
        alignment: Alignment.center,
        color: AppColors.panel,
        child: Text('NO FORECAST DATA', style: monoStyle.copyWith(color: AppColors.greyDim, fontSize: 12)),
      );
    }
    return Container(
      color: AppColors.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: widget.days.length,
              itemBuilder: (context, i) {
                final d = widget.days[i];
                final info = weatherCodeInfo(d.weatherCode);
                final isOpen = expanded == i;
                return GestureDetector(
                  onTap: () => setState(() => expanded = isOpen ? null : i),
                  child: Container(
                    width: 96,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isOpen ? AppColors.panelAlt : AppColors.panel,
                      border: Border.all(color: isOpen ? AppColors.amber : AppColors.border),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_weekday[d.date.weekday - 1], style: monoStyle.copyWith(fontSize: 11, color: AppColors.grey)),
                        Icon(info.icon, color: info.color, size: 26),
                        Text(info.label, style: monoStyle.copyWith(fontSize: 9, color: AppColors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('${d.tempMax.toStringAsFixed(0)}° / ${d.tempMin.toStringAsFixed(0)}°', style: monoStyle.copyWith(fontSize: 12, color: AppColors.white)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (expanded != null && widget.days[expanded!].hours.isNotEmpty)
            Container(
              height: 100,
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                itemCount: widget.days[expanded!].hours.length,
                itemBuilder: (context, i) {
                  final h = widget.days[expanded!].hours[i];
                  final info = weatherCodeInfo(h.weatherCode);
                  return Container(
                    width: 60,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${h.time.hour.toString().padLeft(2, '0')}:00', style: monoStyle.copyWith(fontSize: 10, color: AppColors.grey)),
                        Icon(info.icon, color: info.color, size: 18),
                        Text('${h.temp.toStringAsFixed(0)}°', style: monoStyle.copyWith(fontSize: 12, color: AppColors.white)),
                        if (h.precipProbability != null)
                          Text('${h.precipProbability!.toStringAsFixed(0)}%', style: monoStyle.copyWith(fontSize: 9, color: AppColors.amberDim)),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
