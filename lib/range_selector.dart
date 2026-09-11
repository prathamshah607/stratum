// lib/range_selector.dart
//
// Master date range control, mounted in the AppBar above the mode tabs.
// Every mode reads its data window directly from AppState.rangeStart /
// rangeEnd (see providers.dart), via two fields -- START and END.
//
// Two things layered on top of the plain date picker:
//  - The picker's firstDate/lastDate are the mode's REAL selectable window
//    (see modePickerBounds() in models.dart) -- e.g. Climate physically
//    cannot open past 2050-01-01, Marine cannot go more than 8 days into
//    the future. A caption under the fields (and the dialog's helpText)
//    spells the same window out in plain text, so the limitation is visible
//    before the person even opens the calendar, not just enforced silently
//    inside it.
//  - A follow-up time-of-day picker, shown only when the current mode +
//    current span would actually fetch hourly data (allowTimeOfDay, computed
//    by the caller via resolveRange()) -- daily-only modes/spans skip it
//    since an hour is meaningless for a daily aggregate.

import 'package:flutter/material.dart';
import 'theme.dart';

class DateRangeBar extends StatelessWidget {
  final DateTime start;
  final DateTime end;
  /// Mode-specific absolute bounds (see modePickerBounds() in models.dart) --
  /// the picker physically cannot select outside these, instead of relying
  /// on a fetch-time clamp to silently correct an invalid pick after the fact.
  final DateTime firstSelectableDate;
  final DateTime lastSelectableDate;
  /// Whether the current mode/span supports hourly data -- shows a
  /// time-of-day picker after the date is chosen when true.
  final bool allowTimeOfDay;
  /// Plain-text summary of firstSelectableDate/lastSelectableDate, e.g.
  /// "AVAILABLE 2026-06-11 → 2026-09-19" -- shown under the fields and as
  /// the picker dialog's helpText.
  final String constraintLabel;
  final void Function(DateTime) onStartChanged;
  final void Function(DateTime) onEndChanged;
  const DateRangeBar({
    super.key,
    required this.start,
    required this.end,
    required this.firstSelectableDate,
    required this.lastSelectableDate,
    required this.allowTimeOfDay,
    required this.constraintLabel,
    required this.onStartChanged,
    required this.onEndChanged,
  });

  static String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  static String _fmtTime(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  String _fmt(DateTime d) => allowTimeOfDay ? '${_fmtDate(d)} ${_fmtTime(d)}' : _fmtDate(d);

  ThemeData _pickerTheme() => ThemeData.dark().copyWith(
        colorScheme: ColorScheme.dark(primary: AppColors.amber, surface: AppColors.panel, onSurface: AppColors.white),
      );

  Future<void> _pick(BuildContext context, DateTime initial, void Function(DateTime) onPicked) async {
    final clampedInitial = initial.isBefore(firstSelectableDate)
        ? firstSelectableDate
        : (initial.isAfter(lastSelectableDate) ? lastSelectableDate : initial);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: clampedInitial,
      firstDate: firstSelectableDate,
      lastDate: lastSelectableDate,
      helpText: constraintLabel,
      builder: (context, child) => Theme(data: _pickerTheme(), child: child!),
    );
    if (pickedDate == null) return;

    var result = DateTime.utc(pickedDate.year, pickedDate.month, pickedDate.day, clampedInitial.hour, clampedInitial.minute);

    // Hourly-capable modes/spans get a follow-up time-of-day picker --
    // daily-only modes (Climate/Flood) or a span already forced to daily by
    // the >1-year rule skip this entirely.
    if (allowTimeOfDay && context.mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: clampedInitial.hour, minute: clampedInitial.minute),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: Theme(data: _pickerTheme(), child: child!),
        ),
      );
      if (pickedTime != null) {
        // UTC, not local -- the picker fields represent the same clock as
        // every timestamp elsewhere in the app (API responses, table rows,
        // chart axes are all UTC; see screens.dart's _formatTableTime
        // comment). Building this as a LOCAL DateTime was the actual bug:
        // "07:36" typed here meant 07:36 IST, but every comparison and
        // every displayed row time treated it as if it were 07:36 UTC --
        // a silent 5:30 offset that showed up as data "starting" at what
        // looked like the wrong hour.
        result = DateTime.utc(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
      }
    }

    // The date-only picker above can't see time-of-day -- re-clamp the
    // final combined value in case adding a time pushed it just past a
    // boundary computed to the minute (e.g. a relative "now + 8 days").
    if (result.isBefore(firstSelectableDate)) result = firstSelectableDate;
    if (result.isAfter(lastSelectableDate)) result = lastSelectableDate;
    onPicked(result);
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
          Icon(allowTimeOfDay ? Icons.schedule : Icons.calendar_today, size: 12, color: AppColors.grey),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.panel,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            _field(context, 'START', start, (d) => onStartChanged(d)),
            const SizedBox(width: 10),
            Icon(Icons.arrow_forward, size: 14, color: AppColors.greyDim),
            const SizedBox(width: 10),
            _field(context, 'END', end, (d) => onEndChanged(d)),
          ]),
          if (constraintLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 2),
              child: Text(constraintLabel, style: monoStyle.copyWith(fontSize: 9, color: AppColors.greyDim, letterSpacing: 0.5)),
            ),
        ],
      ),
    );
  }
}
