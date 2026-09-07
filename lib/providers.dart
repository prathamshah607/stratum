// lib/providers.dart
//
// All Riverpod logic lives here: URL-synced app state, the units toggle,
// the FULL per-mode field registry (every value verified against the real
// open_meteo package source, extracted programmatically, July 2026), and
// ONE dispatch FutureProvider.family that calls the correct real open_meteo
// API class.
//
// IMPORTANT: activeFieldsProvider only auto-includes FieldTier.primary
// fields. Secondary ("extended") fields are NEVER fetched until the user
// explicitly picks them via the "SELECT METRICS" dialog in screens.dart,
// which calls AppStateNotifier.addFields(). This is deliberate: extended
// widgets should never trigger an API call the user didn't ask for.
//
// Verified enum inventories (exact counts from source):
//   WeatherHourly     -> 65 values (verified from raw source, corrects prior
//                        139-estimate which was based on an unreliable doc read)
//   WeatherDaily      -> 59 values (NOT wired into UI yet -- dispatch layer
//                        assumes one enum set per mode; adding daily support
//                        for weather mode would need a Hourly/Daily sub-toggle)
//   HistoricalHourly  -> 72 values (incl. _spread variants, full soil profile)
//   ClimateDaily      -> 19 values (aggregation baked into name)
//   MarineHourly      -> 22 values (incl. secondary/tertiary swell, ocean current)
//   AirQualityHourly  -> 42 values (pollutants, pollen, EU/US AQI, wildfire species)
//   FloodDaily        -> 7 values (base + 6 aggregation variants)
//   EnsembleHourly    -> 55 values (surface + altitude/depth/pressure dimensions)
//   ElevationApi/GeocodingApi -> no enum; requestJson() lookups only

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_meteo/open_meteo.dart';
import 'models.dart';
import 'screens.dart';

// ---------------------------------------------------------------------------
// Units: one toggle, flows into every data-fetch call's API-class constructor.
// ---------------------------------------------------------------------------
final unitSystemProvider = StateProvider<UnitSystem>((ref) => UnitSystem.metric);

final unitSettingsProvider = Provider<UnitSettings>((ref) {
  return ref.watch(unitSystemProvider) == UnitSystem.metric ? UnitSettings.metric : UnitSettings.imperial;
});

// ---------------------------------------------------------------------------
// FULL field registry -- every verified enum value per mode, tagged primary
// (fetched by default) or secondary (fetched only on explicit user request).
// ---------------------------------------------------------------------------
final fieldRegistryProvider = Provider<Map<ModeType, List<FieldSpec>>>((ref) {
  return {
    ModeType.weather: [
      FieldSpec(enumKey: WeatherHourly.temperature_2m, label: 'Temperature (2m)', mode: ModeType.weather, unitCategory: UnitCategory.temperature, color: Colors.amber, tier: FieldTier.primary, category: 'Temperature'),
      FieldSpec(enumKey: WeatherHourly.relative_humidity_2m, label: 'Relative Humidity (2m)', mode: ModeType.weather, fixedUnit: '%', chart: ChartKind.line, color: Colors.blueAccent, tier: FieldTier.primary, category: 'Humidity'),
      FieldSpec(enumKey: WeatherHourly.dew_point_2m, label: 'Dew Point (2m)', mode: ModeType.weather, unitCategory: UnitCategory.temperature, color: Colors.grey, category: 'Temperature'),
      FieldSpec(enumKey: WeatherHourly.apparent_temperature, label: 'Apparent Temperature', mode: ModeType.weather, unitCategory: UnitCategory.temperature, color: Colors.orange, tier: FieldTier.primary, category: 'Temperature'),
      FieldSpec(enumKey: WeatherHourly.precipitation_probability, label: 'Precipitation Probability', mode: ModeType.weather, unitCategory: UnitCategory.precipitation, chart: ChartKind.bar, color: Colors.teal, category: 'Precipitation'),
      FieldSpec(enumKey: WeatherHourly.precipitation, label: 'Precipitation', mode: ModeType.weather, unitCategory: UnitCategory.precipitation, chart: ChartKind.bar, color: Colors.cyan, tier: FieldTier.primary, category: 'Precipitation'),
      FieldSpec(enumKey: WeatherHourly.rain, label: 'Rain', mode: ModeType.weather, unitCategory: UnitCategory.precipitation, chart: ChartKind.bar, color: Colors.pinkAccent, category: 'Precipitation'),
      FieldSpec(enumKey: WeatherHourly.showers, label: 'Showers', mode: ModeType.weather, fixedUnit: '', chart: ChartKind.line, color: Colors.redAccent, category: 'Precipitation'),
      FieldSpec(enumKey: WeatherHourly.snowfall, label: 'Snowfall', mode: ModeType.weather, unitCategory: UnitCategory.precipitation, chart: ChartKind.bar, color: Colors.purple, category: 'Precipitation'),
      FieldSpec(enumKey: WeatherHourly.snow_depth, label: 'Snow Depth', mode: ModeType.weather, fixedUnit: 'm', chart: ChartKind.line, color: Colors.indigo, category: 'Precipitation'),
      FieldSpec(enumKey: WeatherHourly.weather_code, label: 'Weather Code', mode: ModeType.weather, fixedUnit: '', chart: ChartKind.line, color: Colors.brown, category: 'Conditions'),
      FieldSpec(enumKey: WeatherHourly.pressure_msl, label: 'Pressure MSL', mode: ModeType.weather, fixedUnit: 'hPa', chart: ChartKind.line, color: Colors.lightBlue, tier: FieldTier.primary, category: 'Pressure'),
      FieldSpec(enumKey: WeatherHourly.surface_pressure, label: 'Surface Pressure', mode: ModeType.weather, fixedUnit: 'hPa', chart: ChartKind.line, color: Colors.green, category: 'Pressure'),
      FieldSpec(enumKey: WeatherHourly.cloud_cover, label: 'Cloud Cover', mode: ModeType.weather, fixedUnit: '%', chart: ChartKind.line, color: Colors.deepOrange, tier: FieldTier.primary, category: 'Sky & Sun'),
      FieldSpec(enumKey: WeatherHourly.cloud_cover_low, label: 'Cloud Cover Low', mode: ModeType.weather, fixedUnit: '%', chart: ChartKind.line, color: Colors.blue, category: 'Sky & Sun'),
      FieldSpec(enumKey: WeatherHourly.cloud_cover_mid, label: 'Cloud Cover Mid', mode: ModeType.weather, fixedUnit: '%', chart: ChartKind.line, color: Colors.tealAccent, category: 'Sky & Sun'),
      FieldSpec(enumKey: WeatherHourly.cloud_cover_high, label: 'Cloud Cover High', mode: ModeType.weather, fixedUnit: '%', chart: ChartKind.line, color: Colors.purpleAccent, category: 'Sky & Sun'),
      FieldSpec(enumKey: WeatherHourly.visibility, label: 'Visibility', mode: ModeType.weather, fixedUnit: 'm', chart: ChartKind.line, color: Colors.deepPurple, category: 'Sky & Sun'),
      FieldSpec(enumKey: WeatherHourly.evapotranspiration, label: 'Evapotranspiration', mode: ModeType.weather, fixedUnit: 'mm', chart: ChartKind.line, color: Colors.lime, category: 'Soil & Moisture'),
      FieldSpec(enumKey: WeatherHourly.et0_fao_evapotranspiration, label: 'ET0 FAO Evapotranspiration', mode: ModeType.weather, fixedUnit: 'mm', chart: ChartKind.line, color: Colors.yellowAccent, category: 'Soil & Moisture'),
      FieldSpec(enumKey: WeatherHourly.vapour_pressure_deficit, label: 'Vapour Pressure Deficit', mode: ModeType.weather, fixedUnit: 'kPa', chart: ChartKind.line, color: Colors.amber, category: 'Pressure'),
      FieldSpec(enumKey: WeatherHourly.wind_speed_10m, label: 'Wind Speed (10m)', mode: ModeType.weather, unitCategory: UnitCategory.windspeed, color: Colors.blueAccent, tier: FieldTier.primary, category: 'Wind'),
      FieldSpec(enumKey: WeatherHourly.wind_speed_80m, label: 'Wind Speed (80m)', mode: ModeType.weather, unitCategory: UnitCategory.windspeed, color: Colors.grey, category: 'Wind'),
      FieldSpec(enumKey: WeatherHourly.wind_speed_120m, label: 'Wind Speed (120m)', mode: ModeType.weather, unitCategory: UnitCategory.windspeed, color: Colors.orange, category: 'Wind'),
      FieldSpec(enumKey: WeatherHourly.wind_speed_180m, label: 'Wind Speed (180m)', mode: ModeType.weather, unitCategory: UnitCategory.windspeed, color: Colors.teal, category: 'Wind'),
      FieldSpec(enumKey: WeatherHourly.wind_direction_10m, label: 'Wind Direction (10m)', mode: ModeType.weather, fixedUnit: '°', chart: ChartKind.line, color: Colors.cyan, category: 'Wind'),
      FieldSpec(enumKey: WeatherHourly.wind_direction_80m, label: 'Wind Direction (80m)', mode: ModeType.weather, fixedUnit: '°', chart: ChartKind.line, color: Colors.pinkAccent, category: 'Wind'),
      FieldSpec(enumKey: WeatherHourly.wind_direction_120m, label: 'Wind Direction (120m)', mode: ModeType.weather, fixedUnit: '°', chart: ChartKind.line, color: Colors.redAccent, category: 'Wind'),
      FieldSpec(enumKey: WeatherHourly.wind_direction_180m, label: 'Wind Direction (180m)', mode: ModeType.weather, fixedUnit: '°', chart: ChartKind.line, color: Colors.purple, category: 'Wind'),
      FieldSpec(enumKey: WeatherHourly.wind_gusts_10m, label: 'Wind Gusts (10m)', mode: ModeType.weather, unitCategory: UnitCategory.windspeed, color: Colors.indigo, category: 'Wind'),
      FieldSpec(enumKey: WeatherHourly.temperature_80m, label: 'Temperature (80m)', mode: ModeType.weather, unitCategory: UnitCategory.temperature, color: Colors.brown, category: 'Temperature'),
      FieldSpec(enumKey: WeatherHourly.temperature_120m, label: 'Temperature (120m)', mode: ModeType.weather, unitCategory: UnitCategory.temperature, color: Colors.lightBlue, category: 'Temperature'),
      FieldSpec(enumKey: WeatherHourly.temperature_180m, label: 'Temperature (180m)', mode: ModeType.weather, unitCategory: UnitCategory.temperature, color: Colors.green, category: 'Temperature'),
      FieldSpec(enumKey: WeatherHourly.soil_temperature_0cm, label: 'Soil Temperature 0cm', mode: ModeType.weather, unitCategory: UnitCategory.temperature, color: Colors.deepOrange, category: 'Temperature'),
      FieldSpec(enumKey: WeatherHourly.soil_temperature_6cm, label: 'Soil Temperature 6cm', mode: ModeType.weather, unitCategory: UnitCategory.temperature, color: Colors.blue, category: 'Temperature'),
      FieldSpec(enumKey: WeatherHourly.soil_temperature_18cm, label: 'Soil Temperature 18cm', mode: ModeType.weather, unitCategory: UnitCategory.temperature, color: Colors.tealAccent, category: 'Temperature'),
      FieldSpec(enumKey: WeatherHourly.soil_temperature_54cm, label: 'Soil Temperature 54cm', mode: ModeType.weather, unitCategory: UnitCategory.temperature, color: Colors.purpleAccent, category: 'Temperature'),
      FieldSpec(enumKey: WeatherHourly.soil_moisture_0_to_1cm, label: 'Soil Moisture 0 To 1cm', mode: ModeType.weather, fixedUnit: 'm³/m³', chart: ChartKind.line, color: Colors.deepPurple, category: 'Soil & Moisture'),
      FieldSpec(enumKey: WeatherHourly.soil_moisture_1_to_3cm, label: 'Soil Moisture 1 To 3cm', mode: ModeType.weather, fixedUnit: 'm³/m³', chart: ChartKind.line, color: Colors.lime, category: 'Soil & Moisture'),
      FieldSpec(enumKey: WeatherHourly.soil_moisture_3_to_9cm, label: 'Soil Moisture 3 To 9cm', mode: ModeType.weather, fixedUnit: 'm³/m³', chart: ChartKind.line, color: Colors.yellowAccent, category: 'Soil & Moisture'),
      FieldSpec(enumKey: WeatherHourly.soil_moisture_9_to_27cm, label: 'Soil Moisture 9 To 27cm', mode: ModeType.weather, fixedUnit: 'm³/m³', chart: ChartKind.line, color: Colors.amber, category: 'Soil & Moisture'),
      FieldSpec(enumKey: WeatherHourly.soil_moisture_27_to_81cm, label: 'Soil Moisture 27 To 81cm', mode: ModeType.weather, fixedUnit: 'm³/m³', chart: ChartKind.line, color: Colors.blueAccent, category: 'Soil & Moisture'),
      FieldSpec(enumKey: WeatherHourly.uv_index, label: 'UV Index', mode: ModeType.weather, fixedUnit: '', chart: ChartKind.line, color: Colors.grey, tier: FieldTier.primary, category: 'Sky & Sun'),
      FieldSpec(enumKey: WeatherHourly.uv_index_clear_sky, label: 'UV Index Clear Sky', mode: ModeType.weather, fixedUnit: '', chart: ChartKind.line, color: Colors.orange, category: 'Sky & Sun'),
      FieldSpec(enumKey: WeatherHourly.is_day, label: 'Is Day', mode: ModeType.weather, fixedUnit: '', chart: ChartKind.line, color: Colors.teal, category: 'Sky & Sun'),
      FieldSpec(enumKey: WeatherHourly.sunshine_duration, label: 'Sunshine Duration', mode: ModeType.weather, fixedUnit: 's', chart: ChartKind.line, color: Colors.cyan, category: 'Sky & Sun'),
      FieldSpec(enumKey: WeatherHourly.wet_bulb_temperature_2m, label: 'Wet Bulb Temperature (2m)', mode: ModeType.weather, unitCategory: UnitCategory.temperature, color: Colors.pinkAccent, category: 'Temperature'),
      FieldSpec(enumKey: WeatherHourly.total_column_integrated_water_vapour, label: 'Total Column Integrated Water Vapour', mode: ModeType.weather, fixedUnit: 'kg/m²', chart: ChartKind.line, color: Colors.redAccent, category: 'Atmosphere'),
      FieldSpec(enumKey: WeatherHourly.cape, label: 'CAPE', mode: ModeType.weather, fixedUnit: 'J/kg', chart: ChartKind.line, color: Colors.purple, category: 'Atmosphere'),
      FieldSpec(enumKey: WeatherHourly.lifted_index, label: 'Lifted Index', mode: ModeType.weather, fixedUnit: '', chart: ChartKind.line, color: Colors.indigo, category: 'Atmosphere'),
      FieldSpec(enumKey: WeatherHourly.convective_inhibition, label: 'Convective Inhibition', mode: ModeType.weather, fixedUnit: 'J/kg', chart: ChartKind.line, color: Colors.brown, category: 'Atmosphere'),
      FieldSpec(enumKey: WeatherHourly.freezing_level_height, label: 'Freezing Level Height', mode: ModeType.weather, fixedUnit: 'm', chart: ChartKind.line, color: Colors.lightBlue, category: 'Atmosphere'),
      FieldSpec(enumKey: WeatherHourly.boundary_layer_height, label: 'Boundary Layer Height', mode: ModeType.weather, fixedUnit: 'm', chart: ChartKind.line, color: Colors.green, category: 'Atmosphere'),
      FieldSpec(enumKey: WeatherHourly.shortwave_radiation, label: 'Shortwave Radiation', mode: ModeType.weather, fixedUnit: 'W/m²', chart: ChartKind.line, color: Colors.deepOrange, category: 'Radiation'),
      FieldSpec(enumKey: WeatherHourly.direct_radiation, label: 'Direct Radiation', mode: ModeType.weather, fixedUnit: 'W/m²', chart: ChartKind.line, color: Colors.blue, category: 'Radiation'),
      FieldSpec(enumKey: WeatherHourly.diffuse_radiation, label: 'Diffuse Radiation', mode: ModeType.weather, fixedUnit: 'W/m²', chart: ChartKind.line, color: Colors.tealAccent, category: 'Radiation'),
      FieldSpec(enumKey: WeatherHourly.direct_normal_irradiance, label: 'Direct Normal Irradiance', mode: ModeType.weather, fixedUnit: 'W/m²', chart: ChartKind.line, color: Colors.purpleAccent, category: 'Radiation'),
      FieldSpec(enumKey: WeatherHourly.global_tilted_irradiance, label: 'Global Tilted Irradiance', mode: ModeType.weather, fixedUnit: 'W/m²', chart: ChartKind.line, color: Colors.deepPurple, category: 'Radiation'),
      FieldSpec(enumKey: WeatherHourly.terrestrial_radiation, label: 'Terrestrial Radiation', mode: ModeType.weather, fixedUnit: 'W/m²', chart: ChartKind.line, color: Colors.lime, category: 'Radiation'),
      FieldSpec(enumKey: WeatherHourly.shortwave_radiation_instant, label: 'Shortwave Radiation Instant', mode: ModeType.weather, fixedUnit: 'W/m²', chart: ChartKind.line, color: Colors.yellowAccent, category: 'Radiation'),
      FieldSpec(enumKey: WeatherHourly.direct_radiation_instant, label: 'Direct Radiation Instant', mode: ModeType.weather, fixedUnit: 'W/m²', chart: ChartKind.line, color: Colors.amber, category: 'Radiation'),
      FieldSpec(enumKey: WeatherHourly.diffuse_radiation_instant, label: 'Diffuse Radiation Instant', mode: ModeType.weather, fixedUnit: 'W/m²', chart: ChartKind.line, color: Colors.blueAccent, category: 'Radiation'),
      FieldSpec(enumKey: WeatherHourly.direct_normal_irradiance_instant, label: 'Direct Normal Irradiance Instant', mode: ModeType.weather, fixedUnit: 'W/m²', chart: ChartKind.line, color: Colors.grey, category: 'Radiation'),
      FieldSpec(enumKey: WeatherHourly.global_tilted_irradiance_instant, label: 'Global Tilted Irradiance Instant', mode: ModeType.weather, fixedUnit: 'W/m²', chart: ChartKind.line, color: Colors.orange, category: 'Radiation'),
      FieldSpec(enumKey: WeatherHourly.terrestrial_radiation_instant, label: 'Terrestrial Radiation Instant', mode: ModeType.weather, fixedUnit: 'W/m²', chart: ChartKind.line, color: Colors.teal, category: 'Radiation'),
    ],
    // HistoricalHourly -- full 72-value enum, generated programmatically from
    // the verified source (includes ensemble-style _spread variants, all soil
    // depth bands, full radiation suite with _instant counterparts).
    ModeType.historical: [
      FieldSpec(enumKey: HistoricalHourly.temperature_2m, label: 'Temperature (2m)', mode: ModeType.historical, unitCategory: UnitCategory.temperature, color: Colors.amber, tier: FieldTier.primary),
      FieldSpec(enumKey: HistoricalHourly.relative_humidity_2m, label: 'Relative Humidity (2m)', mode: ModeType.historical, fixedUnit: '%', chart: ChartKind.line, color: Colors.blueAccent, tier: FieldTier.primary),
      FieldSpec(enumKey: HistoricalHourly.dew_point_2m, label: 'Dew Point (2m)', mode: ModeType.historical, unitCategory: UnitCategory.temperature, color: Colors.grey),
      FieldSpec(enumKey: HistoricalHourly.apparent_temperature, label: 'Apparent Temperature', mode: ModeType.historical, unitCategory: UnitCategory.temperature, color: Colors.orange, tier: FieldTier.primary),
      FieldSpec(enumKey: HistoricalHourly.precipitation, label: 'Precipitation', mode: ModeType.historical, unitCategory: UnitCategory.precipitation, chart: ChartKind.bar, color: Colors.teal, tier: FieldTier.primary),
      FieldSpec(enumKey: HistoricalHourly.rain, label: 'Rain', mode: ModeType.historical, unitCategory: UnitCategory.precipitation, chart: ChartKind.bar, color: Colors.cyan),
      FieldSpec(enumKey: HistoricalHourly.snowfall, label: 'Snowfall', mode: ModeType.historical, unitCategory: UnitCategory.precipitation, chart: ChartKind.bar, color: Colors.pinkAccent),
      FieldSpec(enumKey: HistoricalHourly.snow_depth, label: 'Snow Depth', mode: ModeType.historical, fixedUnit: 'm', chart: ChartKind.line, color: Colors.redAccent),
      FieldSpec(enumKey: HistoricalHourly.weather_code, label: 'Weather Code', mode: ModeType.historical, fixedUnit: '', chart: ChartKind.line, color: Colors.purple),
      FieldSpec(enumKey: HistoricalHourly.pressure_msl, label: 'Pressure MSL', mode: ModeType.historical, fixedUnit: 'hPa', chart: ChartKind.line, color: Colors.indigo, tier: FieldTier.primary),
      FieldSpec(enumKey: HistoricalHourly.surface_pressure, label: 'Surface Pressure', mode: ModeType.historical, fixedUnit: 'hPa', chart: ChartKind.line, color: Colors.brown),
      FieldSpec(enumKey: HistoricalHourly.cloud_cover, label: 'Cloud Cover', mode: ModeType.historical, fixedUnit: '%', chart: ChartKind.line, color: Colors.lightBlue, tier: FieldTier.primary),
      FieldSpec(enumKey: HistoricalHourly.cloud_cover_low, label: 'Cloud Cover Low', mode: ModeType.historical, fixedUnit: '%', chart: ChartKind.line, color: Colors.green),
      FieldSpec(enumKey: HistoricalHourly.cloud_cover_mid, label: 'Cloud Cover Mid', mode: ModeType.historical, fixedUnit: '%', chart: ChartKind.line, color: Colors.deepOrange),
      FieldSpec(enumKey: HistoricalHourly.cloud_cover_high, label: 'Cloud Cover High', mode: ModeType.historical, fixedUnit: '%', chart: ChartKind.line, color: Colors.blue),
      FieldSpec(enumKey: HistoricalHourly.et0_fao_evapotranspiration, label: 'ET0 FAO Evapotranspiration', mode: ModeType.historical, fixedUnit: 'mm', chart: ChartKind.line, color: Colors.tealAccent),
      FieldSpec(enumKey: HistoricalHourly.vapour_pressure_deficit, label: 'Vapour Pressure Deficit', mode: ModeType.historical, fixedUnit: 'kPa', chart: ChartKind.line, color: Colors.purpleAccent),
      FieldSpec(enumKey: HistoricalHourly.wind_speed_10m, label: 'Wind Speed (10m)', mode: ModeType.historical, unitCategory: UnitCategory.windspeed, color: Colors.deepPurple, tier: FieldTier.primary),
      FieldSpec(enumKey: HistoricalHourly.wind_speed_100m, label: 'Wind Speed (100m)', mode: ModeType.historical, unitCategory: UnitCategory.windspeed, color: Colors.lime),
      FieldSpec(enumKey: HistoricalHourly.wind_direction_10m, label: 'Wind Direction (10m)', mode: ModeType.historical, fixedUnit: '°', chart: ChartKind.line, color: Colors.yellowAccent),
      FieldSpec(enumKey: HistoricalHourly.wind_direction_100m, label: 'Wind Direction (100m)', mode: ModeType.historical, fixedUnit: '°', chart: ChartKind.line, color: Colors.amber),
      FieldSpec(enumKey: HistoricalHourly.wind_gusts_10m, label: 'Wind Gusts (10m)', mode: ModeType.historical, unitCategory: UnitCategory.windspeed, color: Colors.blueAccent),
      FieldSpec(enumKey: HistoricalHourly.soil_temperature_0_to_7cm, label: 'Soil Temperature 0 To 7cm', mode: ModeType.historical, unitCategory: UnitCategory.temperature, color: Colors.grey),
      FieldSpec(enumKey: HistoricalHourly.soil_temperature_7_to_28cm, label: 'Soil Temperature 7 To 28cm', mode: ModeType.historical, unitCategory: UnitCategory.temperature, color: Colors.orange),
      FieldSpec(enumKey: HistoricalHourly.soil_temperature_28_to_100cm, label: 'Soil Temperature 28 To 100cm', mode: ModeType.historical, unitCategory: UnitCategory.temperature, color: Colors.teal),
      FieldSpec(enumKey: HistoricalHourly.soil_temperature_100_to_255cm, label: 'Soil Temperature 100 To 255cm', mode: ModeType.historical, unitCategory: UnitCategory.temperature, color: Colors.cyan),
      FieldSpec(enumKey: HistoricalHourly.soil_moisture_0_to_7cm, label: 'Soil Moisture 0 To 7cm', mode: ModeType.historical, fixedUnit: 'm³/m³', chart: ChartKind.line, color: Colors.pinkAccent),
      FieldSpec(enumKey: HistoricalHourly.soil_moisture_7_to_28cm, label: 'Soil Moisture 7 To 28cm', mode: ModeType.historical, fixedUnit: 'm³/m³', chart: ChartKind.line, color: Colors.redAccent),
      FieldSpec(enumKey: HistoricalHourly.soil_moisture_28_to_100cm, label: 'Soil Moisture 28 To 100cm', mode: ModeType.historical, fixedUnit: 'm³/m³', chart: ChartKind.line, color: Colors.purple),
      FieldSpec(enumKey: HistoricalHourly.soil_moisture_100_to_255cm, label: 'Soil Moisture 100 To 255cm', mode: ModeType.historical, fixedUnit: 'm³/m³', chart: ChartKind.line, color: Colors.indigo),
      FieldSpec(enumKey: HistoricalHourly.boundary_layer_height, label: 'Boundary Layer Height', mode: ModeType.historical, fixedUnit: 'm', chart: ChartKind.line, color: Colors.brown),
      FieldSpec(enumKey: HistoricalHourly.wet_bulb_temperature_2m, label: 'Wet Bulb Temperature (2m)', mode: ModeType.historical, unitCategory: UnitCategory.temperature, color: Colors.lightBlue),
      FieldSpec(enumKey: HistoricalHourly.total_column_integrated_water_vapour, label: 'Total Column Integrated Water Vapour', mode: ModeType.historical, fixedUnit: 'kg/m²', chart: ChartKind.line, color: Colors.green),
      FieldSpec(enumKey: HistoricalHourly.is_day, label: 'Is Day', mode: ModeType.historical, fixedUnit: '', chart: ChartKind.line, color: Colors.deepOrange),
      FieldSpec(enumKey: HistoricalHourly.sunshine_duration, label: 'Sunshine Duration', mode: ModeType.historical, fixedUnit: 's', chart: ChartKind.line, color: Colors.blue),
      FieldSpec(enumKey: HistoricalHourly.albedo, label: 'Albedo', mode: ModeType.historical, fixedUnit: '%', chart: ChartKind.line, color: Colors.tealAccent),
      FieldSpec(enumKey: HistoricalHourly.snow_depth_water_equivalent, label: 'Snow Depth Water Equivalent', mode: ModeType.historical, fixedUnit: 'mm', chart: ChartKind.line, color: Colors.purpleAccent),
      FieldSpec(enumKey: HistoricalHourly.shortwave_radiation, label: 'Shortwave Radiation', mode: ModeType.historical, fixedUnit: 'W/m²', chart: ChartKind.line, color: Colors.deepPurple),
      FieldSpec(enumKey: HistoricalHourly.direct_radiation, label: 'Direct Radiation', mode: ModeType.historical, fixedUnit: 'W/m²', chart: ChartKind.line, color: Colors.lime),
      FieldSpec(enumKey: HistoricalHourly.diffuse_radiation, label: 'Diffuse Radiation', mode: ModeType.historical, fixedUnit: 'W/m²', chart: ChartKind.line, color: Colors.yellowAccent),
      FieldSpec(enumKey: HistoricalHourly.direct_normal_irradiance, label: 'Direct Normal Irradiance', mode: ModeType.historical, fixedUnit: 'W/m²', chart: ChartKind.line, color: Colors.amber),
      FieldSpec(enumKey: HistoricalHourly.global_tilted_irradiance, label: 'Global Tilted Irradiance', mode: ModeType.historical, fixedUnit: 'W/m²', chart: ChartKind.line, color: Colors.blueAccent),
      FieldSpec(enumKey: HistoricalHourly.terrestrial_radiation, label: 'Terrestrial Radiation', mode: ModeType.historical, fixedUnit: 'W/m²', chart: ChartKind.line, color: Colors.grey),
      FieldSpec(enumKey: HistoricalHourly.shortwave_radiation_instant, label: 'Shortwave Radiation Instant', mode: ModeType.historical, fixedUnit: 'W/m²', chart: ChartKind.line, color: Colors.orange),
      FieldSpec(enumKey: HistoricalHourly.direct_radiation_instant, label: 'Direct Radiation Instant', mode: ModeType.historical, fixedUnit: 'W/m²', chart: ChartKind.line, color: Colors.teal),
      FieldSpec(enumKey: HistoricalHourly.diffuse_radiation_instant, label: 'Diffuse Radiation Instant', mode: ModeType.historical, fixedUnit: 'W/m²', chart: ChartKind.line, color: Colors.cyan),
      FieldSpec(enumKey: HistoricalHourly.direct_normal_irradiance_instant, label: 'Direct Normal Irradiance Instant', mode: ModeType.historical, fixedUnit: 'W/m²', chart: ChartKind.line, color: Colors.pinkAccent),
      FieldSpec(enumKey: HistoricalHourly.global_tilted_irradiance_instant, label: 'Global Tilted Irradiance Instant', mode: ModeType.historical, fixedUnit: 'W/m²', chart: ChartKind.line, color: Colors.redAccent),
      FieldSpec(enumKey: HistoricalHourly.terrestrial_radiation_instant, label: 'Terrestrial Radiation Instant', mode: ModeType.historical, fixedUnit: 'W/m²', chart: ChartKind.line, color: Colors.purple),
      FieldSpec(enumKey: HistoricalHourly.temperature_2m_spread, label: 'Temperature (2m) Spread', mode: ModeType.historical, unitCategory: UnitCategory.temperature, color: Colors.indigo),
      FieldSpec(enumKey: HistoricalHourly.dew_point_2m_spread, label: 'Dew Point (2m) Spread', mode: ModeType.historical, unitCategory: UnitCategory.temperature, color: Colors.brown),
      FieldSpec(enumKey: HistoricalHourly.precipitation_spread, label: 'Precipitation Spread', mode: ModeType.historical, unitCategory: UnitCategory.precipitation, chart: ChartKind.bar, color: Colors.lightBlue),
      FieldSpec(enumKey: HistoricalHourly.snowfall_spread, label: 'Snowfall Spread', mode: ModeType.historical, unitCategory: UnitCategory.precipitation, chart: ChartKind.bar, color: Colors.green),
      FieldSpec(enumKey: HistoricalHourly.shortwave_radiation_spread, label: 'Shortwave Radiation Spread', mode: ModeType.historical, fixedUnit: 'W/m²', chart: ChartKind.line, color: Colors.deepOrange),
      FieldSpec(enumKey: HistoricalHourly.direct_radiation_spread, label: 'Direct Radiation Spread', mode: ModeType.historical, fixedUnit: 'W/m²', chart: ChartKind.line, color: Colors.blue),
      FieldSpec(enumKey: HistoricalHourly.pressure_msl_spread, label: 'Pressure MSL Spread', mode: ModeType.historical, fixedUnit: 'hPa', chart: ChartKind.line, color: Colors.tealAccent),
      FieldSpec(enumKey: HistoricalHourly.cloud_cover_low_spread, label: 'Cloud Cover Low Spread', mode: ModeType.historical, fixedUnit: '%', chart: ChartKind.line, color: Colors.purpleAccent),
      FieldSpec(enumKey: HistoricalHourly.cloud_cover_mid_spread, label: 'Cloud Cover Mid Spread', mode: ModeType.historical, fixedUnit: '%', chart: ChartKind.line, color: Colors.deepPurple),
      FieldSpec(enumKey: HistoricalHourly.cloud_cover_high_spread, label: 'Cloud Cover High Spread', mode: ModeType.historical, fixedUnit: '%', chart: ChartKind.line, color: Colors.lime),
      FieldSpec(enumKey: HistoricalHourly.wind_speed_10m_spread, label: 'Wind Speed (10m) Spread', mode: ModeType.historical, unitCategory: UnitCategory.windspeed, color: Colors.yellowAccent),
      FieldSpec(enumKey: HistoricalHourly.wind_speed_100m_spread, label: 'Wind Speed (100m) Spread', mode: ModeType.historical, unitCategory: UnitCategory.windspeed, color: Colors.amber),
      FieldSpec(enumKey: HistoricalHourly.wind_direction_10m_spread, label: 'Wind Direction (10m) Spread', mode: ModeType.historical, fixedUnit: '°', chart: ChartKind.line, color: Colors.blueAccent),
      FieldSpec(enumKey: HistoricalHourly.wind_direction_100m_spread, label: 'Wind Direction (100m) Spread', mode: ModeType.historical, fixedUnit: '°', chart: ChartKind.line, color: Colors.grey),
      FieldSpec(enumKey: HistoricalHourly.wind_gusts_10m_spread, label: 'Wind Gusts (10m) Spread', mode: ModeType.historical, unitCategory: UnitCategory.windspeed, color: Colors.orange),
      FieldSpec(enumKey: HistoricalHourly.soil_temperature_0_to_7cm_spread, label: 'Soil Temperature 0 To 7cm Spread', mode: ModeType.historical, unitCategory: UnitCategory.temperature, color: Colors.teal),
      FieldSpec(enumKey: HistoricalHourly.soil_temperature_7_to_28cm_spread, label: 'Soil Temperature 7 To 28cm Spread', mode: ModeType.historical, unitCategory: UnitCategory.temperature, color: Colors.cyan),
      FieldSpec(enumKey: HistoricalHourly.soil_temperature_28_to_100cm_spread, label: 'Soil Temperature 28 To 100cm Spread', mode: ModeType.historical, unitCategory: UnitCategory.temperature, color: Colors.pinkAccent),
      FieldSpec(enumKey: HistoricalHourly.soil_temperature_100_to_255cm_spread, label: 'Soil Temperature 100 To 255cm Spread', mode: ModeType.historical, unitCategory: UnitCategory.temperature, color: Colors.redAccent),
      FieldSpec(enumKey: HistoricalHourly.soil_moisture_0_to_7cm_spread, label: 'Soil Moisture 0 To 7cm Spread', mode: ModeType.historical, fixedUnit: 'm³/m³', chart: ChartKind.line, color: Colors.purple),
      FieldSpec(enumKey: HistoricalHourly.soil_moisture_7_to_28cm_spread, label: 'Soil Moisture 7 To 28cm Spread', mode: ModeType.historical, fixedUnit: 'm³/m³', chart: ChartKind.line, color: Colors.indigo),
      FieldSpec(enumKey: HistoricalHourly.soil_moisture_28_to_100cm_spread, label: 'Soil Moisture 28 To 100cm Spread', mode: ModeType.historical, fixedUnit: 'm³/m³', chart: ChartKind.line, color: Colors.brown),
      FieldSpec(enumKey: HistoricalHourly.soil_moisture_100_to_255cm_spread, label: 'Soil Moisture 100 To 255cm Spread', mode: ModeType.historical, fixedUnit: 'm³/m³', chart: ChartKind.line, color: Colors.lightBlue),
    ],
    // ClimateDaily -- full 19-value enum. Aggregation baked into each name.
    ModeType.climate: [
      FieldSpec(enumKey: ClimateDaily.temperature_2m_mean, label: 'Temperature (2m) Mean', mode: ModeType.climate, unitCategory: UnitCategory.temperature, color: Colors.amber),
      FieldSpec(enumKey: ClimateDaily.temperature_2m_max, label: 'Temperature (2m) Max', mode: ModeType.climate, unitCategory: UnitCategory.temperature, color: Colors.blueAccent, tier: FieldTier.primary),
      FieldSpec(enumKey: ClimateDaily.temperature_2m_min, label: 'Temperature (2m) Min', mode: ModeType.climate, unitCategory: UnitCategory.temperature, color: Colors.grey, tier: FieldTier.primary),
      FieldSpec(enumKey: ClimateDaily.wind_speed_10m_mean, label: 'Wind Speed (10m) Mean', mode: ModeType.climate, unitCategory: UnitCategory.windspeed, color: Colors.orange),
      FieldSpec(enumKey: ClimateDaily.wind_speed_10m_max, label: 'Wind Speed (10m) Max', mode: ModeType.climate, unitCategory: UnitCategory.windspeed, color: Colors.teal, tier: FieldTier.primary),
      FieldSpec(enumKey: ClimateDaily.cloud_cover_mean, label: 'Cloud Cover Mean', mode: ModeType.climate, fixedUnit: '%', chart: ChartKind.line, color: Colors.cyan),
      FieldSpec(enumKey: ClimateDaily.shortwave_radiation_sum, label: 'Shortwave Radiation Sum', mode: ModeType.climate, fixedUnit: 'W/m²', chart: ChartKind.bar, color: Colors.pinkAccent),
      FieldSpec(enumKey: ClimateDaily.relative_humidity_2m_mean, label: 'Relative Humidity (2m) Mean', mode: ModeType.climate, fixedUnit: '%', chart: ChartKind.line, color: Colors.redAccent, tier: FieldTier.primary),
      FieldSpec(enumKey: ClimateDaily.relative_humidity_2m_max, label: 'Relative Humidity (2m) Max', mode: ModeType.climate, fixedUnit: '%', chart: ChartKind.line, color: Colors.purple),
      FieldSpec(enumKey: ClimateDaily.relative_humidity_2m_min, label: 'Relative Humidity (2m) Min', mode: ModeType.climate, fixedUnit: '%', chart: ChartKind.line, color: Colors.indigo),
      FieldSpec(enumKey: ClimateDaily.dew_point_2m_mean, label: 'Dew Point (2m) Mean', mode: ModeType.climate, unitCategory: UnitCategory.temperature, color: Colors.brown),
      FieldSpec(enumKey: ClimateDaily.dew_point_2m_min, label: 'Dew Point (2m) Min', mode: ModeType.climate, unitCategory: UnitCategory.temperature, color: Colors.lightBlue),
      FieldSpec(enumKey: ClimateDaily.dew_point_2m_max, label: 'Dew Point (2m) Max', mode: ModeType.climate, unitCategory: UnitCategory.temperature, color: Colors.green),
      FieldSpec(enumKey: ClimateDaily.precipitation_sum, label: 'Precipitation Sum', mode: ModeType.climate, unitCategory: UnitCategory.precipitation, chart: ChartKind.bar, color: Colors.deepOrange, tier: FieldTier.primary),
      FieldSpec(enumKey: ClimateDaily.rain_sum, label: 'Rain Sum', mode: ModeType.climate, unitCategory: UnitCategory.precipitation, chart: ChartKind.bar, color: Colors.blue),
      FieldSpec(enumKey: ClimateDaily.snowfall_sum, label: 'Snowfall Sum', mode: ModeType.climate, unitCategory: UnitCategory.precipitation, chart: ChartKind.bar, color: Colors.tealAccent),
      FieldSpec(enumKey: ClimateDaily.pressure_msl_mean, label: 'Pressure MSL Mean', mode: ModeType.climate, fixedUnit: 'hPa', chart: ChartKind.line, color: Colors.purpleAccent),
      FieldSpec(enumKey: ClimateDaily.soil_moisture_0_to_10cm_mean, label: 'Soil Moisture 0 To 10cm Mean', mode: ModeType.climate, fixedUnit: 'm³/m³', chart: ChartKind.line, color: Colors.deepPurple),
      FieldSpec(enumKey: ClimateDaily.et0_fao_evapotranspiration_sum, label: 'ET0 FAO Evapotranspiration Sum', mode: ModeType.climate, fixedUnit: 'mm', chart: ChartKind.bar, color: Colors.lime),
    ],
    // MarineHourly -- full 22-value enum (wave/wind-wave/swell/secondary/tertiary
    // swell + ocean current + sea level/surface temp + invert barometer height).
    ModeType.marine: [
      FieldSpec(enumKey: MarineHourly.wave_height, label: 'Wave Height', mode: ModeType.marine, fixedUnit: 'm', chart: ChartKind.line, color: Colors.amber, tier: FieldTier.primary),
      FieldSpec(enumKey: MarineHourly.wave_direction, label: 'Wave Direction', mode: ModeType.marine, fixedUnit: '°', chart: ChartKind.line, color: Colors.blueAccent),
      FieldSpec(enumKey: MarineHourly.wave_period, label: 'Wave Period', mode: ModeType.marine, fixedUnit: 's', chart: ChartKind.line, color: Colors.grey, tier: FieldTier.primary),
      FieldSpec(enumKey: MarineHourly.wind_wave_peak_period, label: 'Wind Wave Peak Period', mode: ModeType.marine, fixedUnit: 's', chart: ChartKind.line, color: Colors.orange),
      FieldSpec(enumKey: MarineHourly.wind_wave_height, label: 'Wind Wave Height', mode: ModeType.marine, fixedUnit: 'm', chart: ChartKind.line, color: Colors.teal),
      FieldSpec(enumKey: MarineHourly.wind_wave_direction, label: 'Wind Wave Direction', mode: ModeType.marine, fixedUnit: '°', chart: ChartKind.line, color: Colors.cyan),
      FieldSpec(enumKey: MarineHourly.wind_wave_period, label: 'Wind Wave Period', mode: ModeType.marine, fixedUnit: 's', chart: ChartKind.line, color: Colors.pinkAccent),
      FieldSpec(enumKey: MarineHourly.swell_wave_height, label: 'Swell Wave Height', mode: ModeType.marine, fixedUnit: 'm', chart: ChartKind.line, color: Colors.redAccent, tier: FieldTier.primary),
      FieldSpec(enumKey: MarineHourly.swell_wave_direction, label: 'Swell Wave Direction', mode: ModeType.marine, fixedUnit: '°', chart: ChartKind.line, color: Colors.purple),
      FieldSpec(enumKey: MarineHourly.swell_wave_period, label: 'Swell Wave Period', mode: ModeType.marine, fixedUnit: 's', chart: ChartKind.line, color: Colors.indigo),
      FieldSpec(enumKey: MarineHourly.swell_wave_peak_period, label: 'Swell Wave Peak Period', mode: ModeType.marine, fixedUnit: 's', chart: ChartKind.line, color: Colors.brown),
      FieldSpec(enumKey: MarineHourly.secondary_swell_wave_height, label: 'Secondary Swell Wave Height', mode: ModeType.marine, fixedUnit: 'm', chart: ChartKind.line, color: Colors.lightBlue),
      FieldSpec(enumKey: MarineHourly.secondary_swell_wave_period, label: 'Secondary Swell Wave Period', mode: ModeType.marine, fixedUnit: 's', chart: ChartKind.line, color: Colors.green),
      FieldSpec(enumKey: MarineHourly.secondary_swell_wave_direction, label: 'Secondary Swell Wave Direction', mode: ModeType.marine, fixedUnit: '°', chart: ChartKind.line, color: Colors.deepOrange),
      FieldSpec(enumKey: MarineHourly.tertiary_swell_wave_height, label: 'Tertiary Swell Wave Height', mode: ModeType.marine, fixedUnit: 'm', chart: ChartKind.line, color: Colors.blue),
      FieldSpec(enumKey: MarineHourly.tertiary_swell_wave_period, label: 'Tertiary Swell Wave Period', mode: ModeType.marine, fixedUnit: 's', chart: ChartKind.line, color: Colors.tealAccent),
      FieldSpec(enumKey: MarineHourly.tertiary_swell_wave_direction, label: 'Tertiary Swell Wave Direction', mode: ModeType.marine, fixedUnit: '°', chart: ChartKind.line, color: Colors.purpleAccent),
      FieldSpec(enumKey: MarineHourly.sea_level_height_msl, label: 'Sea Level Height MSL', mode: ModeType.marine, fixedUnit: 'm', chart: ChartKind.line, color: Colors.deepPurple),
      FieldSpec(enumKey: MarineHourly.sea_surface_temperature, label: 'Sea Surface Temperature', mode: ModeType.marine, unitCategory: UnitCategory.temperature, color: Colors.lime, tier: FieldTier.primary),
      FieldSpec(enumKey: MarineHourly.ocean_current_velocity, label: 'Ocean Current Velocity', mode: ModeType.marine, unitCategory: UnitCategory.windspeed, color: Colors.yellowAccent),
      FieldSpec(enumKey: MarineHourly.ocean_current_direction, label: 'Ocean Current Direction', mode: ModeType.marine, fixedUnit: '°', chart: ChartKind.line, color: Colors.amber),
      FieldSpec(enumKey: MarineHourly.invert_barometer_height, label: 'Invert Barometer Height', mode: ModeType.marine, fixedUnit: 'm', chart: ChartKind.line, color: Colors.blueAccent),
    ],
    // AirQualityHourly -- full 42-value enum (pollutants, full pollen panel,
    // both EU/US AQI sub-indices, plus wildfire/aerosol species).
    ModeType.airQuality: [
      FieldSpec(enumKey: AirQualityHourly.pm10, label: 'PM10', mode: ModeType.airQuality, fixedUnit: 'µg/m³', chart: ChartKind.line, color: Colors.amber, tier: FieldTier.primary),
      FieldSpec(enumKey: AirQualityHourly.pm2_5, label: 'PM2.5 5', mode: ModeType.airQuality, fixedUnit: 'µg/m³', chart: ChartKind.line, color: Colors.blueAccent, tier: FieldTier.primary),
      FieldSpec(enumKey: AirQualityHourly.carbon_monoxide, label: 'Carbon Monoxide', mode: ModeType.airQuality, fixedUnit: 'µg/m³', chart: ChartKind.line, color: Colors.grey),
      FieldSpec(enumKey: AirQualityHourly.carbon_dioxide, label: 'Carbon Dioxide', mode: ModeType.airQuality, fixedUnit: 'µg/m³', chart: ChartKind.line, color: Colors.orange),
      FieldSpec(enumKey: AirQualityHourly.nitrogen_dioxide, label: 'Nitrogen Dioxide', mode: ModeType.airQuality, fixedUnit: 'µg/m³', chart: ChartKind.line, color: Colors.teal),
      FieldSpec(enumKey: AirQualityHourly.sulphur_dioxide, label: 'Sulphur Dioxide', mode: ModeType.airQuality, fixedUnit: 'µg/m³', chart: ChartKind.line, color: Colors.cyan),
      FieldSpec(enumKey: AirQualityHourly.ozone, label: 'Ozone', mode: ModeType.airQuality, fixedUnit: 'µg/m³', chart: ChartKind.line, color: Colors.pinkAccent, tier: FieldTier.primary),
      FieldSpec(enumKey: AirQualityHourly.aerosol_optical_depth, label: 'Aerosol Optical Depth', mode: ModeType.airQuality, fixedUnit: 'm', chart: ChartKind.line, color: Colors.redAccent),
      FieldSpec(enumKey: AirQualityHourly.dust, label: 'Dust', mode: ModeType.airQuality, fixedUnit: 'µg/m³', chart: ChartKind.line, color: Colors.purple),
      FieldSpec(enumKey: AirQualityHourly.uv_index, label: 'UV Index', mode: ModeType.airQuality, fixedUnit: '', chart: ChartKind.line, color: Colors.indigo),
      FieldSpec(enumKey: AirQualityHourly.uv_index_clear_sky, label: 'UV Index Clear Sky', mode: ModeType.airQuality, fixedUnit: '', chart: ChartKind.line, color: Colors.brown),
      FieldSpec(enumKey: AirQualityHourly.ammonia, label: 'Ammonia', mode: ModeType.airQuality, fixedUnit: 'µg/m³', chart: ChartKind.line, color: Colors.lightBlue),
      FieldSpec(enumKey: AirQualityHourly.methane, label: 'Methane', mode: ModeType.airQuality, fixedUnit: 'µg/m³', chart: ChartKind.line, color: Colors.green),
      FieldSpec(enumKey: AirQualityHourly.alder_pollen, label: 'Alder Pollen', mode: ModeType.airQuality, fixedUnit: 'grains/m³', chart: ChartKind.line, color: Colors.deepOrange),
      FieldSpec(enumKey: AirQualityHourly.birch_pollen, label: 'Birch Pollen', mode: ModeType.airQuality, fixedUnit: 'grains/m³', chart: ChartKind.line, color: Colors.blue),
      FieldSpec(enumKey: AirQualityHourly.grass_pollen, label: 'Grass Pollen', mode: ModeType.airQuality, fixedUnit: 'grains/m³', chart: ChartKind.line, color: Colors.tealAccent),
      FieldSpec(enumKey: AirQualityHourly.mugwort_pollen, label: 'Mugwort Pollen', mode: ModeType.airQuality, fixedUnit: 'grains/m³', chart: ChartKind.line, color: Colors.purpleAccent),
      FieldSpec(enumKey: AirQualityHourly.olive_pollen, label: 'Olive Pollen', mode: ModeType.airQuality, fixedUnit: 'grains/m³', chart: ChartKind.line, color: Colors.deepPurple),
      FieldSpec(enumKey: AirQualityHourly.ragweed_pollen, label: 'Ragweed Pollen', mode: ModeType.airQuality, fixedUnit: 'grains/m³', chart: ChartKind.line, color: Colors.lime),
      FieldSpec(enumKey: AirQualityHourly.european_aqi, label: 'European AQI', mode: ModeType.airQuality, fixedUnit: '', chart: ChartKind.line, color: Colors.yellowAccent),
      FieldSpec(enumKey: AirQualityHourly.european_aqi_pm2_5, label: 'European AQI PM2.5 5', mode: ModeType.airQuality, fixedUnit: '', chart: ChartKind.line, color: Colors.amber),
      FieldSpec(enumKey: AirQualityHourly.european_aqi_pm10, label: 'European AQI PM10', mode: ModeType.airQuality, fixedUnit: '', chart: ChartKind.line, color: Colors.blueAccent),
      FieldSpec(enumKey: AirQualityHourly.european_aqi_nitrogen_dioxide, label: 'European AQI Nitrogen Dioxide', mode: ModeType.airQuality, fixedUnit: 'µg/m³', chart: ChartKind.line, color: Colors.grey),
      FieldSpec(enumKey: AirQualityHourly.european_aqi_ozone, label: 'European AQI Ozone', mode: ModeType.airQuality, fixedUnit: 'µg/m³', chart: ChartKind.line, color: Colors.orange),
      FieldSpec(enumKey: AirQualityHourly.european_aqi_sulphur_dioxide, label: 'European AQI Sulphur Dioxide', mode: ModeType.airQuality, fixedUnit: 'µg/m³', chart: ChartKind.line, color: Colors.teal),
      FieldSpec(enumKey: AirQualityHourly.us_aqi, label: 'Us AQI', mode: ModeType.airQuality, fixedUnit: '', chart: ChartKind.line, color: Colors.cyan, tier: FieldTier.primary),
      FieldSpec(enumKey: AirQualityHourly.us_aqi_pm2_5, label: 'Us AQI PM2.5 5', mode: ModeType.airQuality, fixedUnit: '', chart: ChartKind.line, color: Colors.pinkAccent),
      FieldSpec(enumKey: AirQualityHourly.us_aqi_pm10, label: 'Us AQI PM10', mode: ModeType.airQuality, fixedUnit: '', chart: ChartKind.line, color: Colors.redAccent),
      FieldSpec(enumKey: AirQualityHourly.us_aqi_nitrogen_dioxide, label: 'Us AQI Nitrogen Dioxide', mode: ModeType.airQuality, fixedUnit: 'µg/m³', chart: ChartKind.line, color: Colors.purple),
      FieldSpec(enumKey: AirQualityHourly.us_aqi_carbon_monoxide, label: 'Us AQI Carbon Monoxide', mode: ModeType.airQuality, fixedUnit: 'µg/m³', chart: ChartKind.line, color: Colors.indigo),
      FieldSpec(enumKey: AirQualityHourly.us_aqi_ozone, label: 'Us AQI Ozone', mode: ModeType.airQuality, fixedUnit: 'µg/m³', chart: ChartKind.line, color: Colors.brown),
      FieldSpec(enumKey: AirQualityHourly.us_aqi_sulphur_dioxide, label: 'Us AQI Sulphur Dioxide', mode: ModeType.airQuality, fixedUnit: 'µg/m³', chart: ChartKind.line, color: Colors.lightBlue),
      FieldSpec(enumKey: AirQualityHourly.formaldehyde, label: 'Formaldehyde', mode: ModeType.airQuality, fixedUnit: 'µg/m³', chart: ChartKind.line, color: Colors.green),
      FieldSpec(enumKey: AirQualityHourly.glyoxal, label: 'Glyoxal', mode: ModeType.airQuality, fixedUnit: 'µg/m³', chart: ChartKind.line, color: Colors.deepOrange),
      FieldSpec(enumKey: AirQualityHourly.non_methane_volatile_organic_compounds, label: 'Non Methane Volatile Organic Compounds', mode: ModeType.airQuality, fixedUnit: 'µg/m³', chart: ChartKind.line, color: Colors.blue),
      FieldSpec(enumKey: AirQualityHourly.pm10_wildfires, label: 'PM10 Wildfires', mode: ModeType.airQuality, fixedUnit: 'µg/m³', chart: ChartKind.line, color: Colors.tealAccent),
      FieldSpec(enumKey: AirQualityHourly.peroxyacyl_nitrates, label: 'Peroxyacyl Nitrates', mode: ModeType.airQuality, fixedUnit: 'µg/m³', chart: ChartKind.line, color: Colors.purpleAccent),
      FieldSpec(enumKey: AirQualityHourly.secondary_inorganic_aerosol, label: 'Secondary Inorganic Aerosol', mode: ModeType.airQuality, fixedUnit: 'µg/m³', chart: ChartKind.line, color: Colors.deepPurple),
      FieldSpec(enumKey: AirQualityHourly.residential_elementary_carbon, label: 'Residential Elementary Carbon', mode: ModeType.airQuality, fixedUnit: 'µg/m³', chart: ChartKind.line, color: Colors.lime),
      FieldSpec(enumKey: AirQualityHourly.total_elementary_carbon, label: 'Total Elementary Carbon', mode: ModeType.airQuality, fixedUnit: 'µg/m³', chart: ChartKind.line, color: Colors.yellowAccent),
      FieldSpec(enumKey: AirQualityHourly.sea_salt_aerosol, label: 'Sea Salt Aerosol', mode: ModeType.airQuality, fixedUnit: 'µg/m³', chart: ChartKind.line, color: Colors.amber),
      FieldSpec(enumKey: AirQualityHourly.nitrogen_monoxide, label: 'Nitrogen Monoxide', mode: ModeType.airQuality, fixedUnit: 'µg/m³', chart: ChartKind.line, color: Colors.blueAccent),
    ],
    // FloodDaily -- full 7-value enum (base + 6 aggregation variants).
    ModeType.flood: [
      FieldSpec(enumKey: FloodDaily.river_discharge, label: 'River Discharge', mode: ModeType.flood, fixedUnit: 'm³/s', chart: ChartKind.bar, color: Colors.amber, tier: FieldTier.primary),
      FieldSpec(enumKey: FloodDaily.river_discharge_mean, label: 'River Discharge Mean', mode: ModeType.flood, fixedUnit: 'm³/s', chart: ChartKind.bar, color: Colors.blueAccent),
      FieldSpec(enumKey: FloodDaily.river_discharge_median, label: 'River Discharge Median', mode: ModeType.flood, fixedUnit: 'm³/s', chart: ChartKind.bar, color: Colors.grey),
      FieldSpec(enumKey: FloodDaily.river_discharge_max, label: 'River Discharge Max', mode: ModeType.flood, fixedUnit: 'm³/s', chart: ChartKind.bar, color: Colors.orange),
      FieldSpec(enumKey: FloodDaily.river_discharge_min, label: 'River Discharge Min', mode: ModeType.flood, fixedUnit: 'm³/s', chart: ChartKind.bar, color: Colors.teal),
      FieldSpec(enumKey: FloodDaily.river_discharge_p25, label: 'River Discharge P25', mode: ModeType.flood, fixedUnit: 'm³/s', chart: ChartKind.bar, color: Colors.cyan),
      FieldSpec(enumKey: FloodDaily.river_discharge_p75, label: 'River Discharge P75', mode: ModeType.flood, fixedUnit: 'm³/s', chart: ChartKind.bar, color: Colors.pinkAccent),
    ],
    // EnsembleHourly -- full 55-value enum (surface + 4 wind altitudes incl.
    // 100m variant + 4 soil depth bands + 2 pressure levels + full radiation
    // suite with _instant counterparts + wet bulb temp + CAPE).
    ModeType.ensemble: [
      FieldSpec(enumKey: EnsembleHourly.temperature_2m, label: 'Temperature (2m)', mode: ModeType.ensemble, unitCategory: UnitCategory.temperature, color: Colors.amber, tier: FieldTier.primary),
      FieldSpec(enumKey: EnsembleHourly.relative_humidity_2m, label: 'Relative Humidity (2m)', mode: ModeType.ensemble, fixedUnit: '%', chart: ChartKind.line, color: Colors.blueAccent),
      FieldSpec(enumKey: EnsembleHourly.dew_point_2m, label: 'Dew Point (2m)', mode: ModeType.ensemble, unitCategory: UnitCategory.temperature, color: Colors.grey),
      FieldSpec(enumKey: EnsembleHourly.apparent_temperature, label: 'Apparent Temperature', mode: ModeType.ensemble, unitCategory: UnitCategory.temperature, color: Colors.orange),
      FieldSpec(enumKey: EnsembleHourly.precipitation, label: 'Precipitation', mode: ModeType.ensemble, unitCategory: UnitCategory.precipitation, chart: ChartKind.bar, color: Colors.teal, tier: FieldTier.primary),
      FieldSpec(enumKey: EnsembleHourly.rain, label: 'Rain', mode: ModeType.ensemble, unitCategory: UnitCategory.precipitation, chart: ChartKind.bar, color: Colors.cyan),
      FieldSpec(enumKey: EnsembleHourly.snowfall, label: 'Snowfall', mode: ModeType.ensemble, unitCategory: UnitCategory.precipitation, chart: ChartKind.bar, color: Colors.pinkAccent),
      FieldSpec(enumKey: EnsembleHourly.snow_depth, label: 'Snow Depth', mode: ModeType.ensemble, fixedUnit: 'm', chart: ChartKind.line, color: Colors.redAccent),
      FieldSpec(enumKey: EnsembleHourly.weather_code, label: 'Weather Code', mode: ModeType.ensemble, fixedUnit: '', chart: ChartKind.line, color: Colors.purple),
      FieldSpec(enumKey: EnsembleHourly.pressure_msl, label: 'Pressure MSL', mode: ModeType.ensemble, fixedUnit: 'hPa', chart: ChartKind.line, color: Colors.indigo, tier: FieldTier.primary),
      FieldSpec(enumKey: EnsembleHourly.surface_pressure, label: 'Surface Pressure', mode: ModeType.ensemble, fixedUnit: 'hPa', chart: ChartKind.line, color: Colors.brown),
      FieldSpec(enumKey: EnsembleHourly.cloud_cover, label: 'Cloud Cover', mode: ModeType.ensemble, fixedUnit: '%', chart: ChartKind.line, color: Colors.lightBlue, tier: FieldTier.primary),
      FieldSpec(enumKey: EnsembleHourly.visibility, label: 'Visibility', mode: ModeType.ensemble, fixedUnit: 'm', chart: ChartKind.line, color: Colors.green),
      FieldSpec(enumKey: EnsembleHourly.et0_fao_evapotranspiration, label: 'ET0 FAO Evapotranspiration', mode: ModeType.ensemble, fixedUnit: 'mm', chart: ChartKind.line, color: Colors.deepOrange),
      FieldSpec(enumKey: EnsembleHourly.vapour_pressure_deficit, label: 'Vapour Pressure Deficit', mode: ModeType.ensemble, fixedUnit: 'kPa', chart: ChartKind.line, color: Colors.blue),
      FieldSpec(enumKey: EnsembleHourly.wind_speed_10m, label: 'Wind Speed (10m)', mode: ModeType.ensemble, unitCategory: UnitCategory.windspeed, color: Colors.tealAccent, tier: FieldTier.primary),
      FieldSpec(enumKey: EnsembleHourly.wind_speed_80m, label: 'Wind Speed (80m)', mode: ModeType.ensemble, unitCategory: UnitCategory.windspeed, color: Colors.purpleAccent),
      FieldSpec(enumKey: EnsembleHourly.wind_speed_100m, label: 'Wind Speed (100m)', mode: ModeType.ensemble, unitCategory: UnitCategory.windspeed, color: Colors.deepPurple),
      FieldSpec(enumKey: EnsembleHourly.wind_speed_120m, label: 'Wind Speed (120m)', mode: ModeType.ensemble, unitCategory: UnitCategory.windspeed, color: Colors.lime),
      FieldSpec(enumKey: EnsembleHourly.wind_direction_10m, label: 'Wind Direction (10m)', mode: ModeType.ensemble, fixedUnit: '°', chart: ChartKind.line, color: Colors.yellowAccent),
      FieldSpec(enumKey: EnsembleHourly.wind_direction_80m, label: 'Wind Direction (80m)', mode: ModeType.ensemble, fixedUnit: '°', chart: ChartKind.line, color: Colors.amber),
      FieldSpec(enumKey: EnsembleHourly.wind_direction_100m, label: 'Wind Direction (100m)', mode: ModeType.ensemble, fixedUnit: '°', chart: ChartKind.line, color: Colors.blueAccent),
      FieldSpec(enumKey: EnsembleHourly.wind_direction_120m, label: 'Wind Direction (120m)', mode: ModeType.ensemble, fixedUnit: '°', chart: ChartKind.line, color: Colors.grey),
      FieldSpec(enumKey: EnsembleHourly.wind_gusts_10m, label: 'Wind Gusts (10m)', mode: ModeType.ensemble, unitCategory: UnitCategory.windspeed, color: Colors.orange),
      FieldSpec(enumKey: EnsembleHourly.temperature_80m, label: 'Temperature (80m)', mode: ModeType.ensemble, unitCategory: UnitCategory.temperature, color: Colors.teal),
      FieldSpec(enumKey: EnsembleHourly.temperature_120m, label: 'Temperature (120m)', mode: ModeType.ensemble, unitCategory: UnitCategory.temperature, color: Colors.cyan),
      FieldSpec(enumKey: EnsembleHourly.surface_temperature, label: 'Surface Temperature', mode: ModeType.ensemble, unitCategory: UnitCategory.temperature, color: Colors.pinkAccent),
      FieldSpec(enumKey: EnsembleHourly.soil_temperature_0_to_10cm, label: 'Soil Temperature 0 To 10cm', mode: ModeType.ensemble, unitCategory: UnitCategory.temperature, color: Colors.redAccent),
      FieldSpec(enumKey: EnsembleHourly.soil_temperature_10_to_40cm, label: 'Soil Temperature 10 To 40cm', mode: ModeType.ensemble, unitCategory: UnitCategory.temperature, color: Colors.purple),
      FieldSpec(enumKey: EnsembleHourly.soil_temperature_40_to_100cm, label: 'Soil Temperature 40 To 100cm', mode: ModeType.ensemble, unitCategory: UnitCategory.temperature, color: Colors.indigo),
      FieldSpec(enumKey: EnsembleHourly.soil_temperature_100_to_200cm, label: 'Soil Temperature 100 To 200cm', mode: ModeType.ensemble, unitCategory: UnitCategory.temperature, color: Colors.brown),
      FieldSpec(enumKey: EnsembleHourly.soil_moisture_0_to_10cm, label: 'Soil Moisture 0 To 10cm', mode: ModeType.ensemble, fixedUnit: 'm³/m³', chart: ChartKind.line, color: Colors.lightBlue),
      FieldSpec(enumKey: EnsembleHourly.soil_moisture_10_to_40cm, label: 'Soil Moisture 10 To 40cm', mode: ModeType.ensemble, fixedUnit: 'm³/m³', chart: ChartKind.line, color: Colors.green),
      FieldSpec(enumKey: EnsembleHourly.soil_moisture_40_to_100cm, label: 'Soil Moisture 40 To 100cm', mode: ModeType.ensemble, fixedUnit: 'm³/m³', chart: ChartKind.line, color: Colors.deepOrange),
      FieldSpec(enumKey: EnsembleHourly.soil_moisture_100_to_200cm, label: 'Soil Moisture 100 To 200cm', mode: ModeType.ensemble, fixedUnit: 'm³/m³', chart: ChartKind.line, color: Colors.blue),
      FieldSpec(enumKey: EnsembleHourly.uv_index, label: 'UV Index', mode: ModeType.ensemble, fixedUnit: '', chart: ChartKind.line, color: Colors.tealAccent),
      FieldSpec(enumKey: EnsembleHourly.uv_index_clear_sky, label: 'UV Index Clear Sky', mode: ModeType.ensemble, fixedUnit: '', chart: ChartKind.line, color: Colors.purpleAccent),
      FieldSpec(enumKey: EnsembleHourly.temperature_500hPa, label: 'Temperature (500hPa)', mode: ModeType.ensemble, unitCategory: UnitCategory.temperature, color: Colors.deepPurple),
      FieldSpec(enumKey: EnsembleHourly.temperature_850hPa, label: 'Temperature (850hPa)', mode: ModeType.ensemble, unitCategory: UnitCategory.temperature, color: Colors.lime),
      FieldSpec(enumKey: EnsembleHourly.geopotential_height_500hPa, label: 'Geopotential Height (500hPa)', mode: ModeType.ensemble, fixedUnit: 'm', chart: ChartKind.line, color: Colors.yellowAccent),
      FieldSpec(enumKey: EnsembleHourly.geopotential_height_850hPa, label: 'Geopotential Height (850hPa)', mode: ModeType.ensemble, fixedUnit: 'm', chart: ChartKind.line, color: Colors.amber),
      FieldSpec(enumKey: EnsembleHourly.wet_bulb_temperature_2m, label: 'Wet Bulb Temperature (2m)', mode: ModeType.ensemble, unitCategory: UnitCategory.temperature, color: Colors.blueAccent),
      FieldSpec(enumKey: EnsembleHourly.cape, label: 'CAPE', mode: ModeType.ensemble, fixedUnit: 'J/kg', chart: ChartKind.line, color: Colors.grey),
      FieldSpec(enumKey: EnsembleHourly.freezing_level_height, label: 'Freezing Level Height', mode: ModeType.ensemble, fixedUnit: 'm', chart: ChartKind.line, color: Colors.orange),
      FieldSpec(enumKey: EnsembleHourly.sunshine_duration, label: 'Sunshine Duration', mode: ModeType.ensemble, fixedUnit: 's', chart: ChartKind.line, color: Colors.teal),
      FieldSpec(enumKey: EnsembleHourly.shortwave_radiation, label: 'Shortwave Radiation', mode: ModeType.ensemble, fixedUnit: 'W/m²', chart: ChartKind.line, color: Colors.cyan),
      FieldSpec(enumKey: EnsembleHourly.direct_radiation, label: 'Direct Radiation', mode: ModeType.ensemble, fixedUnit: 'W/m²', chart: ChartKind.line, color: Colors.pinkAccent),
      FieldSpec(enumKey: EnsembleHourly.diffuse_radiation, label: 'Diffuse Radiation', mode: ModeType.ensemble, fixedUnit: 'W/m²', chart: ChartKind.line, color: Colors.redAccent),
      FieldSpec(enumKey: EnsembleHourly.direct_normal_irradiance, label: 'Direct Normal Irradiance', mode: ModeType.ensemble, fixedUnit: 'W/m²', chart: ChartKind.line, color: Colors.purple),
      FieldSpec(enumKey: EnsembleHourly.global_tilted_irradiance, label: 'Global Tilted Irradiance', mode: ModeType.ensemble, fixedUnit: 'W/m²', chart: ChartKind.line, color: Colors.indigo),
      FieldSpec(enumKey: EnsembleHourly.shortwave_radiation_instant, label: 'Shortwave Radiation Instant', mode: ModeType.ensemble, fixedUnit: 'W/m²', chart: ChartKind.line, color: Colors.brown),
      FieldSpec(enumKey: EnsembleHourly.direct_radiation_instant, label: 'Direct Radiation Instant', mode: ModeType.ensemble, fixedUnit: 'W/m²', chart: ChartKind.line, color: Colors.lightBlue),
      FieldSpec(enumKey: EnsembleHourly.diffuse_radiation_instant, label: 'Diffuse Radiation Instant', mode: ModeType.ensemble, fixedUnit: 'W/m²', chart: ChartKind.line, color: Colors.green),
      FieldSpec(enumKey: EnsembleHourly.direct_normal_irradiance_instant, label: 'Direct Normal Irradiance Instant', mode: ModeType.ensemble, fixedUnit: 'W/m²', chart: ChartKind.line, color: Colors.deepOrange),
      FieldSpec(enumKey: EnsembleHourly.global_tilted_irradiance_instant, label: 'Global Tilted Irradiance Instant', mode: ModeType.ensemble, fixedUnit: 'W/m²', chart: ChartKind.line, color: Colors.blue),
    ],
    ModeType.elevation: [],
    ModeType.geocoding: [],
  };
});

// Full WeatherDaily registry (59 verified values) -- separate from the main
// per-ModeType map since weather's daily variant isn't its own ModeType.
final fullWeatherDailyFieldsProvider = Provider<List<FieldSpec>>((ref) {
  return [
      FieldSpec(enumKey: WeatherDaily.weather_code, label: 'Weather Code', mode: ModeType.weather, fixedUnit: '', chart: ChartKind.line, color: Colors.amber, category: 'Conditions'),
      FieldSpec(enumKey: WeatherDaily.temperature_2m_max, label: 'Temperature (2m) Max', mode: ModeType.weather, unitCategory: UnitCategory.temperature, color: Colors.blueAccent, tier: FieldTier.primary, category: 'Temperature'),
      FieldSpec(enumKey: WeatherDaily.temperature_2m_min, label: 'Temperature (2m) Min', mode: ModeType.weather, unitCategory: UnitCategory.temperature, color: Colors.grey, tier: FieldTier.primary, category: 'Temperature'),
      FieldSpec(enumKey: WeatherDaily.apparent_temperature_max, label: 'Apparent Temperature Max', mode: ModeType.weather, unitCategory: UnitCategory.temperature, color: Colors.orange, category: 'Temperature'),
      FieldSpec(enumKey: WeatherDaily.apparent_temperature_min, label: 'Apparent Temperature Min', mode: ModeType.weather, unitCategory: UnitCategory.temperature, color: Colors.teal, category: 'Temperature'),
      FieldSpec(enumKey: WeatherDaily.sunrise, label: 'Sunrise', mode: ModeType.weather, fixedUnit: '', chart: ChartKind.line, color: Colors.cyan, category: 'Sky & Sun'),
      FieldSpec(enumKey: WeatherDaily.sunset, label: 'Sunset', mode: ModeType.weather, fixedUnit: '', chart: ChartKind.line, color: Colors.pinkAccent, category: 'Sky & Sun'),
      FieldSpec(enumKey: WeatherDaily.daylight_duration, label: 'Daylight Duration', mode: ModeType.weather, fixedUnit: 's', chart: ChartKind.line, color: Colors.redAccent, category: 'Sky & Sun'),
      FieldSpec(enumKey: WeatherDaily.sunshine_duration, label: 'Sunshine Duration', mode: ModeType.weather, fixedUnit: 's', chart: ChartKind.line, color: Colors.purple, category: 'Sky & Sun'),
      FieldSpec(enumKey: WeatherDaily.uv_index_max, label: 'UV Index Max', mode: ModeType.weather, fixedUnit: '', chart: ChartKind.line, color: Colors.indigo, tier: FieldTier.primary, category: 'Sky & Sun'),
      FieldSpec(enumKey: WeatherDaily.uv_index_clear_sky_max, label: 'UV Index Clear Sky Max', mode: ModeType.weather, fixedUnit: '', chart: ChartKind.line, color: Colors.brown, category: 'Sky & Sun'),
      FieldSpec(enumKey: WeatherDaily.rain_sum, label: 'Rain Sum', mode: ModeType.weather, unitCategory: UnitCategory.precipitation, chart: ChartKind.bar, color: Colors.lightBlue, category: 'Precipitation'),
      FieldSpec(enumKey: WeatherDaily.showers_sum, label: 'Showers Sum', mode: ModeType.weather, fixedUnit: '', chart: ChartKind.bar, color: Colors.green, category: 'Precipitation'),
      FieldSpec(enumKey: WeatherDaily.snowfall_sum, label: 'Snowfall Sum', mode: ModeType.weather, unitCategory: UnitCategory.precipitation, chart: ChartKind.bar, color: Colors.deepOrange, category: 'Precipitation'),
      FieldSpec(enumKey: WeatherDaily.precipitation_sum, label: 'Precipitation Sum', mode: ModeType.weather, unitCategory: UnitCategory.precipitation, chart: ChartKind.bar, color: Colors.blue, tier: FieldTier.primary, category: 'Precipitation'),
      FieldSpec(enumKey: WeatherDaily.precipitation_hours, label: 'Precipitation Hours', mode: ModeType.weather, unitCategory: UnitCategory.precipitation, chart: ChartKind.bar, color: Colors.tealAccent, category: 'Precipitation'),
      FieldSpec(enumKey: WeatherDaily.precipitation_probability_max, label: 'Precipitation Probability Max', mode: ModeType.weather, unitCategory: UnitCategory.precipitation, chart: ChartKind.bar, color: Colors.purpleAccent, category: 'Precipitation'),
      FieldSpec(enumKey: WeatherDaily.wind_speed_10m_max, label: 'Wind Speed (10m) Max', mode: ModeType.weather, unitCategory: UnitCategory.windspeed, color: Colors.deepPurple, tier: FieldTier.primary, category: 'Wind'),
      FieldSpec(enumKey: WeatherDaily.wind_gusts_10m_max, label: 'Wind Gusts (10m) Max', mode: ModeType.weather, unitCategory: UnitCategory.windspeed, color: Colors.lime, category: 'Wind'),
      FieldSpec(enumKey: WeatherDaily.wind_direction_10m_dominant, label: 'Wind Direction (10m) Dominant', mode: ModeType.weather, fixedUnit: '°', chart: ChartKind.line, color: Colors.yellowAccent, category: 'Wind'),
      FieldSpec(enumKey: WeatherDaily.shortwave_radiation_sum, label: 'Shortwave Radiation Sum', mode: ModeType.weather, fixedUnit: 'W/m²', chart: ChartKind.bar, color: Colors.amber, category: 'Radiation'),
      FieldSpec(enumKey: WeatherDaily.et0_fao_evapotranspiration, label: 'ET0 FAO Evapotranspiration', mode: ModeType.weather, fixedUnit: 'mm', chart: ChartKind.line, color: Colors.blueAccent, category: 'Soil & Moisture'),
      FieldSpec(enumKey: WeatherDaily.temperature_2m_mean, label: 'Temperature (2m) Mean', mode: ModeType.weather, unitCategory: UnitCategory.temperature, color: Colors.grey, category: 'Temperature'),
      FieldSpec(enumKey: WeatherDaily.apparent_temperature_mean, label: 'Apparent Temperature Mean', mode: ModeType.weather, unitCategory: UnitCategory.temperature, color: Colors.orange, category: 'Temperature'),
      FieldSpec(enumKey: WeatherDaily.cape_mean, label: 'CAPE Mean', mode: ModeType.weather, fixedUnit: 'J/kg', chart: ChartKind.line, color: Colors.teal, category: 'Atmosphere'),
      FieldSpec(enumKey: WeatherDaily.cape_max, label: 'CAPE Max', mode: ModeType.weather, fixedUnit: 'J/kg', chart: ChartKind.line, color: Colors.cyan, category: 'Atmosphere'),
      FieldSpec(enumKey: WeatherDaily.cape_min, label: 'CAPE Min', mode: ModeType.weather, fixedUnit: 'J/kg', chart: ChartKind.line, color: Colors.pinkAccent, category: 'Atmosphere'),
      FieldSpec(enumKey: WeatherDaily.cloud_cover_mean, label: 'Cloud Cover Mean', mode: ModeType.weather, fixedUnit: '%', chart: ChartKind.line, color: Colors.redAccent, category: 'Sky & Sun'),
      FieldSpec(enumKey: WeatherDaily.cloud_cover_max, label: 'Cloud Cover Max', mode: ModeType.weather, fixedUnit: '%', chart: ChartKind.line, color: Colors.purple, category: 'Sky & Sun'),
      FieldSpec(enumKey: WeatherDaily.cloud_cover_min, label: 'Cloud Cover Min', mode: ModeType.weather, fixedUnit: '%', chart: ChartKind.line, color: Colors.indigo, category: 'Sky & Sun'),
      FieldSpec(enumKey: WeatherDaily.dew_point_2m_mean, label: 'Dew Point (2m) Mean', mode: ModeType.weather, unitCategory: UnitCategory.temperature, color: Colors.brown, category: 'Temperature'),
      FieldSpec(enumKey: WeatherDaily.dew_point_2m_max, label: 'Dew Point (2m) Max', mode: ModeType.weather, unitCategory: UnitCategory.temperature, color: Colors.lightBlue, category: 'Temperature'),
      FieldSpec(enumKey: WeatherDaily.dew_point_2m_min, label: 'Dew Point (2m) Min', mode: ModeType.weather, unitCategory: UnitCategory.temperature, color: Colors.green, category: 'Temperature'),
      FieldSpec(enumKey: WeatherDaily.et0_fao_evapotranspiration_sum, label: 'ET0 FAO Evapotranspiration Sum', mode: ModeType.weather, fixedUnit: 'mm', chart: ChartKind.bar, color: Colors.deepOrange, category: 'Soil & Moisture'),
      FieldSpec(enumKey: WeatherDaily.leaf_wetness_probability_mean, label: 'Leaf Wetness Probability Mean', mode: ModeType.weather, fixedUnit: '%', chart: ChartKind.line, color: Colors.blue, category: 'Soil & Moisture'),
      FieldSpec(enumKey: WeatherDaily.precipitation_probability_mean, label: 'Precipitation Probability Mean', mode: ModeType.weather, unitCategory: UnitCategory.precipitation, chart: ChartKind.bar, color: Colors.tealAccent, category: 'Precipitation'),
      FieldSpec(enumKey: WeatherDaily.precipitation_probability_min, label: 'Precipitation Probability Min', mode: ModeType.weather, unitCategory: UnitCategory.precipitation, chart: ChartKind.bar, color: Colors.purpleAccent, category: 'Precipitation'),
      FieldSpec(enumKey: WeatherDaily.relative_humidity_2m_mean, label: 'Relative Humidity (2m) Mean', mode: ModeType.weather, fixedUnit: '%', chart: ChartKind.line, color: Colors.deepPurple, category: 'Humidity'),
      FieldSpec(enumKey: WeatherDaily.relative_humidity_2m_max, label: 'Relative Humidity (2m) Max', mode: ModeType.weather, fixedUnit: '%', chart: ChartKind.line, color: Colors.lime, category: 'Humidity'),
      FieldSpec(enumKey: WeatherDaily.relative_humidity_2m_min, label: 'Relative Humidity (2m) Min', mode: ModeType.weather, fixedUnit: '%', chart: ChartKind.line, color: Colors.yellowAccent, category: 'Humidity'),
      FieldSpec(enumKey: WeatherDaily.snowfall_water_equivalent_sum, label: 'Snowfall Water Equivalent Sum', mode: ModeType.weather, fixedUnit: 'mm', chart: ChartKind.bar, color: Colors.amber, category: 'Precipitation'),
      FieldSpec(enumKey: WeatherDaily.pressure_msl_mean, label: 'Pressure MSL Mean', mode: ModeType.weather, fixedUnit: 'hPa', chart: ChartKind.line, color: Colors.blueAccent, category: 'Pressure'),
      FieldSpec(enumKey: WeatherDaily.pressure_msl_max, label: 'Pressure MSL Max', mode: ModeType.weather, fixedUnit: 'hPa', chart: ChartKind.line, color: Colors.grey, category: 'Pressure'),
      FieldSpec(enumKey: WeatherDaily.pressure_msl_min, label: 'Pressure MSL Min', mode: ModeType.weather, fixedUnit: 'hPa', chart: ChartKind.line, color: Colors.orange, category: 'Pressure'),
      FieldSpec(enumKey: WeatherDaily.surface_pressure_mean, label: 'Surface Pressure Mean', mode: ModeType.weather, fixedUnit: 'hPa', chart: ChartKind.line, color: Colors.teal, category: 'Pressure'),
      FieldSpec(enumKey: WeatherDaily.surface_pressure_max, label: 'Surface Pressure Max', mode: ModeType.weather, fixedUnit: 'hPa', chart: ChartKind.line, color: Colors.cyan, category: 'Pressure'),
      FieldSpec(enumKey: WeatherDaily.surface_pressure_min, label: 'Surface Pressure Min', mode: ModeType.weather, fixedUnit: 'hPa', chart: ChartKind.line, color: Colors.pinkAccent, category: 'Pressure'),
      FieldSpec(enumKey: WeatherDaily.updraft_max, label: 'Updraft Max', mode: ModeType.weather, fixedUnit: 'm/s', chart: ChartKind.line, color: Colors.redAccent, category: 'Wind'),
      FieldSpec(enumKey: WeatherDaily.visibility_mean, label: 'Visibility Mean', mode: ModeType.weather, fixedUnit: 'm', chart: ChartKind.line, color: Colors.purple, category: 'Sky & Sun'),
      FieldSpec(enumKey: WeatherDaily.visibility_min, label: 'Visibility Min', mode: ModeType.weather, fixedUnit: 'm', chart: ChartKind.line, color: Colors.indigo, category: 'Sky & Sun'),
      FieldSpec(enumKey: WeatherDaily.visibility_max, label: 'Visibility Max', mode: ModeType.weather, fixedUnit: 'm', chart: ChartKind.line, color: Colors.brown, category: 'Sky & Sun'),
      FieldSpec(enumKey: WeatherDaily.wind_gusts_10m_mean, label: 'Wind Gusts (10m) Mean', mode: ModeType.weather, unitCategory: UnitCategory.windspeed, color: Colors.lightBlue, category: 'Wind'),
      FieldSpec(enumKey: WeatherDaily.wind_speed_10m_mean, label: 'Wind Speed (10m) Mean', mode: ModeType.weather, unitCategory: UnitCategory.windspeed, color: Colors.green, category: 'Wind'),
      FieldSpec(enumKey: WeatherDaily.wind_gusts_10m_min, label: 'Wind Gusts (10m) Min', mode: ModeType.weather, unitCategory: UnitCategory.windspeed, color: Colors.deepOrange, category: 'Wind'),
      FieldSpec(enumKey: WeatherDaily.wind_speed_10m_min, label: 'Wind Speed (10m) Min', mode: ModeType.weather, unitCategory: UnitCategory.windspeed, color: Colors.blue, category: 'Wind'),
      FieldSpec(enumKey: WeatherDaily.wet_bulb_temperature_2m_mean, label: 'Wet Bulb Temperature (2m) Mean', mode: ModeType.weather, unitCategory: UnitCategory.temperature, color: Colors.tealAccent, category: 'Temperature'),
      FieldSpec(enumKey: WeatherDaily.wet_bulb_temperature_2m_max, label: 'Wet Bulb Temperature (2m) Max', mode: ModeType.weather, unitCategory: UnitCategory.temperature, color: Colors.purpleAccent, category: 'Temperature'),
      FieldSpec(enumKey: WeatherDaily.wet_bulb_temperature_2m_min, label: 'Wet Bulb Temperature (2m) Min', mode: ModeType.weather, unitCategory: UnitCategory.temperature, color: Colors.deepPurple, category: 'Temperature'),
      FieldSpec(enumKey: WeatherDaily.vapour_pressure_deficit_max, label: 'Vapour Pressure Deficit Max', mode: ModeType.weather, fixedUnit: 'kPa', chart: ChartKind.line, color: Colors.lime, category: 'Pressure'),
  ];
});

// fieldRegistryProvider above is already the exhaustive per-mode list (every
// verified enum value, tagged primary/secondary) -- it doubles as the full
// registry the "SELECT METRICS" dialog offers secondary fields from.
final fullFieldRegistryProvider = Provider<Map<ModeType, List<FieldSpec>>>((ref) {
  return ref.watch(fieldRegistryProvider);
});

// Full HistoricalDaily registry -- mirrors the WeatherDaily pattern above.
// NOTE: field names here follow Open-Meteo's documented Historical Weather
// API daily aggregation parameters (same naming convention the package
// already uses for WeatherDaily). If your installed open_meteo version
// doesn't export `HistoricalDaily`, this is the one spot in the file that
// won't compile -- swap `HistoricalDaily.x` for whatever the package's
// equivalent daily-historical enum is actually called and the rest of the
// wiring (jsonKey, dataProvider, activeFieldsProvider) needs no changes.
//
// This registry -- and defaulting Historical mode to it -- is the actual
// fix for "historical data not loading": requesting 5-10 years of HOURLY
// data across 5-7 primary fields was almost certainly hitting the Archive
// API's per-request data-volume ceiling, which is why the heatmap's day
// cells were coming back empty. Daily is >20x fewer data points for the
// same calendar coverage.
final fullHistoricalDailyFieldsProvider = Provider<List<FieldSpec>>((ref) {
  return [
    FieldSpec(enumKey: HistoricalDaily.weather_code, label: 'Weather Code', mode: ModeType.historical, fixedUnit: '', chart: ChartKind.line, color: Colors.purple),
    FieldSpec(enumKey: HistoricalDaily.temperature_2m_max, label: 'Temperature (2m) Max', mode: ModeType.historical, unitCategory: UnitCategory.temperature, color: Colors.blueAccent, tier: FieldTier.primary),
    FieldSpec(enumKey: HistoricalDaily.temperature_2m_min, label: 'Temperature (2m) Min', mode: ModeType.historical, unitCategory: UnitCategory.temperature, color: Colors.grey, tier: FieldTier.primary),
    FieldSpec(enumKey: HistoricalDaily.temperature_2m_mean, label: 'Temperature (2m) Mean', mode: ModeType.historical, unitCategory: UnitCategory.temperature, color: Colors.amber),
    FieldSpec(enumKey: HistoricalDaily.apparent_temperature_max, label: 'Apparent Temperature Max', mode: ModeType.historical, unitCategory: UnitCategory.temperature, color: Colors.orange),
    FieldSpec(enumKey: HistoricalDaily.apparent_temperature_min, label: 'Apparent Temperature Min', mode: ModeType.historical, unitCategory: UnitCategory.temperature, color: Colors.teal),
    FieldSpec(enumKey: HistoricalDaily.sunshine_duration, label: 'Sunshine Duration', mode: ModeType.historical, fixedUnit: 's', chart: ChartKind.line, color: Colors.cyan),
    FieldSpec(enumKey: HistoricalDaily.precipitation_sum, label: 'Precipitation Sum', mode: ModeType.historical, unitCategory: UnitCategory.precipitation, chart: ChartKind.bar, color: Colors.blue, tier: FieldTier.primary),
    FieldSpec(enumKey: HistoricalDaily.rain_sum, label: 'Rain Sum', mode: ModeType.historical, unitCategory: UnitCategory.precipitation, chart: ChartKind.bar, color: Colors.lightBlue),
    FieldSpec(enumKey: HistoricalDaily.snowfall_sum, label: 'Snowfall Sum', mode: ModeType.historical, unitCategory: UnitCategory.precipitation, chart: ChartKind.bar, color: Colors.indigo),
    FieldSpec(enumKey: HistoricalDaily.precipitation_hours, label: 'Precipitation Hours', mode: ModeType.historical, unitCategory: UnitCategory.precipitation, chart: ChartKind.bar, color: Colors.tealAccent),
    FieldSpec(enumKey: HistoricalDaily.wind_speed_10m_max, label: 'Wind Speed (10m) Max', mode: ModeType.historical, unitCategory: UnitCategory.windspeed, color: Colors.deepPurple, tier: FieldTier.primary),
    FieldSpec(enumKey: HistoricalDaily.wind_gusts_10m_max, label: 'Wind Gusts (10m) Max', mode: ModeType.historical, unitCategory: UnitCategory.windspeed, color: Colors.lime),
    FieldSpec(enumKey: HistoricalDaily.wind_direction_10m_dominant, label: 'Wind Direction (10m) Dominant', mode: ModeType.historical, fixedUnit: '°', chart: ChartKind.line, color: Colors.yellowAccent),
    FieldSpec(enumKey: HistoricalDaily.shortwave_radiation_sum, label: 'Shortwave Radiation Sum', mode: ModeType.historical, fixedUnit: 'W/m²', chart: ChartKind.bar, color: Colors.amber, tier: FieldTier.primary),
    FieldSpec(enumKey: HistoricalDaily.et0_fao_evapotranspiration, label: 'ET0 FAO Evapotranspiration', mode: ModeType.historical, fixedUnit: 'mm', chart: ChartKind.line, color: Colors.green),
  ];
});

/// Resolves the correct "full" field list for a mode given its current
/// resolution toggle (Weather/Historical only -- everything else has one
/// fixed enum set). Used by BOTH activeFieldsProvider (what's fetched) and
/// the "SELECT METRICS" picker (what's offered), so they can never drift
/// out of sync the way Weather's daily toggle previously could.
final resolvedFullFieldsProvider = Provider.family<List<FieldSpec>, ModeType>((ref, mode) {
  final appState = ref.watch(appStateProvider);
  // Past a 1-year window, the actual fetch is forced to daily regardless of
  // what the toggle last showed (see isLongRange / _ModeView) -- this must
  // mirror that exactly, or activeFieldsProvider hands out hourly field
  // keys while the request itself goes out as daily, and every hourly-only
  // key (e.g. relative_humidity_2m, which has no WeatherDaily equivalent by
  // that exact name) blows up the dataProvider's firstWhere lookup.
  final longRange = isLongRange(appState.rangeStart, appState.rangeEnd);
  final weatherResolution = longRange ? TemporalResolution.daily : appState.weatherResolution;
  final historicalResolution = longRange ? TemporalResolution.daily : appState.historicalResolution;
  if (mode == ModeType.weather && weatherResolution == TemporalResolution.daily) {
    return ref.watch(fullWeatherDailyFieldsProvider);
  }
  if (mode == ModeType.historical && historicalResolution == TemporalResolution.daily) {
    return ref.watch(fullHistoricalDailyFieldsProvider);
  }
  return ref.watch(fullFieldRegistryProvider)[mode] ?? [];
});

/// True once the master START/END window exceeds one year. Past this,
/// hourly requests get enormous (chart lag, and for Historical, past the
/// Archive API's realistic per-request volume) -- so callers should hide
/// the HOURLY option entirely and force daily regardless of what the
/// toggle was last set to.
bool isLongRange(DateTime start, DateTime end) => end.difference(start).inDays.abs() > 365;

// ---------------------------------------------------------------------------
// App state: location / mode / range (incl. custom window) / user-added
// fields, URL-synced.
// ---------------------------------------------------------------------------
class AppState {
  final LocationParams? location;
  final ModeType mode;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final Map<ModeType, List<String>> extraFields;
  final TemporalResolution weatherResolution;
  final TemporalResolution historicalResolution;

  AppState({
    this.location,
    this.mode = ModeType.weather,
    DateTime? rangeStart,
    DateTime? rangeEnd,
    this.extraFields = const {},
    this.weatherResolution = TemporalResolution.hourly,
    this.historicalResolution = TemporalResolution.daily,
  })  : rangeStart = rangeStart ?? DateTime.now().subtract(const Duration(days: 30)),
        rangeEnd = rangeEnd ?? DateTime.now().add(const Duration(days: 14));

  AppState copyWith({
    LocationParams? location,
    ModeType? mode,
    DateTime? rangeStart,
    DateTime? rangeEnd,
    Map<ModeType, List<String>>? extraFields,
    TemporalResolution? weatherResolution,
    TemporalResolution? historicalResolution,
  }) =>
      AppState(
        location: location ?? this.location,
        mode: mode ?? this.mode,
        rangeStart: rangeStart ?? this.rangeStart,
        rangeEnd: rangeEnd ?? this.rangeEnd,
        extraFields: extraFields ?? this.extraFields,
        weatherResolution: weatherResolution ?? this.weatherResolution,
        historicalResolution: historicalResolution ?? this.historicalResolution,
      );
}

class AppStateNotifier extends Notifier<AppState> {
  @override
  AppState build() => AppState();

  void syncFromUri(Uri uri) {
    final q = uri.queryParameters;
    if (q['lat'] == null || q['lon'] == null) return;
    state = AppState(
      location: LocationParams(name: q['location'] ?? 'Unknown', lat: double.parse(q['lat']!), lon: double.parse(q['lon']!)),
      mode: ModeType.values.firstWhere((m) => m.name == q['mode'] && m.hasTimeSeries, orElse: () => ModeType.weather),
      rangeStart: q['start'] != null ? DateTime.tryParse(q['start']!) : null,
      rangeEnd: q['end'] != null ? DateTime.tryParse(q['end']!) : null,
      extraFields: state.extraFields,
      weatherResolution: TemporalResolution.values.firstWhere((r) => r.name == q['wres'], orElse: () => TemporalResolution.hourly),
      historicalResolution: TemporalResolution.values.firstWhere((r) => r.name == q['hres'], orElse: () => TemporalResolution.daily),
    );
    if (q['units'] == 'imperial') {
      ref.read(unitSystemProvider.notifier).state = UnitSystem.imperial;
    }
  }

  void _pushToUrl(GoRouter router, {String path = '/explore'}) {
    if (state.location == null) return;
    final units = ref.read(unitSettingsProvider);
    final params = {
      ...state.location!.toQuery(),
      'mode': state.mode.name,
      'start': state.rangeStart.toIso8601String(),
      'end': state.rangeEnd.toIso8601String(),
      'units': units.key,
      'wres': state.weatherResolution.name,
      'hres': state.historicalResolution.name,
    };
    final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    router.go('$path?$query');
  }

  /// Navigates to the dedicated raw-data page, keeping the same
  /// location/mode/range/units context as the dashboard.
  void goToDataTable(GoRouter router) => _pushToUrl(router, path: '/explore/data');

  /// Back from the data page to the dashboard, same context preserved.
  void goToDashboard(GoRouter router) => _pushToUrl(router, path: '/explore');

  void setLocation(LocationParams loc, GoRouter router) {
    state = state.copyWith(location: loc);
    _pushToUrl(router);
  }

  void setMode(ModeType mode, GoRouter router) {
    state = state.copyWith(mode: mode);
    _pushToUrl(router);
  }

  /// User edited the START field in the app-bar date range. Guards against
  /// the range inverting if they pick a start after the current end.
  void setRangeStart(DateTime start, GoRouter router) {
    final end = start.isAfter(state.rangeEnd) ? start : state.rangeEnd;
    state = state.copyWith(rangeStart: start, rangeEnd: end);
    _pushToUrl(router);
  }

  /// User edited the END field. Same invert-guard as setRangeStart.
  void setRangeEnd(DateTime end, GoRouter router) {
    final start = end.isBefore(state.rangeStart) ? end : state.rangeStart;
    state = state.copyWith(rangeStart: start, rangeEnd: end);
    _pushToUrl(router);
  }

  void setUnits(UnitSystem system, GoRouter router) {
    ref.read(unitSystemProvider.notifier).state = system;
    _pushToUrl(router);
  }

  void setWeatherResolution(TemporalResolution res, GoRouter router) {
    state = state.copyWith(weatherResolution: res);
    _pushToUrl(router);
  }

  /// Defaults to daily (see AppState) -- this, plus the HistoricalDaily
  /// registry above, is what fixes Historical mode. Hourly is now an
  /// explicit opt-in via the mode's own HOURLY/DAILY toggle.
  void setHistoricalResolution(TemporalResolution res, GoRouter router) {
    state = state.copyWith(historicalResolution: res);
    _pushToUrl(router);
  }

  void addField(ModeType mode, String fieldKey) => addFields(mode, [fieldKey]);

  /// Adds a batch of extended (secondary-tier) field keys in one go -- this
  /// is what the "SELECT METRICS" picker calls once the user confirms their
  /// choices, so exactly one refetch happens for the whole selection instead
  /// of one per field.
  void addFields(ModeType mode, List<String> fieldKeys) {
    final current = List<String>.from(state.extraFields[mode] ?? []);
    for (final k in fieldKeys) {
      if (!current.contains(k)) current.add(k);
    }
    state = state.copyWith(extraFields: {...state.extraFields, mode: current});
  }
}

final appStateProvider = NotifierProvider<AppStateNotifier, AppState>(AppStateNotifier.new);

// Active fields = PRIMARY tier defaults only + whatever the user explicitly
// added for that mode via the extended-metrics picker. Secondary fields are
// never fetched until the user asks for them -- this is the whole point of
// the lazy-load requirement: main widgets load immediately, extended
// widgets load only on demand.
final activeFieldsProvider = Provider.family<List<FieldSpec>, ModeType>((ref, mode) {
  final extraKeys = ref.watch(appStateProvider).extraFields[mode] ?? [];
  final full = ref.watch(resolvedFullFieldsProvider(mode));
  final defaults = full.where((f) => f.tier == FieldTier.primary).toList();
  final extras = full.where((f) => extraKeys.contains(f.jsonKey) && !defaults.any((d) => d.jsonKey == f.jsonKey));
  return [...defaults, ...extras];
});

// ---------------------------------------------------------------------------
// Data fetching: ONE family provider, dispatches by mode to the correct real
// open_meteo API class + its verified enum set. keepAlive() means switching
// tabs/locations never refetches identical (location, mode, range, fields,
// units) combinations -- this IS the "fetch once per tab landing" behavior.
// fieldKeys only ever contains primary + explicitly user-picked secondary
// fields (see activeFieldsProvider), so this call never over-fetches.
// ---------------------------------------------------------------------------
final dataProvider = FutureProvider.family<Map<String, dynamic>, FetchParams>((ref, params) async {
  ref.keepAlive();
  final units = ref.watch(unitSettingsProvider);
  final lat = params.location.lat;
  final lon = params.location.lon;
  final now = DateTime.now();
  final start = params.rangeStart;
  final end = params.rangeEnd;

  // How far into the past/future the master START/END fields reach, for the
  // "recent past + forecast horizon" style modes (Weather/Marine/AirQuality/
  // Ensemble/Flood) that take pastDays/forecastDays rather than an explicit
  // date window.
  int pastDaysFrom(DateTime s) => s.isBefore(now) ? now.difference(s).inDays : 0;
  int forecastDaysTo(DateTime e) => e.isAfter(now) ? e.difference(now).inDays : 0;

  switch (params.mode) {
    case ModeType.weather:
      final api = WeatherApi(temperatureUnit: units.temperature, windspeedUnit: units.windspeed, precipitationUnit: units.precipitation);
      final locations = {OpenMeteoLocation(latitude: lat, longitude: lon)};
      // ForecastStrip needs daily (weather_code/hi/lo) for its day cards and
      // hourly (weather_code/temp) for the inline per-day expand, regardless
      // of which resolution the HOURLY/DAILY toggle currently shows in the
      // metric panels below -- so both are always requested together in the
      // same call rather than switching between them.
      final daily = params.resolution == TemporalResolution.daily
          ? params.fieldKeys.map((k) => WeatherDaily.values.firstWhere((v) => v.name == k)).toSet()
          : {WeatherDaily.weather_code, WeatherDaily.temperature_2m_max, WeatherDaily.temperature_2m_min};
      final hourly = params.resolution == TemporalResolution.hourly
          ? params.fieldKeys.map((k) => WeatherHourly.values.firstWhere((v) => v.name == k)).toSet()
          : {WeatherHourly.weather_code, WeatherHourly.temperature_2m, WeatherHourly.precipitation_probability};
      return api.requestJson(
        locations: locations,
        daily: daily,
        hourly: hourly,
        pastDays: pastDaysFrom(start).clamp(0, 92),
        forecastDays: forecastDaysTo(end).clamp(0, 16),
      );
    case ModeType.historical:
      // Archive API is past-only, and defaults to DAILY resolution (see
      // AppState.historicalResolution) -- hourly is an explicit opt-in via
      // the HOURLY/DAILY toggle above the panels.
      final api = HistoricalApi(temperatureUnit: units.temperature, windspeedUnit: units.windspeed, precipitationUnit: units.precipitation);
      final histEnd = end.isAfter(now) ? now : end;
      final histStart = start.isAfter(histEnd) ? histEnd : start;
      final locations = {OpenMeteoLocation(latitude: lat, longitude: lon, startDate: histStart, endDate: histEnd)};
      if (params.resolution == TemporalResolution.daily) {
        final daily = params.fieldKeys.map((k) => HistoricalDaily.values.firstWhere((v) => v.name == k)).toSet();
        return api.requestJson(locations: locations, daily: daily);
      }
      final hourly = params.fieldKeys.map((k) => HistoricalHourly.values.firstWhere((v) => v.name == k)).toSet();
      return api.requestJson(locations: locations, hourly: hourly);
    case ModeType.climate:
      // ClimateApi requires a model set at construction (not per-request).
      // Range here is a FUTURE window (climate projections), not a past one.
      final api = ClimateApi(models: {OpenMeteoModel.MRI_AGCM3_2_S}, temperatureUnit: units.temperature, windspeedUnit: units.windspeed, precipitationUnit: units.precipitation);
      final daily = params.fieldKeys.map((k) => ClimateDaily.values.firstWhere((v) => v.name == k)).toSet();
      final climStart = start.isBefore(now) ? now : start;
      final climEnd = end.isBefore(climStart) ? climStart : end;
      final locations = {OpenMeteoLocation(latitude: lat, longitude: lon, startDate: climStart, endDate: climEnd)};
      return api.requestJson(locations: locations, daily: daily);
    case ModeType.marine:
      final api = MarineApi();
      final hourly = params.fieldKeys.map((k) => MarineHourly.values.firstWhere((v) => v.name == k)).toSet();
      return api.requestJson(locations: {OpenMeteoLocation(latitude: lat, longitude: lon)}, hourly: hourly, pastDays: pastDaysFrom(start).clamp(0, 92));
    case ModeType.airQuality:
      final api = AirQualityApi();
      final hourly = params.fieldKeys.map((k) => AirQualityHourly.values.firstWhere((v) => v.name == k)).toSet();
      return api.requestJson(locations: {OpenMeteoLocation(latitude: lat, longitude: lon)}, hourly: hourly, pastDays: pastDaysFrom(start).clamp(0, 92));
    case ModeType.flood:
      // ensemble:true is what makes river_discharge_mean/min/max/p25/p75
      // meaningful -- without it those aggregation fields are degenerate
      // (a single deterministic run has no spread to aggregate).
      final api = FloodApi(ensemble: true);
      final daily = params.fieldKeys.map((k) => FloodDaily.values.firstWhere((v) => v.name == k)).toSet();
      return api.requestJson(locations: {OpenMeteoLocation(latitude: lat, longitude: lon)}, daily: daily, pastDays: pastDaysFrom(start).clamp(0, 366));
    case ModeType.ensemble:
      // EnsembleApi also requires a model set at construction.
      final api = EnsembleApi(models: {OpenMeteoModel.icon_seamless}, temperatureUnit: units.temperature, windspeedUnit: units.windspeed, precipitationUnit: units.precipitation);
      final hourly = params.fieldKeys.map((k) => EnsembleHourly.values.firstWhere((v) => v.name == k)).toSet();
      return api.requestJson(locations: {OpenMeteoLocation(latitude: lat, longitude: lon)}, hourly: hourly, pastDays: pastDaysFrom(start).clamp(0, 92));
    case ModeType.elevation:
    case ModeType.geocoding:
      return {};
  }
});

// Elevation lookup for the dashboard header. requestJson()-only per docs.
final locationMetaProvider = FutureProvider.family<Map<String, dynamic>, LocationParams>((ref, loc) async {
  ref.keepAlive();
  final elevationApi = ElevationApi();
  final elevation = await elevationApi.requestJson(latitudes: {loc.lat}, longitudes: {loc.lon});
  return {'elevation': elevation};
});

// Forward geocoding search for the landing-page autocomplete.
final geocodingSearchProvider = FutureProvider.family<List<LocationParams>, String>((ref, query) async {
  if (query.trim().length < 2) return [];
  final api = GeocodingApi();
  final res = await api.requestJson(name: query, count: 8);
  final results = (res['results'] as List?) ?? [];
  return results
      .map((r) => LocationParams(name: r['name'] ?? query, lat: (r['latitude'] as num).toDouble(), lon: (r['longitude'] as num).toDouble()))
      .toList();
});

// ---------------------------------------------------------------------------
// Router: URL is the single source of truth.
// ---------------------------------------------------------------------------
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => LandingScreen()),
      GoRoute(
        path: '/explore',
        builder: (context, state) {
          // syncFromUri mutates appStateProvider's state. Calling it directly
          // here runs it mid-build (GoRouter builds this during Flutter's
          // build phase), which Riverpod forbids. Defer it a microtask so it
          // runs right after the current build finishes.
          Future.microtask(() => ref.read(appStateProvider.notifier).syncFromUri(state.uri));
          return DashboardScreen();
        },
      ),
      GoRoute(
        path: '/explore/data',
        builder: (context, state) {
          Future.microtask(() => ref.read(appStateProvider.notifier).syncFromUri(state.uri));
          return const DataTableScreen();
        },
      ),
    ],
  );
});