// lib/range_selector.dart
//
// Master date range control, mounted in the AppBar above the mode tabs.
// Replaces the old 24H/7D/1M/3M/... preset SegmentedButton entirely: every
// mode now reads its data window directly from AppState.rangeStart /
// rangeEnd (see providers.dart), via just two fields -- START and END.
// This is also half of the fix for Historical mode coming back empty: it
// stops a preset like "5Y" from silently forcing a huge date span on every
// mode at once regardless of whether that mode's resolution can sanely
// cover it.

import 'package:flutter/material.dart';
import 'theme.dart';

class DateRangeBar extends StatelessWidget {
  final DateTime start;
  final DateTime end;
  final void Function(DateTime) onStartChanged;
  final void Function(DateTime) onEndChanged;
  const DateRangeBar({
    super.key,
    required this.start,
    required this.end,
    required this.onStartChanged,
    required this.onEndChanged,
  });

  static String _fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pick(BuildContext context, DateTime initial, void Function(DateTime) onPicked) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year + 10),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(primary: AppColors.amber, surface: AppColors.panel, onSurface: AppColors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) onPicked(picked);
  }

  Widget _field(BuildContext context, String label, DateTime value, void Function(DateTime) onPicked) {
    return InkWell(
      onTap: () => _pick(context, value, onPicked),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(4)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$label  ', style: monoStyle.copyWith(fontSize: 10, color: AppColors.grey, letterSpacing: 1)),
          Text(_fmt(value), style: monoStyle.copyWith(fontSize: 12, color: AppColors.amber, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          const Icon(Icons.calendar_today, size: 12, color: AppColors.grey),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.panel,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        _field(context, 'START', start, (d) => onStartChanged(d)),
        const SizedBox(width: 10),
        Icon(Icons.arrow_forward, size: 14, color: AppColors.greyDim),
        const SizedBox(width: 10),
        _field(context, 'END', end, (d) => onEndChanged(d)),
      ]),
    );
  }
}
