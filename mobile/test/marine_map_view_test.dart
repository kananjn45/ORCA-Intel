import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_mobile/views/map/widgets/map_layer_controls.dart';
import 'package:orca_mobile/views/map/widgets/vessel_heading_marker.dart';
import 'package:orca_mobile/core/constants/app_colors.dart';
import 'package:orca_mobile/core/theme/app_theme.dart';

void main() {
  group('Web UI Map Component Tests', () {
    testWidgets('MapLayerControls renders all 4 toggle chips and responds to taps', (WidgetTester tester) async {
      bool routeToggled = false;
      bool pfzToggled = false;
      bool hazardsToggled = false;
      bool imblToggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: AppColors.brandNavy,
            body: Center(
              child: MapLayerControls(
                showRoute: true,
                showPfz: true,
                showHazards: false,
                showImbl: true,
                onToggleRoute: () => routeToggled = true,
                onTogglePfz: () => pfzToggled = true,
                onToggleHazards: () => hazardsToggled = true,
                onToggleImbl: () => imblToggled = true,
              ),
            ),
          ),
        ),
      );

      // Verify all 4 labels are rendered
      expect(find.text('Route'), findsOneWidget);
      expect(find.text('PFZ'), findsOneWidget);
      expect(find.text('Hazards'), findsOneWidget);
      expect(find.text('IMBL'), findsOneWidget);

      // Tap Route chip
      await tester.tap(find.text('Route'));
      expect(routeToggled, isTrue);

      // Tap Hazards chip
      await tester.tap(find.text('Hazards'));
      expect(hazardsToggled, isTrue);

      // Tap IMBL chip
      await tester.tap(find.text('IMBL'));
      expect(imblToggled, isTrue);

      // Tap PFZ chip
      await tester.tap(find.text('PFZ'));
      expect(pfzToggled, isTrue);
    });

    testWidgets('VesselHeadingMarker renders boat vector and speed tooltip', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: VesselHeadingMarker(
                headingDeg: 82.0,
                speedKnots: 8.4,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Your vessel · 8.4 kt'), findsOneWidget);
      expect(find.byIcon(Icons.navigation_rounded), findsOneWidget);
    });

    test('ThemeController toggles between dark tactical and sunlight deck mode', () {
      ThemeController.setDarkMode(true);
      expect(ThemeController.isDarkMode.value, isTrue);

      ThemeController.toggleTheme();
      expect(ThemeController.isDarkMode.value, isFalse);

      ThemeController.toggleTheme();
      expect(ThemeController.isDarkMode.value, isTrue);
    });

    testWidgets('MapLayerControls supports collapsible header and sunlight light theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapLayerControls(
              showRoute: true,
              showPfz: true,
              showHazards: true,
              showImbl: true,
              isDarkMode: false,
              initiallyExpanded: true,
              onToggleRoute: () {},
              onTogglePfz: () {},
              onToggleHazards: () {},
              onToggleImbl: () {},
            ),
          ),
        ),
      );

      // Verify header is visible
      expect(find.text('Layers (4)'), findsOneWidget);
      expect(find.text('Route'), findsOneWidget);

      // Tap header to collapse
      await tester.tap(find.text('Layers (4)'));
      await tester.pumpAndSettle();

      // After collapse, individual layer chips are hidden
      expect(find.text('Route'), findsNothing);

      // Tap header again to expand
      await tester.tap(find.text('Layers (4)'));
      await tester.pumpAndSettle();
      expect(find.text('Route'), findsOneWidget);
    });
  });
}

