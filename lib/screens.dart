// lib/screens.dart
//
// Three screens: LandingScreen (full-screen map + autocomplete search),
// DashboardScreen (branded AppBar + TabBar + 9-mode IndexedStack), and the
// mode-agnostic raw-data dialog (folded into _ModeGrid rather than a
// separate route, per prior direction) -- plus an inline split-screen raw
// data panel toggleable from the app bar.

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'dart:js_interop';
import 'package:csv/csv.dart';
import 'package:web/web.dart' as web;
import 'models.dart';
import 'providers.dart';
import 'widgets.dart';
import 'theme.dart' as theme;
import 'forecast_widgets.dart';
import 'heatmap_widget.dart';
import 'fan_chart_widget.dart';
import 'range_selector.dart';
import 'wave_rose_widget.dart';
import 'aqi_gauge_widget.dart';

const _appTitle = 'STRATUM';
const _appSubtitle = 'OPEN CLIMATIC INTELLIGENCE';

/// Readable timestamp for table rows -- "2026-03-14 09:00" instead of the
/// raw ISO-8601 "2026-03-14T09:00:00.000Z" the T/Z separators produce.
/// Values from the API are already UTC-normalized (see the various
/// fromMillisecondsSinceEpoch(..., isUtc: true) calls below), so this just
/// swaps the separator and drops the seconds/millis/zone suffix rather than
/// converting timezones.
String _formatTableTime(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final mo = d.month.toString().padLeft(2, '0');
  final da = d.day.toString().padLeft(2, '0');
  final h = d.hour.toString().padLeft(2, '0');
  final mi = d.minute.toString().padLeft(2, '0');
  return '$y-$mo-$da $h:$mi';
}

/// The tabbed modes shown in the dashboard. Elevation and Location (the two
/// single-value metadata lookups, formerly shown as a "meta" tab that just
/// pointed back at the header) are dropped entirely -- their data already
/// lives in the location header above, so a whole tab for them added
/// nothing.
const _tabModes = <ModeType>[
  ModeType.weather,
  ModeType.historical,
  ModeType.climate,
  ModeType.marine,
  ModeType.airQuality,
  ModeType.flood,
  ModeType.ensemble,
];

// ---------------------------------------------------------------------------
// LandingScreen: full-bleed map is the entire canvas. Search lives in a
// full-width bar with a proper autocomplete dropdown underneath it; tapping
// a result (or the map itself) drops a pin and pushes into the dashboard
// for that location. The search bar pulses gently until the person starts
// typing or picks a location, so it's obvious that's where to start.
// ---------------------------------------------------------------------------

class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({super.key});
  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen> with SingleTickerProviderStateMixin {
  final controller = TextEditingController();
  final focusNode = FocusNode();
  final mapController = MapController();
  LatLng? marker;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    // Draws the eye to the search bar on first load -- stops (settles to
    // its resting state) the moment the person starts typing or picks a
    // location, via `drawAttention` in build() below.
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  }

  void _select(LocationParams loc) {
    setState(() {
      marker = LatLng(loc.lat, loc.lon);
      controller.text = loc.name;
    });
    focusNode.unfocus();
    try {
      mapController.move(LatLng(loc.lat, loc.lon), 9);
    } catch (_) {
      // Map may not be laid out yet on the very first frame; harmless.
    }
    ref.read(appStateProvider.notifier).setLocation(loc, ref.read(routerProvider));
  }

  @override
  void dispose() {
    _pulse.dispose();
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = controller.text.trim();
    final showDropdown = query.length >= 2;
    final results = showDropdown ? ref.watch(geocodingSearchProvider(query)) : null;
    final drawAttention = marker == null && controller.text.isEmpty;

    return Scaffold(
      backgroundColor: theme.AppColors.bg,
      body: Stack(
        children: [
          // Full-screen map.
          Positioned.fill(
            child: FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: const LatLng(20, 0),
                initialZoom: 2.2,
                onTap: (tapPosition, point) => _select(LocationParams(
                  name: 'Lat ${point.latitude.toStringAsFixed(2)}, Lon ${point.longitude.toStringAsFixed(2)}',
                  lat: point.latitude,
                  lon: point.longitude,
                )),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  tileBuilder: (context, tileWidget, tile) => ColorFiltered(
                    // Dim/darken the base OSM tiles so they sit inside the
                    // Bloomberg-terminal palette instead of looking like a
                    // stock web map dropped on top of it.
                    colorFilter: const ColorFilter.matrix(<double>[
                      0.55, 0, 0, 0, 0,
                      0, 0.55, 0, 0, 0,
                      0, 0, 0.55, 0, 0,
                      0, 0, 0, 1, 0,
                    ]),
                    child: tileWidget,
                  ),
                ),
                if (marker != null)
                  MarkerLayer(markers: [
                    Marker(
                      point: marker!,
                      width: 40,
                      height: 40,
                      child: Icon(Icons.location_on, color: theme.AppColors.amber, size: 40, shadows: const [Shadow(color: Colors.black, blurRadius: 6)]),
                    ),
                  ]),
              ],
            ),
          ),
          // Subtle top gradient so overlaid text/controls stay legible over
          // any tile.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 160,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [theme.AppColors.bg.withOpacity(0.85), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          // Branding, top-left.
          Positioned(
            top: 20,
            left: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_appTitle, style: theme.monoStyle.copyWith(fontSize: 24, color: theme.AppColors.amber, letterSpacing: 5, fontWeight: FontWeight.bold)),
                Text(_appSubtitle, style: theme.monoStyle.copyWith(fontSize: 10, color: theme.AppColors.grey, letterSpacing: 3)),
              ],
            ),
          ),
          // Full-width search bar + autocomplete dropdown, below the brand.
          Positioned(
            top: 76,
            left: 24,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) {
                    final t = drawAttention ? _pulse.value : 0.0;
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: theme.AppColors.amber.withOpacity(0.05 + t * 0.35),
                            blurRadius: 8 + t * 20,
                            spreadRadius: t * 3,
                          ),
                        ],
                      ),
                      child: child,
                    );
                  },
                  child: Material(
                    color: theme.AppColors.panel.withOpacity(0.96),
                    borderRadius: BorderRadius.circular(10),
                    elevation: 10,
                    shadowColor: Colors.black54,
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: (_) => setState(() {}),
                      style: theme.monoStyle.copyWith(color: theme.AppColors.white, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Search any location on Earth...',
                        hintStyle: theme.monoStyle.copyWith(color: theme.AppColors.grey, fontSize: 14),
                        prefixIcon: Icon(Icons.search, color: theme.AppColors.grey, size: 22),
                        suffixIcon: controller.text.isEmpty
                            ? null
                            : IconButton(
                                icon: Icon(Icons.clear, color: theme.AppColors.grey, size: 18),
                                onPressed: () => setState(() => controller.clear()),
                              ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                        filled: true,
                        fillColor: Colors.transparent,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.AppColors.border)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: drawAttention ? Color.lerp(theme.AppColors.border, theme.AppColors.amber, _pulse.value)! : theme.AppColors.border, width: drawAttention ? 1.4 : 1),
                        ),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.AppColors.amber)),
                      ),
                    ),
                  ),
                ),
                if (showDropdown)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(maxHeight: 340),
                    decoration: BoxDecoration(
                      color: theme.AppColors.panel.withOpacity(0.98),
                      border: Border.all(color: theme.AppColors.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: results!.when(
                      data: (list) => list.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text('NO RESULTS', style: theme.monoStyle.copyWith(color: theme.AppColors.grey, fontSize: 12)),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              itemCount: list.length,
                              separatorBuilder: (_, __) => Divider(height: 1, color: theme.AppColors.border),
                              itemBuilder: (context, i) {
                                final loc = list[i];
                                return ListTile(
                                  dense: true,
                                  leading: Icon(Icons.place_outlined, color: theme.AppColors.amber, size: 18),
                                  title: Text(loc.name, style: theme.monoStyle.copyWith(color: theme.AppColors.white, fontSize: 13)),
                                  subtitle: Text('${loc.lat.toStringAsFixed(3)}, ${loc.lon.toStringAsFixed(3)}', style: theme.monoStyle.copyWith(color: theme.AppColors.grey, fontSize: 10)),
                                  onTap: () => _select(loc),
                                );
                              },
                            ),
                      loading: () => const Padding(
                        padding: EdgeInsets.all(18),
                        child: Center(child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))),
                      ),
                      error: (error, stack) {
                        // Keep the full exception in the browser/device logs
                        // and expose it in the dropdown while diagnosing
                        // Safari/iPad-specific geocoding failures.
                        debugPrint('Geocoding search failed: $error');
                        debugPrintStack(stackTrace: stack);

                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: SelectableText(
                            'SEARCH FAILED\n$error',
                            style: theme.monoStyle.copyWith(
                              color: theme.AppColors.red,
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          // Hint footer -- full width, bigger, and now explicitly points
          // back up at the search bar as the other way in.
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: IgnorePointer(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.AppColors.panel.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.AppColors.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TAP ANYWHERE ON THE MAP TO EXPLORE THAT LOCATION',
                      textAlign: TextAlign.center,
                      style: theme.monoStyle.copyWith(color: theme.AppColors.white, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'OR SEARCH FOR A LOCATION USING THE BOX AT THE TOP',
                      textAlign: TextAlign.center,
                      style: theme.monoStyle.copyWith(color: theme.AppColors.grey, fontSize: 11, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DashboardScreen: branded AppBar ("STRATUM - OPEN CLIMATIC INTELLIGENCE")
// with location/lat-lon/elevation and the CHANGE LOCATION / unit-system
// controls now living IN the app bar itself, plus a Material TabBar for the
// 9 modes. Body is graph-view only by default; toggling the data-table icon
// in the app bar splits it side-by-side with a live raw data table for the
// current mode. Body keeps the IndexedStack (not TabBarView) so each mode's
// keepAlive'd dataProvider is never rebuilt just because the user switched
// tabs and back.
// ---------------------------------------------------------------------------

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  /// Only tabs the user has actually visited get a real _ModeView (and
  /// therefore a live dataProvider watch). Previously every mode's
  /// _ModeView was built on every IndexedStack rebuild regardless of which
  /// tab was showing, so changing the date range fired all 7 modes' API
  /// calls at once -- this, plus dataProvider's existing keepAlive cache,
  /// is what makes a revisit instant instead of a reload.
  final Set<int> _builtTabs = {};

  /// Split-screen toggle: graphs alongside a live raw data table for
  /// whichever mode is currently selected, reusing the SAME dataProvider
  /// call the graph grid already makes (identical FetchParams => cache hit,
  /// not a second fetch). Defaults to visible -- the table icon in the app
  /// bar just hides/shows it rather than being the only way to see it.
  bool _splitDataTable = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabModes.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      final mode = _tabModes[_tabController.index];
      if (mode != ref.read(appStateProvider).mode) {
        ref.read(appStateProvider.notifier).setMode(mode, ref.read(routerProvider));
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final router = ref.watch(routerProvider);
    final unitSystem = ref.watch(unitSystemProvider);
    if (appState.location == null) return const LandingScreen();

    var currentIndex = _tabModes.indexOf(appState.mode);
    if (currentIndex < 0) currentIndex = 0;
    _builtTabs.add(currentIndex);
    if (_tabController.index != currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tabController.index = currentIndex;
      });
    }

    return Scaffold(
      backgroundColor: theme.AppColors.bg,
      appBar: AppBar(
        backgroundColor: theme.AppColors.panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 20,
        toolbarHeight: 68,
        title: _AppBarLocationInfo(location: appState.location!),
        actions: [
          DateRangeBar(
            start: appState.rangeStart,
            end: appState.rangeEnd,
            onStartChanged: (d) => ref.read(appStateProvider.notifier).setRangeStart(d, router),
            onEndChanged: (d) => ref.read(appStateProvider.notifier).setRangeEnd(d, router),
          ),
          const SizedBox(width: 12),
          UnitToggle(active: unitSystem, onChanged: (s) => ref.read(appStateProvider.notifier).setUnits(s, router)),
          const SizedBox(width: 12),
          IconButton(
            tooltip: _splitDataTable ? 'Hide raw data table' : 'Show raw data table',
            icon: Icon(Icons.table_chart_outlined, color: _splitDataTable ? theme.AppColors.amber : theme.AppColors.grey),
            onPressed: () => setState(() => _splitDataTable = !_splitDataTable),
          ),
          const SizedBox(width: 16),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            isScrollable: false,
            indicatorColor: theme.AppColors.amber,
            indicatorWeight: 2,
            labelColor: theme.AppColors.amber,
            unselectedLabelColor: theme.AppColors.grey,
            labelStyle: theme.monoStyle.copyWith(fontSize: 12, letterSpacing: 0.5),
            tabs: [for (final mode in _tabModes) Tab(text: mode.label.toUpperCase())],
          ),
        ),
      ),
      // Body is graph view only by default. Toggling the data-table icon
      // above splits it side-by-side with a live raw data table for the
      // currently selected mode.
      body: Row(
        children: [
          Expanded(
            flex: _splitDataTable ? 3 : 1,
            child: IndexedStack(
              index: currentIndex,
              children: [for (var i = 0; i < _tabModes.length; i++) _builtTabs.contains(i) ? _ModeView(mode: _tabModes[i]) : const SizedBox.shrink()],
            ),
          ),
          if (_splitDataTable) Container(width: 1, color: theme.AppColors.border),
          if (_splitDataTable) Expanded(flex: 2, child: _RawDataTableView(mode: appState.mode)),
        ],
      ),
    );
  }
}

/// Compact location readout for the app bar: name + lat/lon + elevation.
/// Elevation comes from the same keepAlive'd locationMetaProvider the old
/// body-level header used, just relocated.
class _AppBarLocationInfo extends ConsumerWidget {
  final LocationParams location;
  const _AppBarLocationInfo({required this.location});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = ref.watch(locationMetaProvider(location));
    final router = ref.watch(routerProvider);
    final elevation = meta.maybeWhen(
      data: (d) {
        final results = (d['elevation']?['elevation'] as List?);
        return results != null && results.isNotEmpty ? '${results.first} m' : '--';
      },
      orElse: () => '--',
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            location.name.toUpperCase(),
            style: monoStyle.copyWith(fontSize: 22, color: theme.AppColors.amber, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 24),
        Text('LAT ${location.lat.toStringAsFixed(4)}  LON ${location.lon.toStringAsFixed(4)}  ELEV $elevation', style: monoStyle.copyWith(fontSize: 16, color: theme.AppColors.grey)),
        const SizedBox(width: 24),
        OutlinedButton.icon(
          onPressed: () => router.go('/'),
          icon: const Icon(Icons.edit_location_alt_outlined, size: 16, color: theme.AppColors.amber),
          label: Text('CHANGE LOCATION', style: monoStyle.copyWith(color: theme.AppColors.amber, fontSize: 11)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: theme.AppColors.border)),
        ),
      ],
    );
  }
}

/// Fetches ONLY when this mode's IndexedStack child first paints, then
/// stays cached (ref.keepAlive() lives in dataProvider itself).
class _ModeView extends ConsumerWidget {
  final ModeType mode;
  const _ModeView({required this.mode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final router = ref.watch(routerProvider);
    if (appState.location == null) return const SizedBox.shrink();
    final units = ref.watch(unitSettingsProvider);
    final fields = ref.watch(activeFieldsProvider(mode));
    final longRange = isLongRange(appState.rangeStart, appState.rangeEnd);
    final rawResolution = mode == ModeType.weather
        ? appState.weatherResolution
        : mode == ModeType.historical
            ? appState.historicalResolution
            : TemporalResolution.hourly;
    // Past a 1-year window, hourly is off the table entirely -- forced to
    // daily regardless of what the toggle was last set to, which is what
    // actually keeps a 5-10Y Historical/Weather range from trying to pull
    // (and then render) tens of thousands of hourly rows per field.
    final resolution = longRange ? TemporalResolution.daily : rawResolution;
    final params = FetchParams(
      mode: mode,
      location: appState.location!,
      rangeStart: appState.rangeStart,
      rangeEnd: appState.rangeEnd,
      fieldKeys: [for (final f in fields) f.jsonKey],
      unitsKey: units.key,
      resolution: resolution,
    );
    final asyncData = ref.watch(dataProvider(params));

    return Column(
      children: [
        if (mode.hasResolutionToggle)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: longRange
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(border: Border.all(color: theme.AppColors.border), borderRadius: BorderRadius.circular(4)),
                    child: Text('DAILY ONLY — RANGE EXCEEDS 1 YEAR', style: monoStyle.copyWith(fontSize: 11, color: theme.AppColors.grey, letterSpacing: 0.5)),
                  )
                : SegmentedButton<TemporalResolution>(
                    segments: const [
                      ButtonSegment(value: TemporalResolution.hourly, label: Text('HOURLY')),
                      ButtonSegment(value: TemporalResolution.daily, label: Text('DAILY')),
                    ],
                    selected: {resolution},
                    onSelectionChanged: (s) => mode == ModeType.weather
                        ? ref.read(appStateProvider.notifier).setWeatherResolution(s.first, router)
                        : ref.read(appStateProvider.notifier).setHistoricalResolution(s.first, router),
                    style: ButtonStyle(
                      textStyle: WidgetStateProperty.all(monoStyle.copyWith(fontSize: 11)),
                      foregroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? theme.AppColors.bg : theme.AppColors.grey),
                      backgroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? theme.AppColors.amber : theme.AppColors.panel),
                      side: WidgetStateProperty.all(BorderSide(color: theme.AppColors.border)),
                    ),
                  ),
          ),
        Expanded(
          child: asyncData.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e', style: monoStyle.copyWith(color: theme.AppColors.red))),
            data: (data) => _ModeGrid(mode: mode, fields: fields, data: data, units: units, resolution: resolution, longRange: longRange),
          ),
        ),
      ],
    );
  }
}

// Charts get choppy well before fl_chart falls over -- cap every series at
// this many points. _strideKeep always keeps the LAST point exactly (so
// "current value" readouts stay accurate) even though earlier points are
// thinned by a fixed stride.
const _maxSeriesPoints = 1200;
int _strideFor(int length) => length <= _maxSeriesPoints ? 1 : (length / _maxSeriesPoints).ceil();
List<T> _strideKeep<T>(List<T> list, int stride) {
  if (stride <= 1 || list.isEmpty) return list;
  final out = [for (var i = 0; i < list.length; i += stride) list[i]];
  if (out.last != list.last) out.add(list.last);
  return out;
}

/// One row's worth of data for _DynamicGrid: whether it actually has data
/// (small "not available" rectangle if not) plus a lazy builder so panels
/// with no data never construct their (often chart-heavy) widget at all.
class _GridItem {
  final String label;
  final bool hasData;
  final Widget Function() builder;
  const _GridItem({required this.label, required this.hasData, required this.builder});
}

/// Wraps any chart/panel so tapping it opens the SAME chart full-screen.
/// `builder` (not a pre-built widget) is stored and re-invoked for the
/// full-screen route -- the grid's own copy stays mounted underneath
/// (IndexedStack keeps the mode alive) while a fresh instance renders large
/// in the pushed route.
class _FullscreenableChart extends StatelessWidget {
  final String label;
  final Widget Function() builder;
  const _FullscreenableChart({required this.label, required this.builder});

  void _open(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => Scaffold(
        backgroundColor: theme.AppColors.bg,
        appBar: AppBar(
          backgroundColor: theme.AppColors.panel,
          elevation: 0,
          title: Text(label.toUpperCase(), style: theme.monoStyle.copyWith(color: theme.AppColors.amber, fontSize: 13, letterSpacing: 1)),
          leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
        ),
        body: Padding(padding: const EdgeInsets.all(20), child: SizedBox.expand(child: builder())),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _open(context),
        // builder() is a non-positioned child, so Stack sizes itself off
        // the chart's own natural/bounded size -- this works whether the
        // caller wrapped it in a fixed-height SizedBox (grid panels) or
        // left it to size itself intrinsically (the calendar heatmap).
        child: Stack(
          children: [
            builder(),
            Positioned(
              top: 6,
              right: 6,
              child: IgnorePointer(
                child: Icon(Icons.fullscreen, size: 16, color: theme.AppColors.greyDim),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeGrid extends ConsumerWidget {
  final ModeType mode;
  final List<FieldSpec> fields;
  final Map<String, dynamic> data;
  final UnitSettings units;
  final TemporalResolution resolution;
  final bool longRange;
  const _ModeGrid({required this.mode, required this.fields, required this.data, required this.units, required this.resolution, required this.longRange});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Weather always requests a small hourly fallback set (for
    // ForecastStrip's per-day expand) ALONGSIDE whatever daily/hourly set
    // the toggle actually asked for -- so `data['hourly']` is never null
    // even in DAILY mode. Picking hourly-first here was the daily-weather
    // bug: every panel went looking for e.g. `temperature_2m_max` inside
    // the hourly map (which only has weather_code/temperature_2m/
    // precipitation_probability) and came up empty. Only weather needs this
    // branch -- every other mode's API response only ever contains the one
    // resolution it actually requested.
    final series = mode == ModeType.weather
        ? ((resolution == TemporalResolution.daily ? data['daily'] : data['hourly']) as Map<String, dynamic>?) ?? {}
        : (data['hourly'] as Map<String, dynamic>?) ?? (data['daily'] as Map<String, dynamic>?) ?? {};

    List<num> validValues(String jsonKey) {
      final raw = (series[jsonKey] as List?)?.cast<num?>() ?? [];
      final filtered = [for (final v in raw) if (v != null) v];
      return _strideKeep(filtered, _strideFor(filtered.length));
    }

    // Two series must be filtered TOGETHER when they're paired (e.g. wave
    // height + direction for the rose) -- filtering each independently can
    // desync index i whenever one has a null the other doesn't.
    (List<double>, List<double>) pairedValues(String keyA, String keyB) {
      final a = (series[keyA] as List?) ?? [];
      final b = (series[keyB] as List?) ?? [];
      final outA = <double>[], outB = <double>[];
      for (var i = 0; i < a.length && i < b.length; i++) {
        if (a[i] is num && b[i] is num) {
          outA.add((a[i] as num).toDouble());
          outB.add((b[i] as num).toDouble());
        }
      }
      final stride = _strideFor(outA.length);
      return (_strideKeep(outA, stride), _strideKeep(outB, stride));
    }

    // Dates and values must be filtered TOGETHER -- validValues() alone
    // drops nulls independently of the date list, which would misalign
    // heatmap cells / chart x-axes whenever a field has an internal (not
    // just leading-or-trailing) null.
    (List<DateTime>, List<double>) pairedSeries(String jsonKey) {
      final rawTimes = (series['time'] as List?) ?? [];
      final rawValues = (series[jsonKey] as List?) ?? [];
      final dates = <DateTime>[];
      final values = <double>[];
      for (var i = 0; i < rawTimes.length && i < rawValues.length; i++) {
        final t = rawTimes[i];
        final v = rawValues[i];
        if (t is num && v is num) {
          dates.add(DateTime.fromMillisecondsSinceEpoch(t.toInt() * 1000, isUtc: true));
          values.add(v.toDouble());
        }
      }
      final stride = _strideFor(values.length);
      return (_strideKeep(dates, stride), _strideKeep(values, stride));
    }

    // Calendar heatmap draws one cell per calendar day off a fixed Jan-Dec
    // grid -- it doesn't render more or fewer cells based on how many points
    // it's handed, so the stride-downsampling in pairedSeries() (there to
    // keep line/bar charts fast) buys it nothing and actively hurts it: it
    // was dropping ~2 of every 3 days, leaving gaps in the year rows that
    // read as a false monthly-reset/sawtooth pattern. The heatmap always
    // gets the full, un-thinned series instead.
    (List<DateTime>, List<double>) pairedSeriesFull(String jsonKey) {
      final rawTimes = (series['time'] as List?) ?? [];
      final rawValues = (series[jsonKey] as List?) ?? [];
      final dates = <DateTime>[];
      final values = <double>[];
      for (var i = 0; i < rawTimes.length && i < rawValues.length; i++) {
        final t = rawTimes[i];
        final v = rawValues[i];
        if (t is num && v is num) {
          dates.add(DateTime.fromMillisecondsSinceEpoch(t.toInt() * 1000, isUtc: true));
          values.add(v.toDouble());
        }
      }
      return (dates, values);
    }

    List<DateTime> allDates() {
      final rawTimes = (series['time'] as List?) ?? [];
      return [for (final t in rawTimes) if (t is num) DateTime.fromMillisecondsSinceEpoch(t.toInt() * 1000, isUtc: true)];
    }

    final primary = fields.where((f) => f.tier == FieldTier.primary).toList();
    final secondary = fields.where((f) => f.tier == FieldTier.secondary).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mode == ModeType.weather) ForecastStrip(days: _buildForecast(data), tempUnit: units.key == 'metric' ? '°C' : '°F'),
          if (primary.isNotEmpty && (mode == ModeType.historical || mode == ModeType.climate) && longRange)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Column(
                children: [
                  for (final spec in primary)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Builder(builder: (context) {
                        final (dates, values) = pairedSeriesFull(spec.jsonKey);
                        if (values.isEmpty) return _EmptyRow(label: spec.label);
                        return _FullscreenableChart(
                          label: spec.label,
                          builder: () => CalendarHeatmap(label: spec.label, unit: spec.unitLabel(units), dates: dates, values: values),
                        );
                      }),
                    ),
                ],
              ),
            )
          else if (primary.isNotEmpty && mode == ModeType.ensemble)
            Builder(builder: (context) {
              final rawTimes = allDates();
              final stride = _strideFor(rawTimes.length);
              final times = _strideKeep(rawTimes, stride);
              return _DynamicGrid(items: [
                for (final spec in primary)
                  (() {
                    final members = extractEnsembleMembers(series, spec.jsonKey, stride: stride);
                    return _GridItem(
                      label: spec.label,
                      hasData: members.any((m) => m.isNotEmpty),
                      builder: () => FanChart(label: spec.label, unit: spec.unitLabel(units), members: members, times: times),
                    );
                  })(),
              ]);
            })
          else if (primary.isNotEmpty && mode == ModeType.marine)
            _DynamicGrid(items: [
              for (final spec in primary)
                (() {
                  if (spec.jsonKey == 'wave_height') {
                    final (heights, directions) = pairedValues('wave_height', 'wave_direction');
                    final periods = validValues('wave_period');
                    return _GridItem(
                      label: spec.label,
                      hasData: heights.isNotEmpty,
                      builder: () => WaveRose(
                        label: spec.label,
                        heightUnit: spec.unitLabel(units),
                        heights: heights,
                        directions: directions,
                        currentHeight: heights.isEmpty ? null : heights.last,
                        currentPeriod: periods.isEmpty ? null : periods.last.toDouble(),
                      ),
                    );
                  }
                  final (dates, values) = pairedSeries(spec.jsonKey);
                  return _GridItem(
                    label: spec.label,
                    hasData: values.isNotEmpty,
                    builder: () => MetricPanel(label: spec.label, unit: spec.unitLabel(units), isBar: spec.chart == ChartKind.bar, values: values, times: dates),
                  );
                })(),
            ])
          else if (primary.isNotEmpty && mode == ModeType.airQuality)
            _DynamicGrid(items: [
              for (final spec in primary)
                (() {
                  if (spec.jsonKey == 'us_aqi') {
                    final (aqiDates, aqiValues) = pairedSeries('us_aqi');
                    return _GridItem(
                      label: spec.label,
                      hasData: aqiValues.isNotEmpty,
                      builder: () => AqiGauge(current: aqiValues.isEmpty ? null : aqiValues.last, history: aqiValues, times: aqiDates),
                    );
                  }
                  final (dates, values) = pairedSeries(spec.jsonKey);
                  return _GridItem(
                    label: spec.label,
                    hasData: values.isNotEmpty,
                    builder: () => MetricPanel(label: spec.label, unit: spec.unitLabel(units), isBar: spec.chart == ChartKind.bar, values: values, times: dates),
                  );
                })(),
            ])
          else if (primary.isNotEmpty)
            _DynamicGrid(items: [
              for (final spec in primary)
                (() {
                  final (dates, values) = pairedSeries(spec.jsonKey);
                  return _GridItem(
                    label: spec.label,
                    hasData: values.isNotEmpty,
                    builder: () => MetricPanel(label: spec.label, unit: spec.unitLabel(units), isBar: spec.chart == ChartKind.bar, values: values, times: dates),
                  );
                })(),
            ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(children: [
              Text('EXTENDED METRICS (${secondary.length} LOADED)', style: monoStyle.copyWith(fontSize: 12, color: theme.AppColors.grey, letterSpacing: 1)),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => _pickExtendedMetrics(context, ref, mode, fields),
                icon: Icon(Icons.add_chart, size: 16, color: theme.AppColors.amber),
                label: Text('SELECT METRICS', style: monoStyle.copyWith(color: theme.AppColors.amber, fontSize: 11)),
              ),
            ]),
          ),
          if (secondary.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text('No extended metrics loaded yet -- use SELECT METRICS above to choose which extra series to fetch.', style: monoStyle.copyWith(fontSize: 11, color: theme.AppColors.greyDim)),
            )
          else
            _DynamicGrid(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              items: [
                for (final spec in secondary)
                  (() {
                    final (dates, valid) = pairedSeries(spec.jsonKey);
                    return _GridItem(
                      label: spec.label,
                      hasData: valid.isNotEmpty,
                      builder: () => spec.chart == ChartKind.bar
                          ? StandardBarChart(spec: spec, units: units, values: valid, times: dates)
                          : StandardLineChart(spec: spec, units: units, points: [for (var j = 0; j < valid.length; j++) FlSpot(j.toDouble(), valid[j])], times: dates),
                    );
                  })(),
              ],
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton(
              onPressed: () => ref.read(appStateProvider.notifier).goToDataTable(ref.read(routerProvider)),
              child: const Text('VIEW RAW DATA TABLE (FULL PAGE)'),
            ),
          ),
        ],
      ),
    );
  }

  /// Opens the "which extended metrics do you want?" picker -- nothing is
  /// fetched until the user confirms a selection here, which is the whole
  /// point: main widgets load immediately, extended ones only on request.
  Future<void> _pickExtendedMetrics(BuildContext context, WidgetRef ref, ModeType mode, List<FieldSpec> active) async {
    final full = ref.read(resolvedFullFieldsProvider(mode));
    final available = full.where((f) => f.tier == FieldTier.secondary && !active.any((a) => a.jsonKey == f.jsonKey)).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All available metrics for this mode are already loaded.')));
      return;
    }
    final byCategory = <String, List<FieldSpec>>{};
    for (final f in available) {
      byCategory.putIfAbsent(f.category, () => []).add(f);
    }
    final selected = <String>{};

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: panelColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: theme.AppColors.border)),
          title: Text('SELECT EXTENDED METRICS', style: monoStyle.copyWith(color: theme.AppColors.white, fontSize: 14, letterSpacing: 1)),
          content: SizedBox(
            width: 460,
            height: 460,
            child: ListView(
              children: [
                for (final entry in byCategory.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 2),
                    child: Text(entry.key.toUpperCase(), style: monoStyle.copyWith(color: theme.AppColors.amber, fontSize: 11, letterSpacing: 1)),
                  ),
                  for (final f in entry.value)
                    CheckboxListTile(
                      dense: true,
                      activeColor: theme.AppColors.amber,
                      checkColor: theme.AppColors.bg,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: selected.contains(f.jsonKey),
                      onChanged: (v) => setState(() => v == true ? selected.add(f.jsonKey) : selected.remove(f.jsonKey)),
                      title: Text(f.label, style: monoStyle.copyWith(color: theme.AppColors.white, fontSize: 12)),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('CANCEL', style: monoStyle.copyWith(color: theme.AppColors.grey))),
            TextButton(
              onPressed: selected.isEmpty ? null : () => Navigator.pop(context, true),
              child: Text('LOAD SELECTED (${selected.length})', style: monoStyle.copyWith(color: selected.isEmpty ? theme.AppColors.greyDim : theme.AppColors.amber)),
            ),
          ],
        ),
      ),
    );

    if (result == true && selected.isNotEmpty) {
      ref.read(appStateProvider.notifier).addFields(mode, selected.toList());
    }
  }

  /// Builds day cards (always from `data['daily']`) with their matching
  /// hourly slice (from `data['hourly']`) for the inline expand -- both are
  /// always present in the response now regardless of the HOURLY/DAILY
  /// toggle (see dataProvider's weather branch).
  List<DayForecast> _buildForecast(Map<String, dynamic> data) {
    final daily = (data['daily'] as Map<String, dynamic>?) ?? {};
    final hourly = (data['hourly'] as Map<String, dynamic>?) ?? {};
    final dTimes = (daily['time'] as List?) ?? [];
    final dCode = (daily['weather_code'] as List?) ?? [];
    final dMax = (daily['temperature_2m_max'] as List?) ?? [];
    final dMin = (daily['temperature_2m_min'] as List?) ?? [];
    final hTimes = (hourly['time'] as List?) ?? [];
    final hTemp = (hourly['temperature_2m'] as List?) ?? [];
    final hCode = (hourly['weather_code'] as List?) ?? [];
    final hProb = (hourly['precipitation_probability'] as List?) ?? [];

    final hourlyTimes = [for (final t in hTimes) if (t is num) DateTime.fromMillisecondsSinceEpoch(t.toInt() * 1000, isUtc: true) else null];

    final days = <DayForecast>[];
    for (var i = 0; i < dTimes.length; i++) {
      if (dTimes[i] is! num || i >= dCode.length || i >= dMax.length || i >= dMin.length) continue;
      if (dCode[i] == null || dMax[i] == null || dMin[i] == null) continue;
      final date = DateTime.fromMillisecondsSinceEpoch((dTimes[i] as num).toInt() * 1000, isUtc: true);
      final hours = <HourForecast>[
        for (var j = 0; j < hourlyTimes.length; j++)
          if (hourlyTimes[j] != null &&
              hourlyTimes[j]!.year == date.year &&
              hourlyTimes[j]!.month == date.month &&
              hourlyTimes[j]!.day == date.day &&
              j < hTemp.length &&
              hTemp[j] != null)
            HourForecast(
              time: hourlyTimes[j]!,
              temp: (hTemp[j] as num).toDouble(),
              weatherCode: (j < hCode.length && hCode[j] != null) ? (hCode[j] as num).toInt() : 0,
              precipProbability: (j < hProb.length && hProb[j] != null) ? (hProb[j] as num).toDouble() : null,
            ),
      ];
      days.add(DayForecast(date: date, weatherCode: (dCode[i] as num).toInt(), tempMax: (dMax[i] as num).toDouble(), tempMin: (dMin[i] as num).toDouble(), hours: hours));
    }
    return days;
  }
}

/// Every panel is full-width, one per row, stacked in a single column --
/// this gives every chart the full window width to render its time axis in
/// detail instead of squeezing 2-3 across. Items with no data render as a
/// small fixed-height rectangle (_EmptyRow) instead of a full 420px blank
/// panel, and their (often chart-heavy) widget is never built at all. Every
/// panel with data is tappable -- see _FullscreenableChart -- to open the
/// same chart full-screen.
class _DynamicGrid extends StatelessWidget {
  final List<_GridItem> items;
  final EdgeInsets padding;
  const _DynamicGrid({required this.items, this.padding = const EdgeInsets.all(12)});

  static const double _rowHeight = 420;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 12),
              child: items[i].hasData
                  ? SizedBox(
                      height: _rowHeight,
                      width: double.infinity,
                      child: RepaintBoundary(
                        child: _FullscreenableChart(label: items[i].label, builder: items[i].builder),
                      ),
                    )
                  : _EmptyRow(label: items[i].label),
            ),
        ],
      ),
    );
  }
}

/// Compact "not available" placeholder for a metric with no data in the
/// current window -- takes one line of vertical space instead of a full
/// panel's worth.
class _EmptyRow extends StatelessWidget {
  final String label;
  const _EmptyRow({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(color: theme.AppColors.panel, border: Border.all(color: theme.AppColors.border)),
      child: Row(children: [
        Icon(Icons.remove_circle_outline, size: 14, color: theme.AppColors.greyDim),
        const SizedBox(width: 8),
        Text('${label.toUpperCase()} — NOT AVAILABLE', style: monoStyle.copyWith(fontSize: 11, color: theme.AppColors.greyDim)),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Raw data table -- ONE virtualized, sortable, searchable, exportable table
// implementation shared by both the app bar's split-screen sidebar and the
// standalone /explore/data page. The sidebar previously used a separate,
// simpler RawDataTable (widgets.dart) built on a plain DataTable widget
// inside only a horizontal SingleChildScrollView -- with no vertical scroll
// view wrapping it, so anything past the panel's visible height just
// overflowed instead of scrolling. Reusing THIS table (ListView.builder +
// itemExtent, the same virtualized approach the full page already used)
// fixes that outright rather than patching the old one, and means the
// sidebar and the full page can never drift out of sync again.
// ---------------------------------------------------------------------------

class _RawDataTableView extends ConsumerStatefulWidget {
  final ModeType mode;
  /// When non-null, a back button calling this is shown in the toolbar --
  /// used by the standalone DataTableScreen route. The split-screen sidebar
  /// leaves this null since there's nowhere to "go back" to from a panel
  /// that's already sitting next to the graphs.
  final VoidCallback? onBack;
  const _RawDataTableView({required this.mode, this.onBack});

  @override
  ConsumerState<_RawDataTableView> createState() => _RawDataTableViewState();
}

class _RawDataTableViewState extends ConsumerState<_RawDataTableView> {
  String search = '';
  int? sortColumn;
  bool sortAsc = true;
  final Set<String> hiddenColumns = {};
  static const _colWidth = 150.0;

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    if (appState.location == null) return const SizedBox.shrink();
    final units = ref.watch(unitSettingsProvider);
    final fields = ref.watch(activeFieldsProvider(widget.mode));
    final rawResolution = widget.mode == ModeType.weather
        ? appState.weatherResolution
        : widget.mode == ModeType.historical
            ? appState.historicalResolution
            : TemporalResolution.hourly;
    final resolution = isLongRange(appState.rangeStart, appState.rangeEnd) ? TemporalResolution.daily : rawResolution;
    // Identical FetchParams to whatever the graph grid for this mode is
    // already fetching with -- dataProvider's keepAlive cache serves this
    // from the exact same in-flight or completed request, so showing the
    // table alongside the graphs is never a second network call.
    final params = FetchParams(
      mode: widget.mode,
      location: appState.location!,
      rangeStart: appState.rangeStart,
      rangeEnd: appState.rangeEnd,
      fieldKeys: [for (final f in fields) f.jsonKey],
      unitsKey: units.key,
      resolution: resolution,
    );
    final asyncData = ref.watch(dataProvider(params));

    return asyncData.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e', style: monoStyle.copyWith(color: theme.AppColors.red))),
      data: (data) => _buildTable(appState, data, fields, units, resolution),
    );
  }

  Widget _buildTable(AppState appState, Map<String, dynamic> data, List<FieldSpec> fields, UnitSettings units, TemporalResolution resolution) {
    final series = widget.mode == ModeType.weather
        ? ((resolution == TemporalResolution.daily ? data['daily'] : data['hourly']) as Map<String, dynamic>?) ?? {}
        : (data['hourly'] as Map<String, dynamic>?) ?? (data['daily'] as Map<String, dynamic>?) ?? {};
    final rawTimes = (series['time'] as List?) ?? [];
    final times = [
      for (final t in rawTimes)
        if (t is num) _formatTableTime(DateTime.fromMillisecondsSinceEpoch(t.toInt() * 1000, isUtc: true)) else '$t'
    ];
    final visibleFields = fields.where((f) => !hiddenColumns.contains(f.jsonKey)).toList();
    final columns = ['time', for (final f in visibleFields) '${f.label} (${f.unitLabel(units)})'];

    var rows = <List<dynamic>>[for (var i = 0; i < times.length; i++) [times[i], for (final f in visibleFields) (series[f.jsonKey] as List?)?[i]]];

    if (search.isNotEmpty) {
      final q = search.toLowerCase();
      rows = rows.where((r) => r.any((c) => '$c'.toLowerCase().contains(q))).toList();
    }
    if (sortColumn != null && sortColumn! < columns.length) {
      rows.sort((a, b) {
        final av = a[sortColumn!], bv = b[sortColumn!];
        final cmp = (av is num && bv is num) ? av.compareTo(bv) : '$av'.compareTo('$bv');
        return sortAsc ? cmp : -cmp;
      });
    }

    return Column(
      children: [
        Container(
          color: panelColor,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              if (widget.onBack != null)
                IconButton(
                  icon: Icon(Icons.arrow_back, color: theme.AppColors.amber),
                  onPressed: widget.onBack,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              Text('${widget.mode.label.toUpperCase()} — RAW DATA (${rows.length} ROWS)', style: monoStyle.copyWith(fontSize: 12, color: theme.AppColors.white)),
              SizedBox(
                width: 200,
                height: 32,
                child: TextField(
                  style: monoStyle.copyWith(color: theme.AppColors.white, fontSize: 12),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'SEARCH',
                    hintStyle: monoStyle.copyWith(color: theme.AppColors.grey, fontSize: 12),
                    prefixIcon: Icon(Icons.search, color: theme.AppColors.grey, size: 16),
                    border: OutlineInputBorder(borderSide: BorderSide(color: theme.AppColors.border)),
                  ),
                  onChanged: (v) => setState(() => search = v),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Columns',
                icon: Icon(Icons.view_column, color: theme.AppColors.grey, size: 20),
                padding: EdgeInsets.zero,
                itemBuilder: (context) => [
                  for (final f in fields) CheckedPopupMenuItem(value: f.jsonKey, checked: !hiddenColumns.contains(f.jsonKey), child: Text(f.label, style: monoStyle.copyWith(fontSize: 12))),
                ],
                onSelected: (key) => setState(() => hiddenColumns.contains(key) ? hiddenColumns.remove(key) : hiddenColumns.add(key)),
              ),
              TextButton.icon(
                onPressed: () => _download(const ListToCsvConverter().convert([columns, ...rows]), 'data.csv', 'text/csv'),
                icon: Icon(Icons.download, size: 14, color: theme.AppColors.amber),
                label: Text('CSV', style: monoStyle.copyWith(color: theme.AppColors.amber, fontSize: 12)),
              ),
              TextButton.icon(
                onPressed: () => _download(jsonEncode({'columns': columns, 'rows': rows}), 'data.json', 'application/json'),
                icon: Icon(Icons.download, size: 14, color: theme.AppColors.amber),
                label: Text('JSON', style: monoStyle.copyWith(color: theme.AppColors.amber, fontSize: 12)),
              ),
            ],
          ),
        ),
        Expanded(
          // Horizontal scroll for wide column sets, wrapping a Column whose
          // ListView.builder below is what actually gives vertical scroll --
          // this is the piece the old sidebar table was missing entirely.
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: _colWidth * columns.length,
              child: Column(
                children: [
                  _headerRow(columns),
                  Expanded(
                    child: rows.isEmpty
                        ? Center(child: Text('NO DATA AVAILABLE', style: monoStyle.copyWith(fontSize: 11, color: theme.AppColors.greyDim)))
                        : ListView.builder(
                            itemCount: rows.length,
                            itemExtent: 30,
                            itemBuilder: (context, i) => _dataRow(rows[i], i),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _headerRow(List<String> columns) {
    return Container(
      decoration: const BoxDecoration(color: panelColor, border: Border(bottom: BorderSide(color: theme.AppColors.border))),
      child: Row(children: [
        for (var c = 0; c < columns.length; c++)
          SizedBox(
            width: _colWidth,
            child: InkWell(
              onTap: () => setState(() {
                if (sortColumn == c) {
                  sortAsc = !sortAsc;
                } else {
                  sortColumn = c;
                  sortAsc = true;
                }
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                child: Row(children: [
                  Expanded(child: Text(columns[c], style: monoStyle.copyWith(fontSize: 11, color: theme.AppColors.grey), maxLines: 2, overflow: TextOverflow.ellipsis)),
                  if (sortColumn == c) Icon(sortAsc ? Icons.arrow_upward : Icons.arrow_downward, size: 12, color: theme.AppColors.amber),
                ]),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _dataRow(List<dynamic> row, int i) {
    return Container(
      color: i.isEven ? bgColor : panelColor,
      child: Row(children: [
        for (final v in row)
          SizedBox(
            width: _colWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(v == null ? '' : '$v', style: monoStyle.copyWith(fontSize: 11, color: theme.AppColors.white), overflow: TextOverflow.ellipsis),
            ),
          ),
      ]),
    );
  }

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
}

/// Standalone /explore/data route -- now just a Scaffold shell around
/// _RawDataTableView with a back button wired to the dashboard, so the page
/// and the split-screen sidebar can never drift out of sync.
class DataTableScreen extends ConsumerWidget {
  const DataTableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final router = ref.watch(routerProvider);
    if (appState.location == null) return const SizedBox.shrink();
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: _RawDataTableView(
          mode: appState.mode,
          onBack: () => ref.read(appStateProvider.notifier).goToDashboard(router),
        ),
      ),
    );
  }
}