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
