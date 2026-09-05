import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/telemetry_model.dart';
import '../../data/models/geofence_model.dart';
import 'widgets/map_layer_controls.dart';
import 'widgets/vessel_heading_marker.dart';
import 'widgets/astar_route_layer.dart';
import 'widgets/pfz_polygon_layer.dart';
import 'widgets/imbl_boundary_layer.dart';

class MarineMapView extends StatefulWidget {
  final TelemetryModel telemetry;
  final GeofenceModel geofence;
  final bool showPfzRoute;
  final bool showEvasiveRoute;
  final VoidCallback? onRecenterTap;
  final VoidCallback? onMenuTap;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onPfzTap;
  final VoidCallback? onImblTap;
  final VoidCallback? onHazardsTap;
  final VoidCallback? onRouteChipTap;

  const MarineMapView({
    super.key,
    required this.telemetry,
    required this.geofence,
    this.showPfzRoute = true,
    this.showEvasiveRoute = false,
    this.onRecenterTap,
    this.onMenuTap,
    this.onAvatarTap,
    this.onPfzTap,
    this.onImblTap,
    this.onHazardsTap,
    this.onRouteChipTap,
  });

  @override
  State<MarineMapView> createState() => _MarineMapViewState();
}

class _MarineMapViewState extends State<MarineMapView>
    with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  late final AnimationController _pulseController;

  // Layer filter toggle states matching Web UI
  bool _layerRoute = true;
  bool _layerPfz = true;
  bool _layerHazards = true;
  bool _layerImbl = true;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant MarineMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.telemetry.latitude != widget.telemetry.latitude ||
        oldWidget.telemetry.longitude != widget.telemetry.longitude) {
      // Re-center smoothly if position changes noticeably
      _mapController.move(
        LatLng(widget.telemetry.latitude, widget.telemetry.longitude),
        _mapController.camera.zoom,
      );
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _recenterOnVessel() {
    HapticFeedback.lightImpact();
    final target = LatLng(widget.telemetry.latitude, widget.telemetry.longitude);
    _mapController.move(target, 11.0);
    widget.onRecenterTap?.call();
  }

  /// Calculates dynamic geo coordinates based on current vessel position
  /// Ensures both Web UI coordinates (12.80, 80.36) and Palk Strait (9.28, 79.31) look great!
  List<LatLng> _computeRouteWaypoints(LatLng vesselPos) {
    if (vesselPos.latitude > 11.0) {
      // Chennai / Tamil Nadu North Coast (Web UI demo alignment)
      return [
        vesselPos,
        const LatLng(12.75, 80.44),
        const LatLng(12.68, 80.50),
        const LatLng(12.66, 80.59),
        const LatLng(12.60, 80.70),
      ];
    } else {
      // Palk Strait / Rameswaram Coast (ISRO scenarios)
      return [
        vesselPos,
        LatLng(vesselPos.latitude + 0.04, vesselPos.longitude + 0.05),
        LatLng(vesselPos.latitude + 0.08, vesselPos.longitude + 0.10),
        LatLng(vesselPos.latitude + 0.12, vesselPos.longitude + 0.14),
      ];
    }
  }

  LatLng _computeDestination(LatLng vesselPos) {
    if (vesselPos.latitude > 11.0) {
      return const LatLng(12.60, 80.70);
    } else {
      return LatLng(vesselPos.latitude + 0.12, vesselPos.longitude + 0.14);
    }
  }

  List<LatLng> _computePfzPolygon(LatLng vesselPos) {
    if (vesselPos.latitude > 11.0) {
      return const [
        LatLng(12.52, 80.61),
        LatLng(12.56, 80.78),
        LatLng(12.67, 80.75),
        LatLng(12.64, 80.57),
      ];
    } else {
      final baseLat = vesselPos.latitude + 0.10;
      final baseLon = vesselPos.longitude + 0.12;
      return [
        LatLng(baseLat - 0.04, baseLon - 0.04),
        LatLng(baseLat - 0.02, baseLon + 0.06),
        LatLng(baseLat + 0.04, baseLon + 0.04),
        LatLng(baseLat + 0.02, baseLon - 0.03),
      ];
    }
  }

  LatLng _computePfzCenter(LatLng vesselPos) {
    if (vesselPos.latitude > 11.0) {
      return const LatLng(12.60, 80.68);
    } else {
      return LatLng(vesselPos.latitude + 0.10, vesselPos.longitude + 0.12);
    }
  }

  LatLng _computeHazardCenter(LatLng vesselPos) {
    if (vesselPos.latitude > 11.0) {
      return const LatLng(12.88, 80.58);
    } else {
      return LatLng(vesselPos.latitude + 0.08, vesselPos.longitude - 0.05);
    }
  }

  List<LatLng> _computeImblPoints(LatLng vesselPos) {
    if (vesselPos.latitude > 11.0) {
      return const [
        LatLng(12.38, 80.89),
        LatLng(12.54, 80.83),
        LatLng(12.71, 80.83),
        LatLng(12.91, 80.74),
        LatLng(13.10, 80.69),
      ];
    } else {
      // Palk Strait maritime line
      return const [
        LatLng(9.10, 79.52),
        LatLng(9.25, 79.46),
        LatLng(9.35, 79.42),
        LatLng(9.50, 79.35),
        LatLng(9.70, 79.28),
      ];
    }
  }

  LatLng _computeImblMarkerPoint(LatLng vesselPos) {
    if (vesselPos.latitude > 11.0) {
      return const LatLng(12.71, 80.83);
    } else {
      return const LatLng(9.35, 79.42);
    }
  }

  String _formatCoordinate(double val, bool isLat) {
    final dir = isLat ? (val >= 0 ? 'N' : 'S') : (val >= 0 ? 'E' : 'W');
    return '${val.abs().toStringAsFixed(4)}° $dir';
  }

  @override
  Widget build(BuildContext context) {
    final vesselPos = LatLng(widget.telemetry.latitude, widget.telemetry.longitude);
    final waypoints = _computeRouteWaypoints(vesselPos);
    final destination = _computeDestination(vesselPos);
    final pfzPolygon = _computePfzPolygon(vesselPos);
    final pfzCenter = _computePfzCenter(vesselPos);
    final hazardCenter = _computeHazardCenter(vesselPos);
    final imblPoints = _computeImblPoints(vesselPos);
    final imblMarker = _computeImblMarkerPoint(vesselPos);

    return Stack(
      children: [
        // ====================================================================
        // 1. LEAFLET / OSM CARTODB DARK MARINE MAP
        // ====================================================================
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: vesselPos,
            initialZoom: 10.2,
            minZoom: 5.0,
            maxZoom: 17.0,
            backgroundColor: AppColors.brandNavy,
          ),
          children: [
            // Dark Oceanic OpenStreetMap Tile Layer (No API Key Required, No Watermark)
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              maxZoom: 18,
              userAgentPackageName: 'org.orca.mobile',
              tileBuilder: (context, tileWidget, tile) {
                return ColorFiltered(
                  colorFilter: const ColorFilter.matrix([
                    // Invert RGB and tint towards deep midnight oceanic blue
                    -0.20,  0.00,  0.00, 0.0, 32,
                     0.00, -0.18,  0.00, 0.0, 48,
                     0.00,  0.00, -0.12, 0.0, 72,
                     0.00,  0.00,  0.00, 1.0, 0,
                  ]),
                  child: tileWidget,
                );
              },
            ),

            // IMBL Layer
            if (_layerImbl) ...[
              ImblBoundaryLayer.buildPolylineLayer(imblPoints: imblPoints),
              ImblBoundaryLayer.buildBorderWarningMarker(
                markerPosition: imblMarker,
                onTap: widget.onImblTap,
              ),
            ],

            // Weather Watch / Hazards Layer
            if (_layerHazards) ...[
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: hazardCenter,
                    radius: 7700,
                    useRadiusInMeter: true,
                    color: AppColors.hazardAmber.withOpacity(0.20),
                    borderColor: AppColors.hazardAmber,
                    borderStrokeWidth: 2.0,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: hazardCenter,
                    width: 130,
                    height: 38,
                    child: GestureDetector(
                      onTap: widget.onHazardsTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.brandSurfaceGlass,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: AppColors.hazardAmber.withOpacity(0.8),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.waves_rounded,
                              size: 13,
                              color: AppColors.hazardAmber,
                            ),
                            SizedBox(width: 4),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'WEATHER WATCH',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.hazardAmber,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                Text(
                                  'Moderate swell window',
                                  style: TextStyle(
                                    fontSize: 7.5,
                                    color: AppColors.inkLight,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // PFZ Layer
            if (_layerPfz) ...[
              PfzPolygonLayer.buildPolygonLayer(boundaryPoints: pfzPolygon),
              PfzPolygonLayer.buildCenterLabelMarker(
                center: pfzCenter,
                onTap: widget.onPfzTap,
              ),
            ],

            // Active Safe Route Polyline & Destination
            if (_layerRoute && (widget.showPfzRoute || !widget.showEvasiveRoute)) ...[
              AstarRouteLayer.buildPolylineLayer(waypoints: waypoints),
              AstarRouteLayer.buildDestinationMarkerLayer(
                destination: destination,
                label: 'PFZ Sector 04',
                onTap: widget.onPfzTap,
              ),
            ],

            // Vessel Marker (Always Visible on Top)
            MarkerLayer(
              markers: [
                Marker(
                  point: vesselPos,
                  width: 90,
                  height: 90,
                  child: VesselHeadingMarker(
                    headingDeg: widget.telemetry.headingDeg,
                    speedKnots: widget.telemetry.speedKnots,
                    onTap: widget.onMenuTap,
                  ),
                ),
              ],
            ),
          ],
        ),

        // ====================================================================
        // 2. FLOATING TOPBAR (BRAND, MENU, AVATAR)
        // ====================================================================
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Menu / Simulator Trigger
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onMenuTap?.call();
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xD9041926),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.08),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 17,
                                height: 2,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: AppColors.inkLight,
                                    borderRadius: BorderRadius.all(Radius.circular(1)),
                                  ),
                                ),
                              ),
                              SizedBox(height: 5),
                              SizedBox(
                                width: 12,
                                height: 2,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: AppColors.inkLight,
                                    borderRadius: BorderRadius.all(Radius.circular(1)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Brand Mark ⌁ SeaSentinel
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.rotate(
                        angle: -20 * math.pi / 180,
                        child: const Text(
                          '⌁',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppColors.neonLime,
                            height: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            color: AppColors.inkLight,
                          ),
                          children: [
                            TextSpan(text: 'Sea'),
                            TextSpan(
                              text: 'Sentinel',
                              style: TextStyle(color: AppColors.neonLime),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Profile / Language Avatar
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onAvatarTap?.call();
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xD9041926),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF75A5AB),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'RK',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: AppColors.inkLight,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ====================================================================
        // 3. FLOATING GPS STATUS BADGE
        // ====================================================================
        Positioned(
          top: 66,
          left: 18,
          child: SafeArea(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.brandSurfaceGlass,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.cardBorder.withOpacity(0.5),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Container(
                                width: 6.5,
                                height: 6.5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.neonLime,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.neonLime.withOpacity(
                                        0.3 + 0.6 * _pulseController.value,
                                      ),
                                      blurRadius: 4 + 4 * _pulseController.value,
                                      spreadRadius: 1 * _pulseController.value,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'GPS CONNECTED',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.inkLight,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text(
                          '${_formatCoordinate(widget.telemetry.latitude, true)}, ${_formatCoordinate(widget.telemetry.longitude, false)}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted.withOpacity(0.9),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // ====================================================================
        // 4. FLOATING LAYER FILTER CONTROLS (RIGHT SIDE)
        // ====================================================================
        Positioned(
          top: 66,
          right: 18,
          child: SafeArea(
            child: MapLayerControls(
              showRoute: _layerRoute,
              showPfz: _layerPfz,
              showHazards: _layerHazards,
              showImbl: _layerImbl,
              onToggleRoute: () => setState(() => _layerRoute = !_layerRoute),
              onTogglePfz: () => setState(() => _layerPfz = !_layerPfz),
              onToggleHazards: () => setState(() => _layerHazards = !_layerHazards),
              onToggleImbl: () => setState(() => _layerImbl = !_layerImbl),
            ),
          ),
        ),

        // ====================================================================
        // 5. RECENTER FAB (⌖)
        // ====================================================================
        Positioned(
          right: 18,
          bottom: 84,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: GestureDetector(
                onTap: _recenterOnVessel,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xD9041926),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.electricTeal.withOpacity(0.4),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.my_location_rounded,
                      size: 22,
                      color: AppColors.electricTeal,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // ====================================================================
        // 6. ACTIVE ROUTE CHIP (FLOATING ABOVE COMMAND DECK)
        // ====================================================================
        Positioned(
          left: 18,
          right: 18,
          bottom: 18,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onRouteChipTap?.call();
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xDD072B3C),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.cardBorder,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Pulsing green route indicator dot
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.neonLime,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.neonLime.withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'ACTIVE ROUTE',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            widget.showEvasiveRoute
                                ? 'EVASIVE · Return to India Waters'
                                : 'PFZ · Sector 04',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.inkLight,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: AppColors.neonLime,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
