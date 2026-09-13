import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/telemetry_model.dart';
import '../../data/models/geofence_model.dart';
import '../../data/models/pfz_model.dart';
import '../../data/models/cyclone_hazard_model.dart';
import 'widgets/map_layer_controls.dart';
import 'widgets/vessel_heading_marker.dart';
import 'widgets/astar_route_layer.dart';
import 'widgets/pfz_polygon_layer.dart';
import 'widgets/imbl_boundary_layer.dart';
import '../../core/utils/geo_math.dart';

class MarineMapView extends StatefulWidget {
  final TelemetryModel telemetry;
  final GeofenceModel geofence;
  final PFZModel? activePfz;
  final CycloneHazardModel? liveHazard;
  final bool showPfzRoute;
  final bool showEvasiveRoute;
  final bool isDarkMode;
  final String currentLanguageName;
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
    this.activePfz,
    this.liveHazard,
    this.showPfzRoute = true,
    this.showEvasiveRoute = false,
    this.isDarkMode = false,
    this.currentLanguageName = 'English',
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
  /// Fixed regional safe refuge harbors for emergency evasion
  LatLng _computeRefugeHarbor(LatLng vesselPos) {
    if (vesselPos.latitude > 20.0) {
      return const LatLng(21.6417, 69.6293); // Porbandar Harbor
    } else if (vesselPos.latitude > 15.0) {
      return const LatLng(17.6975, 83.2981); // Visakhapatnam Naval Harbor
    } else if (vesselPos.latitude > 11.0) {
      return const LatLng(12.7850, 80.2550); // Kovalam / Kasimedu Safe Harbor
    } else if (vesselPos.longitude < 79.2) {
      return const LatLng(9.1520, 79.1240); // Mandapam Base
    } else {
      return const LatLng(9.2854, 79.3121); // Rameswaram Harbor
    }
  }

  /// Anchored Oceanic PFZ Destination Coordinates
  LatLng _computeDestination(LatLng vesselPos) {
    if (widget.showEvasiveRoute) {
      return _computeRefugeHarbor(vesselPos);
    }
    if (widget.activePfz != null) {
      return LatLng(widget.activePfz!.centroidLat, widget.activePfz!.centroidLon);
    }
    if (vesselPos.latitude > 20.0) {
      return const LatLng(21.5200, 69.4100); // Gujarat Porbandar Offshore Bank (Arabian Sea)
    } else if (vesselPos.latitude > 15.0) {
      return const LatLng(17.6150, 83.5200); // Andhra Shelf PFZ
    } else if (vesselPos.latitude > 11.0) {
      return const LatLng(12.6500, 80.6500); // Chennai-Mahabalipuram Upwelling Basin
    } else if (vesselPos.longitude < 79.2) {
      return const LatLng(9.0650, 79.2800); // Gulf of Mannar Deep Reef
    } else {
      return const LatLng(9.3450, 79.4180); // Palk Strait Central PFZ
    }
  }

  /// Calculates smooth, collision-free nautical channel waypoints connecting the vessel's
  /// live position to the anchored target destination.
  List<LatLng> _computeRouteWaypoints(LatLng vesselPos) {
    final dest = _computeDestination(vesselPos);

    if (widget.showEvasiveRoute) {
      // Evasive 180° Emergency Route towards safe refuge harbor
      final midLat = vesselPos.latitude + (dest.latitude - vesselPos.latitude) * 0.5;
      final midLon = vesselPos.longitude + (dest.longitude - vesselPos.longitude) * 0.5;
      return [
        vesselPos,
        LatLng(midLat, midLon),
        dest,
      ];
    }

    final dLat = dest.latitude - vesselPos.latitude;
    final dLon = dest.longitude - vesselPos.longitude;
    final distKm = GeoMath.haversineKm(vesselPos.latitude, vesselPos.longitude, dest.latitude, dest.longitude);

    if (distKm < 1.0) {
      return [vesselPos, dest];
    }

    // Curvature bias to steer clear of shallow shores and stay within the safe maritime channel
    double latBend = 0.0;
    double lonBend = 0.0;
    if (vesselPos.latitude > 20.0) {
      // Gujarat: keep south-west in open Arabian Sea, well clear of coastline
      latBend = -0.012;
      lonBend = -0.015;
    } else if (vesselPos.latitude > 15.0) {
      // Andhra: offshore channel
      latBend = -0.010;
      lonBend = 0.015;
    } else if (vesselPos.latitude > 11.0) {
      // Chennai: gentle offshore arc towards Mahabalipuram PFZ
      latBend = -0.018;
      lonBend = 0.022;
    } else if (vesselPos.longitude < 79.2) {
      // Gulf of Mannar: deep channel between coral islands
      latBend = -0.012;
      lonBend = 0.018;
    } else {
      // Palk Strait: stay safely west of the Indo-Sri Lanka IMBL (79.52)
      latBend = 0.015;
      lonBend = -0.012;
    }

    final wp1 = LatLng(
      vesselPos.latitude + dLat * 0.30 + latBend,
      vesselPos.longitude + dLon * 0.30 + lonBend,
    );
    final wp2 = LatLng(
      vesselPos.latitude + dLat * 0.65 + (latBend * 0.6),
      vesselPos.longitude + dLon * 0.65 + (lonBend * 0.6),
    );

    return [vesselPos, wp1, wp2, dest];
  }

  /// Computes cumulative nautical distance across route waypoints
  double _computeTotalRouteDistanceKm(List<LatLng> waypoints) {
    if (waypoints.length < 2) return 0.0;
    double total = 0.0;
    for (int i = 0; i < waypoints.length - 1; i++) {
      total += GeoMath.haversineKm(
        waypoints[i].latitude,
        waypoints[i].longitude,
        waypoints[i + 1].latitude,
        waypoints[i + 1].longitude,
      );
    }
    return total;
  }

  List<LatLng> _computePfzPolygon(LatLng vesselPos) {
    if (widget.activePfz != null && widget.activePfz!.polygonCoordinates.isNotEmpty) {
      return widget.activePfz!.polygonCoordinates
          .map((pt) => LatLng(pt[1], pt[0]))
          .toList();
    }
    final center = _computePfzCenter(vesselPos);
    return [
      LatLng(center.latitude - 0.045, center.longitude - 0.055),
      LatLng(center.latitude - 0.025, center.longitude + 0.065),
      LatLng(center.latitude + 0.050, center.longitude + 0.045),
      LatLng(center.latitude + 0.030, center.longitude - 0.040),
    ];
  }

  LatLng _computePfzCenter(LatLng vesselPos) {
    if (widget.activePfz != null) {
      return LatLng(widget.activePfz!.centroidLat, widget.activePfz!.centroidLon);
    }
    if (vesselPos.latitude > 20.0) {
      return const LatLng(21.5200, 69.4100); // Gujarat Porbandar Offshore Bank in Arabian Sea
    } else if (vesselPos.latitude > 15.0) {
      return const LatLng(17.6150, 83.5200);
    } else if (vesselPos.latitude > 11.0) {
      return const LatLng(12.6500, 80.6500);
    } else if (vesselPos.longitude < 79.2) {
      return const LatLng(9.0650, 79.2800);
    } else {
      return const LatLng(9.3450, 79.4180);
    }
  }

  LatLng _computeHazardCenter(LatLng vesselPos) {
    if (vesselPos.latitude > 20.0) {
      return const LatLng(21.4800, 69.3500); // Arabian Sea offshore swell area
    } else if (vesselPos.latitude > 15.0) {
      return const LatLng(17.7400, 83.4200);
    } else if (vesselPos.latitude > 11.0) {
      return const LatLng(12.8600, 80.5200);
    } else if (vesselPos.longitude < 79.2) {
      return const LatLng(9.1800, 79.0800);
    } else {
      return const LatLng(9.2200, 79.2200);
    }
  }

  List<LatLng> _computeImblPoints(LatLng vesselPos) {
    if (vesselPos.latitude > 20.0) {
      // Sir Creek / India-Pakistan Notional Line
      return const [
        LatLng(22.35, 68.45),
        LatLng(22.15, 68.65),
        LatLng(21.95, 68.85),
        LatLng(21.75, 69.10),
        LatLng(21.50, 69.30),
      ];
    } else if (vesselPos.latitude > 15.0) {
      // Andhra Deep Sea EEZ Line
      return const [
        LatLng(17.20, 83.95),
        LatLng(17.45, 83.88),
        LatLng(17.70, 83.75),
        LatLng(17.95, 83.60),
        LatLng(18.20, 83.45),
      ];
    } else if (vesselPos.latitude > 11.0) {
      // Chennai Northern Bay Line
      return const [
        LatLng(12.38, 80.89),
        LatLng(12.54, 80.83),
        LatLng(12.71, 80.83),
        LatLng(12.91, 80.74),
        LatLng(13.10, 80.69),
      ];
    } else if (vesselPos.longitude < 79.2) {
      // Gulf of Mannar
      return const [
        LatLng(8.75, 79.25),
        LatLng(8.92, 79.35),
        LatLng(9.10, 79.45),
        LatLng(9.25, 79.52),
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
    if (vesselPos.latitude > 20.0) {
      return const LatLng(22.10, 68.80);
    } else if (vesselPos.latitude > 15.0) {
      return const LatLng(17.50, 83.85);
    } else if (vesselPos.latitude > 11.0) {
      return const LatLng(12.71, 80.83);
    } else if (vesselPos.longitude < 79.2) {
      return const LatLng(8.92, 79.35);
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
    final hazardCenter = widget.liveHazard?.centerLatLng ?? _computeHazardCenter(vesselPos);
    final hazardRadius = widget.liveHazard?.radiusMeters ?? 7700.0;
    final isSevereHazard = widget.liveHazard?.isSevere ?? false;
    final hazardColor = isSevereHazard
        ? (widget.isDarkMode ? AppColors.stitchError : const Color(0xFFDC2626))
        : (widget.isDarkMode ? AppColors.hazardAmber : const Color(0xFFD97706));
    final imblPoints = _computeImblPoints(vesselPos);
    final imblMarker = _computeImblMarkerPoint(vesselPos);

    final totalRouteDistKm = _computeTotalRouteDistanceKm(waypoints);
    final totalRouteDistNm = totalRouteDistKm * 0.539957;
    final liveSpeedKnots = widget.telemetry.speedKnots > 0.5 ? widget.telemetry.speedKnots : 8.0;
    final timeHours = totalRouteDistNm / liveSpeedKnots;
    final timeMins = (timeHours * 60).round();
    final etaTime = DateTime.now().add(Duration(minutes: timeMins));
    final etaFormatted = 'ETA ${etaTime.hour.toString().padLeft(2, '0')}:${etaTime.minute.toString().padLeft(2, '0')} IST';
    final dieselBurnLtr = (totalRouteDistNm * 1.5).toStringAsFixed(1);
    final dieselCost = '₹${(totalRouteDistNm * 1.5 * 91.0).round()} @ Cruising';

    String boundaryName = 'Sri Lanka Boundary';
    if (vesselPos.latitude > 20.0) {
      boundaryName = 'Pakistan Maritime Line';
    } else if (vesselPos.latitude > 15.0) {
      boundaryName = 'Deep EEZ Boundary';
    } else if (vesselPos.latitude > 11.0) {
      boundaryName = 'International Waters Line';
    }

    String targetTitle = 'Optimal Route: PFZ Sector 04';
    String targetSubtitle = 'Target: Pelagic Tuna & Yellowfin School';
    if (widget.showEvasiveRoute) {
      targetTitle = 'Evasive Corridor: Indian Waters';
      targetSubtitle = 'Emergency Retreat to Refuge Harbor';
    } else if (vesselPos.latitude > 20.0) {
      targetTitle = 'Optimal Route: Gujarat Pelagic PFZ-01';
      targetSubtitle = 'Target: Ribbonfish, Pomfret & Sardine Grounds';
    } else if (vesselPos.latitude > 15.0) {
      targetTitle = 'Optimal Route: Andhra Deep Shelf PFZ-02';
      targetSubtitle = 'Target: Mackerel, Carangids & Pelagic Shoals';
    } else if (vesselPos.latitude > 11.0) {
      targetTitle = 'Optimal Route: Mahabalipuram Basin PFZ-08';
      targetSubtitle = 'Target: Indian Scad, Seerfish & Coastal Tuna';
    } else if (vesselPos.longitude < 79.2) {
      targetTitle = 'Optimal Route: Gulf of Mannar PFZ-03';
      targetSubtitle = 'Target: Coral Reef Squid, Barracuda & Snapper';
    }

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
            backgroundColor: widget.isDarkMode ? AppColors.brandNavy : const Color(0xFFE2E8F0),
          ),
          children: [
            // OpenStreetMap Tile Layer (Dark oceanic filter in night mode, clean daylight in deck mode)
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              maxZoom: 18,
              userAgentPackageName: 'org.orca.mobile',
              tileBuilder: (context, tileWidget, tile) {
                if (!widget.isDarkMode) {
                  return tileWidget;
                }
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
                isDarkMode: widget.isDarkMode,
              ),
            ],

            // Weather Watch / Hazards Layer
            if (_layerHazards) ...[
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: hazardCenter,
                    radius: hazardRadius,
                    useRadiusInMeter: true,
                    color: hazardColor.withOpacity(isSevereHazard ? 0.22 : 0.16),
                    borderColor: hazardColor,
                    borderStrokeWidth: isSevereHazard ? 2.5 : 2.0,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: hazardCenter,
                    width: 220,
                    height: 50,
                    child: GestureDetector(
                      onTap: widget.onHazardsTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.isDarkMode ? AppColors.brandSurfaceGlass : Colors.white.withOpacity(0.96),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: hazardColor.withOpacity(0.85),
                            width: isSevereHazard ? 1.8 : 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(widget.isDarkMode ? 0.4 : 0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSevereHazard ? Icons.warning_amber_rounded : Icons.waves_rounded,
                                size: 15,
                                color: hazardColor,
                              ),
                              const SizedBox(width: 5),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.liveHazard?.title ?? 'WEATHER WATCH',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: hazardColor,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                  Text(
                                    widget.liveHazard?.subtitle ?? 'Moderate swell window',
                                    style: TextStyle(
                                      fontSize: 7.5,
                                      fontWeight: FontWeight.w600,
                                      color: widget.isDarkMode ? AppColors.inkLight : const Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // PFZ Layer
            if (_layerPfz) ...[
              PfzPolygonLayer.buildPolygonLayer(
                boundaryPoints: pfzPolygon,
                isDarkMode: widget.isDarkMode,
              ),
              PfzPolygonLayer.buildCenterLabelMarker(
                center: pfzCenter,
                onTap: widget.onPfzTap,
                isDarkMode: widget.isDarkMode,
              ),
            ],

            // Active Safe Route Polyline & Destination
            if (_layerRoute && (widget.showPfzRoute || widget.showEvasiveRoute)) ...[
              AstarRouteLayer.buildPolylineLayer(
                waypoints: waypoints,
                color: widget.showEvasiveRoute ? AppColors.stitchError : null,
                isDarkMode: widget.isDarkMode,
              ),
              AstarRouteLayer.buildDestinationMarkerLayer(
                destination: destination,
                label: widget.showEvasiveRoute
                    ? 'SAFE REFUGE'
                    : (vesselPos.latitude > 20.0
                        ? 'PFZ GUJ-01'
                        : (vesselPos.latitude > 15.0
                            ? 'PFZ AP-02'
                            : (vesselPos.latitude > 11.0
                                ? 'PFZ TN-08'
                                : 'PFZ Sector 04'))),
                onTap: widget.showEvasiveRoute ? null : widget.onPfzTap,
                isDarkMode: widget.isDarkMode,
              ),
            ],

            // Vessel Marker (Always Visible on Top)
            MarkerLayer(
              markers: [
                Marker(
                  point: vesselPos,
                  width: 110,
                  height: 90,
                  child: VesselHeadingMarker(
                    headingDeg: widget.telemetry.headingDeg,
                    speedKnots: widget.telemetry.speedKnots,
                    onTap: widget.onMenuTap,
                    isDarkMode: widget.isDarkMode,
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
                            color: widget.isDarkMode ? const Color(0xD9041926) : Colors.white.withOpacity(0.92),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: widget.isDarkMode ? Colors.white.withOpacity(0.08) : const Color(0xFFCBD5E1),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(widget.isDarkMode ? 0.35 : 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 17,
                                height: 2,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: widget.isDarkMode ? AppColors.inkLight : const Color(0xFF0F172A),
                                    borderRadius: const BorderRadius.all(Radius.circular(1)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              SizedBox(
                                width: 12,
                                height: 2,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: widget.isDarkMode ? AppColors.inkLight : const Color(0xFF0F172A),
                                    borderRadius: const BorderRadius.all(Radius.circular(1)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Brand Mark ⌁ ORCA-Intel
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.rotate(
                        angle: -20 * math.pi / 180,
                        child: Text(
                          '⌁',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: widget.isDarkMode ? AppColors.neonLime : const Color(0xFF0284C7),
                            height: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            color: widget.isDarkMode ? AppColors.inkLight : const Color(0xFF0F172A),
                          ),
                          children: [
                            const TextSpan(text: 'ORCA-'),
                            TextSpan(
                              text: 'Intel',
                              style: TextStyle(
                                color: widget.isDarkMode ? AppColors.neonLime : const Color(0xFF0284C7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Action: Language Selector Pill
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Direct Language Pill Button
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          widget.onAvatarTap?.call();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: widget.isDarkMode ? const Color(0xD9041926) : Colors.white.withOpacity(0.92),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: widget.isDarkMode ? const Color(0xFF75A5AB) : const Color(0xFF94A3B8),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(widget.isDarkMode ? 0.35 : 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🌐', style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 4),
                              Text(
                                widget.currentLanguageName,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                  color: widget.isDarkMode ? AppColors.inkLight : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // ====================================================================
        // 3. PERSISTENT ALERT STRIP: IMBL SAFE BUFFER RIBBON & HUD COMPASS TAPE
        // ====================================================================
        Positioned(
          top: 60,
          left: 14,
          right: 14,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Stitch IMBL Safe Corridor Buffer Ribbon
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.isDarkMode ? const Color(0xEE061C2C) : AppColors.stitchSurfaceContainerLowest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.geofence.distanceToImblKm < 5.0
                            ? AppColors.stitchError
                            : AppColors.stitchOutlineVariant,
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Advisory Header Bar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          color: widget.geofence.distanceToImblKm < 5.0
                              ? AppColors.stitchError
                              : AppColors.stitchTertiary,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    widget.geofence.distanceToImblKm < 5.0
                                        ? Icons.gpp_bad_rounded
                                        : Icons.warning_amber_rounded,
                                    size: 15,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    widget.geofence.distanceToImblKm < 5.0
                                        ? 'BORDER BREACH PROXIMITY ALERT'
                                        : 'BORDER PROXIMITY ADVISORY',
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: const BoxDecoration(
                                        color: AppColors.stitchSecondaryFixed,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'RADAR ACTIVE',
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Sub Corridor & Buffer Readout
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: AppColors.stitchSurfaceContainerHigh,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                      Icons.shield_rounded,
                                      size: 16,
                                      color: AppColors.stitchPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        widget.geofence.distanceToImblKm < 5.0
                                            ? 'APPROACHING EXCLUSION ZONE'
                                            : 'SAFE CORRIDOR',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          color: widget.isDarkMode
                                              ? AppColors.inkLight
                                              : (widget.geofence.distanceToImblKm < 5.0
                                                  ? AppColors.stitchError
                                                  : AppColors.stitchOnSurface),
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      Text(
                                        '${(widget.geofence.distanceToImblKm * 0.539957).toStringAsFixed(1)} NM to $boundaryName',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: widget.isDarkMode ? AppColors.textMuted : AppColors.stitchOnSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    (widget.geofence.distanceToImblKm * 0.539957).toStringAsFixed(1),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: widget.geofence.distanceToImblKm < 5.0
                                          ? AppColors.stitchError
                                          : AppColors.stitchTertiary,
                                      height: 1.0,
                                    ),
                                  ),
                                  const Text(
                                    'NM BUFFER',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.stitchOutline,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                // Floating HUD Bearing Compass Tape (Center HUD)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (widget.isDarkMode ? AppColors.brandSurfaceGlass : Colors.white).withOpacity(0.92),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.stitchOutlineVariant, width: 0.8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.explore_rounded,
                        size: 15,
                        color: AppColors.stitchPrimary,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'HDG',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.stitchOnSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.telemetry.headingDeg.toStringAsFixed(0)}° SE',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AppColors.stitchPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(width: 1, height: 12, color: AppColors.stitchOutlineVariant),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.speed_rounded,
                        size: 15,
                        color: AppColors.stitchSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.telemetry.speedKnots.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AppColors.stitchSecondary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Text(
                        'KTS',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.stitchSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
              isDarkMode: widget.isDarkMode,
              onToggleRoute: () => setState(() => _layerRoute = !_layerRoute),
              onTogglePfz: () => setState(() => _layerPfz = !_layerPfz),
              onToggleHazards: () => setState(() => _layerHazards = !_layerHazards),
              onToggleImbl: () => setState(() => _layerImbl = !_layerImbl),
            ),
          ),
        ),

        // ====================================================================
        // 5. NAUTICAL SCALE BAR (BOTTOM LEFT)
        // ====================================================================
        Positioned(
          left: 18,
          bottom: 240,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (widget.isDarkMode ? AppColors.brandSurfaceGlass : Colors.white).withOpacity(0.92),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.stitchOutlineVariant, width: 0.8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
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
                    Text(
                      '0',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: widget.isDarkMode ? AppColors.inkLight : AppColors.stitchOnSurface,
                      ),
                    ),
                    const SizedBox(width: 46),
                    Text(
                      '1.0 NM',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: widget.isDarkMode ? AppColors.inkLight : AppColors.stitchOnSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Container(
                  width: 68,
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: AppColors.stitchSurfaceContainerHighest,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        decoration: const BoxDecoration(
                          color: AppColors.stitchPrimary,
                          borderRadius: BorderRadius.horizontal(left: Radius.circular(2)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ====================================================================
        // 6. QUICK FLOATING CONTROLS (RIGHT VERTICAL STACK)
        // ====================================================================
        Positioned(
          right: 18,
          bottom: 236,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Recenter on Vessel GPS
              _buildFloatingToolButton(
                icon: Icons.my_location_rounded,
                iconColor: AppColors.stitchPrimary,
                tooltip: 'Center GPS',
                onTap: _recenterOnVessel,
              ),
              const SizedBox(height: 6),
              // Zoom In
              _buildFloatingToolButton(
                icon: Icons.add_rounded,
                iconColor: widget.isDarkMode ? AppColors.inkLight : AppColors.stitchOnSurface,
                tooltip: 'Zoom In',
                onTap: () {
                  HapticFeedback.selectionClick();
                  _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 0.8);
                },
              ),
              const SizedBox(height: 6),
              // Zoom Out
              _buildFloatingToolButton(
                icon: Icons.remove_rounded,
                iconColor: widget.isDarkMode ? AppColors.inkLight : AppColors.stitchOnSurface,
                tooltip: 'Zoom Out',
                onTap: () {
                  HapticFeedback.selectionClick();
                  _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 0.8);
                },
              ),
            ],
          ),
        ),

        // ====================================================================
        // 7. STITCH TACTICAL NAVIGATION DECK CARD (BOTTOM SUMMARY BENTO)
        // ====================================================================
        Positioned(
          left: 14,
          right: 14,
          bottom: 12,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (widget.isDarkMode ? const Color(0xEE061C2C) : AppColors.stitchSurfaceContainerLowest).withOpacity(0.96),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.isDarkMode ? AppColors.cardBorder : AppColors.stitchOutlineVariant,
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(widget.isDarkMode ? 0.45 : 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Target Strip & INCOIS Credential
                    InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onRouteChipTap?.call();
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.stitchSecondaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.phishing_rounded,
                                color: AppColors.stitchOnSecondaryContainer,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        targetTitle,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: widget.isDarkMode ? AppColors.inkLight : AppColors.stitchOnSurface,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: AppColors.stitchSecondaryContainer,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        '91% PROB',
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.stitchOnSecondaryContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  targetSubtitle,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: widget.isDarkMode ? AppColors.textMuted : AppColors.stitchOnSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'INCOIS-ISRO',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.stitchSecondary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                'Live Sync Active',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w500,
                                  color: widget.isDarkMode ? AppColors.textMuted : AppColors.stitchOutline,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // 4-Up High Visibility Telemetry Bento Grid
                    Row(
                      children: [
                        _buildDeckBentoItem(
                          label: 'TIME TO TARGET',
                          value: '$timeMins',
                          unit: 'MIN',
                          valueColor: AppColors.stitchPrimary,
                          subtitle: etaFormatted,
                        ),
                        const SizedBox(width: 6),
                        _buildDeckBentoItem(
                          label: 'DISTANCE LEFT',
                          value: totalRouteDistNm.toStringAsFixed(1),
                          unit: 'NM',
                          valueColor: widget.isDarkMode ? AppColors.inkLight : AppColors.stitchOnSurface,
                          subtitle: widget.showEvasiveRoute ? 'To Refuge Harbor' : 'Inside Safe Corridor',
                        ),
                        const SizedBox(width: 6),
                        _buildDeckBentoItem(
                          label: 'EST. DIESEL BURN',
                          value: dieselBurnLtr,
                          unit: 'LTR',
                          valueColor: AppColors.stitchTertiary,
                          subtitle: dieselCost,
                        ),
                        const SizedBox(width: 6),
                        _buildDeckBentoItem(
                          label: 'SAFE BUFFER',
                          value: (widget.geofence.distanceToImblKm * 0.539957).toStringAsFixed(1),
                          unit: 'NM',
                          valueColor: widget.geofence.distanceToImblKm < 5.0
                              ? AppColors.stitchError
                              : AppColors.stitchSecondary,
                          subtitle: 'To Maritime Line',
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Navigation Action Bar
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 38,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.stitchPrimary,
                                foregroundColor: AppColors.stitchOnPrimary,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.navigation_rounded, size: 16),
                              label: Text(
                                widget.showPfzRoute ? 'Active NavIC Track Engaged' : 'Engage Safe PFZ Run',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                              ),
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                widget.onRouteChipTap?.call();
                              },
                            ),
                          ),
                        ),
                        if (widget.geofence.distanceToImblKm < 10.0 || widget.showEvasiveRoute) ...[
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 38,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.stitchError,
                                side: const BorderSide(color: AppColors.stitchError, width: 1.2),
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.turn_left_rounded, size: 16),
                              label: const Text(
                                'Evasive 180°',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                              ),
                              onPressed: () {
                                HapticFeedback.heavyImpact();
                                widget.onImblTap?.call();
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingToolButton({
    required IconData icon,
    required Color iconColor,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: (widget.isDarkMode ? AppColors.brandSurfaceGlass : Colors.white).withOpacity(0.92),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.stitchOutlineVariant, width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(icon, size: 20, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeckBentoItem({
    required String label,
    required String value,
    required String unit,
    required Color valueColor,
    required String subtitle,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: widget.isDarkMode ? const Color(0xFF092535) : AppColors.stitchSurfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                color: widget.isDarkMode ? AppColors.textMuted : AppColors.stitchOnSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: valueColor,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: valueColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 1),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 7.5,
                fontWeight: FontWeight.w600,
                color: widget.isDarkMode ? AppColors.textMuted : AppColors.stitchOutline,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

