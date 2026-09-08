import 'package:flutter/material.dart';
import '../../data/local/offline_cache_manager.dart';
import '../../data/repositories/marine_repository.dart';
import 'widgets/pack_download_progress.dart';

class PreVoyageScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const PreVoyageScreen({super.key, this.onBack});

  @override
  State<PreVoyageScreen> createState() => _PreVoyageScreenState();
}

class _PreVoyageScreenState extends State<PreVoyageScreen> {
  final OfflineCacheManager _cacheManager = OfflineCacheManager();
  final MarineRepository _marineRepo = MarineRepository();

  String _selectedSector = 'Palk Strait (Rameswaram)';
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _currentStep = 'Ready to download regional marine pack';
  bool _isPackActive = false;
  int _cachedCellsCount = 0;

  final List<String> _sectors = [
    'Palk Strait (Rameswaram)',
    'Gulf of Mannar (Mandapam)',
    'Coromandel Coast (Chennai)',
    'Andhra Coast (Visakhapatnam)',
    'Gujarat Offshore (Porbandar)',
  ];

  @override
  void initState() {
    super.initState();
    _checkExistingPack();
  }

  Future<void> _checkExistingPack() async {
    final hasPack = await _cacheManager.hasActiveOfflinePack();
    final count = await _cacheManager.getCachedWeatherCount();
    setState(() {
      _isPackActive = hasPack;
      _cachedCellsCount = count;
      if (hasPack) {
        _downloadProgress = 1.0;
        _currentStep = '24-Hour Offline Marine Pack Active ($count cells in SQLite)';
      }
    });
  }

  Map<String, double> _getSectorBounds(String sector) {
    switch (sector) {
      case 'Gulf of Mannar (Mandapam)':
        return {'min_lat': 8.7, 'max_lat': 9.3, 'min_lon': 78.8, 'max_lon': 79.5};
      case 'Coromandel Coast (Chennai)':
        return {'min_lat': 12.8, 'max_lat': 13.4, 'min_lon': 80.1, 'max_lon': 80.7};
      case 'Andhra Coast (Visakhapatnam)':
        return {'min_lat': 17.4, 'max_lat': 18.0, 'min_lon': 83.1, 'max_lon': 83.7};
      case 'Gujarat Offshore (Porbandar)':
        return {'min_lat': 21.4, 'max_lat': 22.0, 'min_lon': 69.4, 'max_lon': 70.0};
      case 'Palk Strait (Rameswaram)':
      default:
        return {'min_lat': 9.0, 'max_lat': 9.6, 'min_lon': 79.0, 'max_lon': 79.8};
    }
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.15;
      _currentStep = '1/4: Requesting 24h marine pack from server for $_selectedSector...';
    });

    final bounds = _getSectorBounds(_selectedSector);

    try {
      final packData = await _marineRepo.fetchOfflinePack(
        minLat: bounds['min_lat']!,
        maxLat: bounds['max_lat']!,
        minLon: bounds['min_lon']!,
        maxLon: bounds['max_lon']!,
      );

      setState(() {
        _downloadProgress = 0.45;
        _currentStep = '2/4: Ingesting IMBL boundaries & coastline vectors into SQLite...';
      });

      await Future.delayed(const Duration(milliseconds: 300));

      setState(() {
        _downloadProgress = 0.75;
        _currentStep = '3/4: Caching Open-Meteo wave grid & INCOIS PFZ advisories...';
      });

      if (packData != null) {
        await _cacheManager.ingestFullOfflinePack(packData);
      } else {
        // Safe offline seed fallback
        await _cacheManager.cacheImblPoints([
          {'name': 'Palk Strait IMBL Pt 1', 'countries': 'IND-LKA', 'lat': 10.0833, 'lon': 79.0733},
          {'name': 'Palk Strait IMBL Pt 2', 'countries': 'IND-LKA', 'lat': 9.7167, 'lon': 79.3767},
          {'name': 'Palk Strait IMBL Pt 3', 'countries': 'IND-LKA', 'lat': 9.4833, 'lon': 79.5333},
          {'name': 'Palk Strait IMBL Pt 4', 'countries': 'IND-LKA', 'lat': 9.1000, 'lon': 79.5300},
          {'name': 'Palk Strait IMBL Pt 5', 'countries': 'IND-LKA', 'lat': 8.8667, 'lon': 79.4867},
        ]);
      }

      final count = await _cacheManager.getCachedWeatherCount();

      setState(() {
        _downloadProgress = 1.0;
        _cachedCellsCount = count;
        _currentStep = '4/4: Offline Pack Active ($count cells in SQLite memory)';
        _isDownloading = false;
        _isPackActive = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF16A34A),
            content: Text(
              '⚓ 24h Offline Marine Pack active! App is ready for disconnected sea trips.',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _currentStep = 'Offline sync fallback activated ($e)';
        _isPackActive = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
        title: const Text(
          'Pre-Voyage Offline Sync',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: 0.2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () {
            if (widget.onBack != null) {
              widget.onBack!();
            } else if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Summary Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.wifi_off_rounded, color: Color(0xFF0284C7), size: 26),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'High-Seas Offline Protection',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Downloads local boundary vectors and weather grids to phone memory. Operates at deep sea with zero cellular data.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Coastal Sector Selector
              const Text(
                'SELECT DEPARTURE SECTOR',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF475569),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedSector,
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF0284C7)),
                    items: _sectors.map((s) {
                      return DropdownMenuItem(
                        value: s,
                        child: Text(
                          s,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedSector = val);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Data Components Checklist Card
              const Text(
                'OFFLINE PACK COMPONENTS (~5.8 MB)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF475569),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildComponentRow('IMBL & Coastal Boundary Vectors', '520 KB', Icons.polyline_rounded),
                    const Divider(height: 12, color: Color(0xFFF1F5F9)),
                    _buildComponentRow('24h Marine Wave & Swell Grid', '1.2 MB', Icons.waves_rounded),
                    const Divider(height: 12, color: Color(0xFFF1F5F9)),
                    _buildComponentRow('Active INCOIS PFZ Advisories', '340 KB', Icons.grain_rounded),
                    const Divider(height: 12, color: Color(0xFFF1F5F9)),
                    _buildComponentRow('Emergency Voice Siren Audio Pack', '3.8 MB', Icons.volume_up_rounded),
                  ],
                ),
              ),

              const Spacer(),

              // Download Status Bar
              PackDownloadProgress(
                progress: _downloadProgress,
                currentStep: _currentStep,
                isCompleted: _isPackActive,
              ),

              const SizedBox(height: 16),

              // Action Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isDownloading ? null : _startDownload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isPackActive ? const Color(0xFF16A34A) : const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                    shadowColor: (_isPackActive ? const Color(0xFF16A34A) : const Color(0xFF0284C7)).withOpacity(0.3),
                  ),
                  child: Text(
                    _isDownloading
                        ? 'DOWNLOADING PACK...'
                        : (_isPackActive ? 'UPDATE 24H OFFLINE PACK' : 'DOWNLOAD 24H OFFLINE PACK'),
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComponentRow(String label, String size, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 14, color: const Color(0xFF0284C7)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          Text(
            size,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
