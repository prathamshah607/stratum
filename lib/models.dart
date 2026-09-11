// lib/models.dart
//
// Core value types. Field enum VALUES are the real, verified open_meteo
// package enums (WeatherHourly, HistoricalHourly, ClimateDaily, MarineHourly,
// AirQualityHourly, FloodDaily, EnsembleHourly). Each enum value in the real
// package is documented to carry variable/altitude/depth/aggregation
// metadata internally, but since that internal shape isn't guaranteed
// stable across versions, FieldSpec explicitly stores label/unit/chart/color
// itself -- "add one FieldSpec line, get one widget" stays simple AND safe.

import 'package:flutter/material.dart';
import 'package:open_meteo/open_meteo.dart';
enum ModeType { weather, historical, climate, marine, airQuality, flood, ensemble, elevation, geocoding }

/// Only ModeType.weather currently exposes a user-facing Hourly/Daily
/// sub-toggle (WeatherHourly: 65 verified values, WeatherDaily: 59 verified
/// values -- both extracted from real package source, July 2026). Mirrors
/// the Hourly/Daily sibling-enum pattern already used internally by
/// Historical, Climate, and Ensemble modes.
enum TemporalResolution { hourly, daily }

extension ModeMeta on ModeType {
  String get label => switch (this) {
        ModeType.weather => 'Weather',
        ModeType.historical => 'Historical',
        ModeType.climate => 'Climate Forecast',
        ModeType.marine => 'Marine',
        ModeType.airQuality => 'Air Quality',
        ModeType.flood => 'Flood',
        ModeType.ensemble => 'Ensemble',
        ModeType.elevation => 'Elevation',
        ModeType.geocoding => 'Location Info',
      };

  /// True for the 7 modes with a real time-series enum + request() call.
  /// Elevation and Geocoding are single-value metadata lookups, shown in
  /// the dashboard header instead of a chart tab.
  bool get hasTimeSeries => this != ModeType.elevation && this != ModeType.geocoding;

  /// Weather and Historical both have a wired Hourly/Daily sub-toggle.
  /// Historical defaults to daily (see AppState.historicalResolution) --
  /// requesting years of hourly data across several primary fields is what
  /// was causing Historical's panels to come back empty.
  bool get hasResolutionToggle => this == ModeType.weather || this == ModeType.historical;
}

enum ChartKind { line, bar }

/// primary: always rendered, full-size panel, first in layout order, and the
/// ONLY tier fetched by default. secondary: never fetched until the user
/// explicitly picks it via the "SELECT METRICS" dialog -- see
/// providers.dart's activeFieldsProvider.
enum FieldTier { primary, secondary }

/// Which of Open-Meteo's 3 user-adjustable unit families (if any) applies.
enum UnitCategory { temperature, windspeed, precipitation, fixed }

/// Declarative description of one measurable variable. Adding a FieldSpec to
/// a mode's list in providers.dart is the ONLY step needed to surface a new
/// chart widget. enumKey is the real open_meteo enum instance passed
/// directly into request(hourly: {...}) / request(daily: {...}).
class FieldSpec {
  final dynamic enumKey;
  final String label;
  final UnitCategory unitCategory;
  final String fixedUnit;
  final ChartKind chart;
  final ModeType mode;
  final FieldTier tier;
  final String category;

  /// Deprecated: chart color now comes from [tier] (amber=primary,
  /// grey=secondary), never from a per-field hue. Kept only so the existing
  /// registry in providers.dart (which still passes `color:` on every entry)
  /// doesn't need a mass edit in the same pass as the tier/category rollout.
  final Color? color;

  const FieldSpec({
    required this.enumKey,
    required this.label,
    required this.mode,
    this.unitCategory = UnitCategory.fixed,
    this.fixedUnit = '',
    this.chart = ChartKind.line,
    this.tier = FieldTier.secondary,
    this.category = 'Other',
    this.color,
  });

  /// JSON key open_meteo uses in its hourly/daily response map. Matches the
  /// enum constant's own name (verified: enum .name getter, Dart standard).
  String get jsonKey {
    final e = enumKey;
    if (e is WeatherHourly) return e.name;
    if (e is WeatherDaily) return e.name;
    if (e is HistoricalHourly) return e.name;
    if (e is HistoricalDaily) return e.name;
    if (e is ClimateDaily) return e.name;
    if (e is MarineHourly) return e.name;
    if (e is AirQualityHourly) return e.name;
    if (e is FloodDaily) return e.name;
    if (e is EnsembleHourly) return e.name;
    return e.toString();
  }

  String unitLabel(UnitSettings units) => switch (unitCategory) {
        UnitCategory.temperature => units.temperature == TemperatureUnit.celsius ? '°C' : '°F',
        UnitCategory.windspeed => switch (units.windspeed) {
            WindspeedUnit.kmh => 'km/h',
            WindspeedUnit.ms => 'm/s',
            WindspeedUnit.mph => 'mph',
            WindspeedUnit.kn => 'kn',
          },
        UnitCategory.precipitation => units.precipitation == PrecipitationUnit.mm ? 'mm' : 'in',
        UnitCategory.fixed => fixedUnit,
      };
}

enum UnitSystem { metric, imperial }

/// Groups the 3 user-adjustable Open-Meteo unit enums (verified: all 7
/// data-bearing API classes accept these as constructor params).
class UnitSettings {
  final TemperatureUnit temperature;
  final WindspeedUnit windspeed;
  final PrecipitationUnit precipitation;
  const UnitSettings({required this.temperature, required this.windspeed, required this.precipitation});

  static const metric = UnitSettings(
    temperature: TemperatureUnit.celsius,
    windspeed: WindspeedUnit.kmh,
    precipitation: PrecipitationUnit.mm,
  );
  static const imperial = UnitSettings(
    temperature: TemperatureUnit.fahrenheit,
    windspeed: WindspeedUnit.mph,
    precipitation: PrecipitationUnit.inch,
  );

  String get key => temperature == TemperatureUnit.celsius ? 'metric' : 'imperial';
}

class LocationParams {
  final String name;
  final double lat;
  final double lon;
  const LocationParams({required this.name, required this.lat, required this.lon});

  Map<String, String> toQuery() => {'location': name, 'lat': lat.toString(), 'lon': lon.toString()};
}

/// Cache key for the data-fetch provider. Value-equality means identical
/// (location, mode, rangeStart, rangeEnd, fields, units) requests are never
/// refetched. rangeStart/rangeEnd come directly from the master START/END
/// date fields in the app bar (see DateRangeBar in range_selector.dart).
class FetchParams {
  final ModeType mode;
  final LocationParams location;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final List<String> fieldKeys;
  final String unitsKey;
  final TemporalResolution resolution;

  const FetchParams({
    required this.mode,
    required this.location,
    required this.rangeStart,
    required this.rangeEnd,
    required this.fieldKeys,
    required this.unitsKey,
    this.resolution = TemporalResolution.hourly,
  });

  @override
  bool operator ==(Object other) =>
      other is FetchParams &&
      other.mode == mode &&
      other.location.lat == location.lat &&
      other.location.lon == location.lon &&
      other.rangeStart == rangeStart &&
      other.rangeEnd == rangeEnd &&
      other.fieldKeys.join(',') == fieldKeys.join(',') &&
      other.unitsKey == unitsKey &&
      other.resolution == resolution;

  @override
  int get hashCode => Object.hash(mode, location.lat, location.lon, rangeStart, rangeEnd, fieldKeys.join(','), unitsKey, resolution);
}

// ---------------------------------------------------------------------------
// ModeCapability / resolveRange -- the single source of truth for "what
// date window + resolution is this mode actually allowed to request".
// Both the data-fetch layer (providers.dart's dataProvider) and the UI
// (range_selector.dart's date pickers, screens.dart's hourly/daily toggle)
// call resolveRange()/modePickerBounds() instead of each independently
// guessing at day-count clamps -- that drift is what caused the Ensemble
// pastDays bug and the missing Marine/AirQuality forecastDays in the first
// place.
// ---------------------------------------------------------------------------

class ModeCapability {
  /// Whether this mode has an hourly resolution at all (vs. daily-only).
  final bool supportsHourly;
  /// Relative past window in days (pastDays-style param). 0 = not supported.
  final int maxPastDays;
  /// Relative future window in days (forecastDays-style param). 0 = not supported.
  final int maxFutureDays;
  /// Absolute earliest selectable date, if the mode has a fixed archive start.
  final DateTime? calendarFloor;
  /// Absolute latest selectable date, if the mode has a fixed forecast horizon.
  /// Null + Historical means "today" (resolved dynamically, not baked in here).
  final DateTime? calendarCeiling;
  const ModeCapability({required this.supportsHourly, this.maxPastDays = 0, this.maxFutureDays = 0, this.calendarFloor, this.calendarCeiling});
}

/// One row per mode, taken directly from the verified Open-Meteo capability
/// table: resolution support, relative past/future windows, and absolute
/// calendar bounds where the mode has an archive/forecast-horizon limit.
final Map<ModeType, ModeCapability> modeCapabilities = {
  ModeType.weather: ModeCapability(supportsHourly: true, maxPastDays: 92, maxFutureDays: 16),
  ModeType.historical: ModeCapability(supportsHourly: true, calendarFloor: DateTime.utc(1940, 1, 1)), // ceiling = "today", resolved in modePickerBounds
  ModeType.climate: ModeCapability(supportsHourly: false, calendarFloor: DateTime.utc(1950, 1, 1), calendarCeiling: DateTime.utc(2050, 1, 1)),
  ModeType.marine: ModeCapability(supportsHourly: true, maxPastDays: 92, maxFutureDays: 8),
  ModeType.airQuality: ModeCapability(supportsHourly: true, maxPastDays: 92, maxFutureDays: 7),
  ModeType.flood: ModeCapability(supportsHourly: false, maxFutureDays: 210, calendarFloor: DateTime.utc(1984, 1, 1)), // no past window at all
  ModeType.ensemble: ModeCapability(supportsHourly: true, maxPastDays: 3, maxFutureDays: 35), // archive is only 3 days, NOT 92
};

/// Absolute [floor, ceiling] a date picker for this mode may select --
/// combines the mode's fixed calendar bounds (if any) with its relative
/// past/future windows (if any). Every mode in the table above resolves to
/// a concrete floor AND ceiling this way, so callers never need a fallback.
({DateTime floor, DateTime ceiling}) modePickerBounds(ModeType mode, {DateTime? now}) {
  final cap = modeCapabilities[mode]!;
  final raw = (now ?? DateTime.now()).toUtc();
  // Truncate to the start of the UTC day. pastDays/forecastDays are
  // day-granularity anyway, so nothing is lost -- but WITHOUT this, any
  // mode whose window is exceeded by the current start/end (Marine's
  // 8-day future window, Air Quality's 7-day, Ensemble's 3-day past, or
  // Flood whenever the global range is still sitting at Climate's +3y
  // default from an earlier tab) recomputes a microsecond-different clamp
  // on every single rebuild. That becomes a new FetchParams every time,
  // which refetches, which rebuilds on completion, which computes a new
  // `now`, forever -- an infinite fetch loop that just looks like
  // "loading forever" in the UI. Truncating to the day makes the bound
  // stable for the whole day, so identical builds produce identical
  // FetchParams and the fetch actually completes and caches. UTC (not
  // local) because every timestamp elsewhere in the app -- API responses,
  // table rows, chart axes -- is UTC; computing this floor/ceiling from
  // local midnight silently shifted it by the device's UTC offset.
  final n = DateTime.utc(raw.year, raw.month, raw.day);
  var floor = cap.calendarFloor ?? DateTime.utc(1900);
  var ceiling = cap.calendarCeiling ?? (mode == ModeType.historical ? n : DateTime.utc(2100));
  if (cap.maxPastDays > 0) {
    final pastFloor = n.subtract(Duration(days: cap.maxPastDays));
    if (pastFloor.isAfter(floor)) floor = pastFloor;
  }
  if (cap.maxFutureDays > 0) {
    final futureCeiling = n.add(Duration(days: cap.maxFutureDays));
    if (futureCeiling.isBefore(ceiling)) ceiling = futureCeiling;
  }
  return (floor: floor, ceiling: ceiling);
}

class ResolvedRange {
  final DateTime start;
  final DateTime end;
  final TemporalResolution resolution;
  final bool longRange;
  const ResolvedRange({required this.start, required this.end, required this.resolution, required this.longRange});
}

/// Clamps [requestedStart, requestedEnd] into the mode's real window (see
/// modePickerBounds) and decides hourly vs. daily. Any range over a year --
/// after clamping -- is ALWAYS forced to daily, no matter what the mode's
/// own toggle was set to; a mode with no hourly support at all is always
/// daily regardless of span. This is the ONLY place that decision is made.
ResolvedRange resolveRange({required ModeType mode, required DateTime requestedStart, required DateTime requestedEnd, required TemporalResolution requestedResolution, DateTime? now}) {
  final cap = modeCapabilities[mode]!;
  final bounds = modePickerBounds(mode, now: now);
  var start = requestedStart.isBefore(bounds.floor)
      ? DateTime(bounds.floor.year, bounds.floor.month, bounds.floor.day, requestedStart.hour, requestedStart.minute)
      : requestedStart;
  var end = requestedEnd.isAfter(bounds.ceiling)
      ? DateTime(bounds.ceiling.year, bounds.ceiling.month, bounds.ceiling.day, requestedEnd.hour, requestedEnd.minute)
      : requestedEnd;
  if (end.isBefore(start)) end = start;
  final longRange = end.difference(start).inDays.abs() > 365;
  final resolution = (!cap.supportsHourly || longRange) ? TemporalResolution.daily : requestedResolution;
  return ResolvedRange(start: start, end: end, resolution: resolution, longRange: longRange);
}

/// Human-readable summary of a mode's currently selectable window, e.g.
/// "AVAILABLE 2026-06-11 → 2026-09-19" -- shown directly under the
/// START/END fields (and as the date picker dialog's helpText) so a
/// limitation is visible before the person even opens the calendar,
/// instead of only being enforced silently inside it.
String modeRangeLabel(ModeType mode, {DateTime? now}) {
  final b = modePickerBounds(mode, now: now);
  String fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  return 'AVAILABLE ${fmt(b.floor)} \u2192 ${fmt(b.ceiling)}';
}
