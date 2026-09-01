import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/local/offline_cache_manager.dart';
import 'widgets/pack_download_progress.dart';

class PreVoyageScreen extends StatefulWidget {
  const PreVoyageScreen({super.key});

  @override
  State<PreVoyageScreen> createState() => _PreVoyageScreenState();
}

class _PreVoyageScreenState extends State<PreVoyageScreen> {
  final OfflineCacheManager _cacheManager = OfflineCacheManager();

  String _selectedSector = 'Palk Strait (Rameswaram)';
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _currentStep = 'Ready to download regional marine pack';
  bool _isPackActive = false;

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
    setState(() {
      _isPackActive = hasPack;
      if (hasPack) {
        _downloadProgress = 1.0;
        _currentStep = '24-Hour Offline Marine Pack Active';
      }
    });
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.1;
      _currentStep = '1/4: Ingesting IMBL & Coastline GeoJSON (520 KB)...';
    });

    await Future.delayed(const Duration(milliseconds: 600));

    // Seed mock IMBL coordinates into SQLite
    await _cacheManager.cacheImblPoints([
      {'name': 'Palk Strait IMBL Pt 1', 'countries': 'IND-LKA', 'lat': 10.0833, 'lon': 79.0733},
      {'name': 'Palk Strait IMBL Pt 2', 'countries': 'IND-LKA', 'lat': 9.7167, 'lon': 79.3767},
      {'name': 'Palk Strait IMBL Pt 3', 'countries': 'IND-LKA', 'lat': 9.4833, 'lon': 79.5333},
      {'name': 'Palk Strait IMBL Pt 4', 'countries': 'IND-LKA', 'lat': 9.1000, 'lon': 79.5300},
      {'name': 'Palk Strait IMBL Pt 5', 'countries': 'IND-LKA', 'lat': 8.8667, 'lon': 79.4867},
    ]);

    setState(() {
      _downloadProgress = 0.45;
      _currentStep = '2/4: Ingesting 24-Hour Open-Meteo Wave & Wind Grid (1.2 MB)...';
    });

    await Future.delayed(const Duration(milliseconds: 600));

    setState(() {
      _downloadProgress = 0.75;
      _currentStep = '3/4: Parsing INCOIS Chlorophyll & PFZ Advisories (340 KB)...';
    });

    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _downloadProgress = 1.0;
      _currentStep = '4/4: Pre-caching Regional Voice Emergency Audio Clips (3.8 MB)...';
      _isDownloading = false;
      _isPackActive = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.abyssBlack,
      appBar: AppBar(
        backgroundColor: AppColors.deepOcean,
        title: const Text('Pre-Voyage Offline Sync'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.radarCyan),
          onPressed: () => Navigator.pop(context),
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
                  color: AppColors.deepOcean,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.wifi_off_outlined, color: AppColors.radarCyan, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'High-Seas Offline Protection',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Downloads local boundary vectors and weather grids to phone memory. Operates at deep sea with zero cellular data.',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.marineSurface.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedSector,
                    isExpanded: true,
                    dropdownColor: AppColors.deepOcean,
                    icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.radarCyan),
                    items: _sectors.map((s) {
                      return DropdownMenuItem(
                        value: s,
                        child: Text(s, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedSector = val);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Data Components Checklist
              const Text(
                'OFFLINE PACK COMPONENTS (~5.8 MB)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8),
              ),
              const SizedBox(height: 8),
              _buildComponentRow('IMBL & Coastal Boundary Vectors', '520 KB', Icons.polyline),
              _buildComponentRow('24h Marine Wave & Swell Grid', '1.2 MB', Icons.waves),
              _buildComponentRow('Active INCOIS PFZ Advisories', '340 KB', Icons.grain),
              _buildComponentRow('Emergency Voice Siren Audio Pack', '3.8 MB', Icons.volume_up),

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
                    backgroundColor: _isPackActive ? AppColors.bioGreen : AppColors.radarCyan,
                    foregroundColor: AppColors.abyssBlack,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(
                    _isDownloading
                        ? 'DOWNLOADING PACK...'
                        : (_isPackActive ? 'UPDATE 24H OFFLINE PACK' : 'DOWNLOAD 24H OFFLINE PACK'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.8),
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
          Icon(icon, size: 14, color: AppColors.radarCyan),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
          ),
          Text(
            size,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}
