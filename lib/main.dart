// lib/main.dart
//
// Boots the REAL app: ProviderScope + GoRouter, which routes to
// LandingScreen (full-screen flutter_map + autocomplete) and DashboardScreen
// (AppBar/TabBar + per-mode widgets) from screens.dart/providers.dart.
//
// The previous version of this file (`StratosphericApp` / `WeatherHomePage`)
// talked to a Leaflet map embedded directly in index.html via dart:html +
// window.postMessage/js_util (see the `flyToLocation` JS bridge call). That
// approach is now fully replaced by flutter_map running natively inside
// Flutter (see LandingScreen in screens.dart) -- there is no more JS map to
// bridge to, and no more `flyToLocation` global expected on `window`.
//
// IMPORTANT: if index.html still has the old Leaflet <script>/<div id="map">
// setup left over from the previous approach, remove it. Two independently
// DOM-managed map layers (JS Leaflet underneath, Flutter's transparent
// canvas/input layer on top) is what caused the
// `event_position_helper.dart` "targetElement == domElement" assertion and
// white screen -- Flutter's HTML-renderer input handling gets confused about
// which DOM element actually owns focus once outside JS starts moving
// document.activeElement around. Deleting the old map script (or at least
// giving its container `tabindex="-1"` / removing its ability to steal
// focus) is required, not optional, alongside this file swap.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';
import 'theme.dart' as theme;

void main() {
  runApp(const ProviderScope(child: StratumApp()));
}

class StratumApp extends ConsumerWidget {
  const StratumApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // routerProvider is defined in providers.dart -- it already declares
    // '/', '/explore', and '/explore/data' and drives LandingScreen /
    // DashboardScreen / DataTableScreen from there.
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Stratum — Open Climatic Intelligence',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: theme.AppColors.bg,
        colorScheme: ColorScheme.dark(
          primary: theme.AppColors.amber,
          surface: theme.AppColors.panel,
          onSurface: theme.AppColors.white,
        ),
        textTheme: Typography.whiteMountainView.apply(fontFamily: 'JetBrainsMono'),
        appBarTheme: AppBarTheme(backgroundColor: theme.AppColors.panel, elevation: 0),
      ),
    );
  }
}