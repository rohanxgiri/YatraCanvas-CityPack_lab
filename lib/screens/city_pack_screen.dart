import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../app/app_state.dart';
import '../domain/city_pack.dart';
import '../widgets/offline_badge.dart';
import 'city_lab_home_screen.dart';
import 'diagnostics_screen.dart';

class CityPackScreen extends StatelessWidget {
  final AppState state;

  const CityPackScreen({super.key, required this.state});

  void _openPack(BuildContext context, CityPack pack) async {
    if (!pack.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot open invalid pack: ${pack.invalidReason}'),
          backgroundColor: Colors.red.shade800,
        ),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading City Pack SQLite Database...'),
                ],
              ),
            ),
          ),
        ),
      );

      await state.openPack(pack);
      if (context.mounted) {
        Navigator.of(context).pop(); // Dismiss loading dialog
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CityLabHomeScreen(state: state),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading pack: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  void _showPackMetadata(BuildContext context, CityPack pack) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.indigo),
                  const SizedBox(width: 8),
                  Text(
                    '${pack.name} Pack Metadata',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Divider(height: 24),
              _metaTile('City ID', pack.id),
              _metaTile('State / Country', '${pack.state}, ${pack.country}'),
              _metaTile('Pack Version', pack.version),
              _metaTile('Integrity Status', pack.integrityStatus.name.toUpperCase()),
              _metaTile('Place Count', '${pack.placeCount} places'),
              _metaTile('Images with Local Files', '${pack.imageCount} images'),
              _metaTile('Database Size', '${pack.dbSizeMb} MB'),
              _metaTile('Center Coordinates',
                  '${pack.centerLat.toStringAsFixed(5)}, ${pack.centerLon.toStringAsFixed(5)}'),
              _metaTile('Bounding Box (W, S, E, N)',
                  '[${pack.minLon.toStringAsFixed(3)}, ${pack.minLat.toStringAsFixed(3)}, ${pack.maxLon.toStringAsFixed(3)}, ${pack.maxLat.toStringAsFixed(3)}]'),
              const SizedBox(height: 16),
              if (pack.receipt.isNotEmpty) ...[
                const Text('Lab Sync Receipt:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    pack.receipt.toString(),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CITY PACK LAB',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Manual Real-Flow QA Suite',
                style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: OfflineBadge(
              isStrictOffline: state.strictOfflineMode,
              onTap: () => state.toggleStrictOffline(!state.strictOfflineMode),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Network Transparency & Diagnostics',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DiagnosticsScreen(state: state),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload Packs',
            onPressed: () => state.loadPacks(),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          if (state.isLoadingPacks) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Discovering City Packs...'),
                ],
              ),
            );
          }

          if (state.packLoadError != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: Colors.red.shade700),
                    const SizedBox(height: 16),
                    Text(
                      state.packLoadError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => state.loadPacks(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state.availablePacks.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 56, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text(
                      'No City Packs Synchronized',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Run tools/sync_city_packs.py to import valid production packs from YatraCanvas-DataFactory.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Check Assets Again'),
                      onPressed: () => state.loadPacks(),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (kIsWeb)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.language, color: Colors.blue.shade800),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Web Browser Mode (WASM SQLite): City Packs queryable directly inside Chrome via WebAssembly SQLite.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.indigo.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified_user_outlined,
                        color: Colors.indigo.shade700),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Testing DataFactory City Packs in Read-Only Mode. Choose a city to begin realistic manual testing.',
                        style: TextStyle(
                            fontSize: 12, color: Colors.indigo.shade900),
                      ),
                    ),
                  ],
                ),
              ),
              ...state.availablePacks.map((pack) => _buildPackCard(context, pack)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPackCard(BuildContext context, CityPack pack) {
    final bool isPass = pack.integrityStatus == IntegrityStatus.pass;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pack.name,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${pack.state}, ${pack.country}',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPass ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color:
                          isPass ? Colors.green.shade600 : Colors.red.shade600,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPass ? Icons.check_circle : Icons.warning_amber,
                        size: 14,
                        color: isPass
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Integrity: ${pack.integrityStatus.name.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isPass
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statItem(
                    'Places',
                    '${pack.placeCount}',
                    Icons.place_outlined),
                _statItem(
                    'Images',
                    '${pack.imageCount}',
                    Icons.image_outlined),
                _statItem(
                    'DB Size',
                    '${pack.dbSizeMb} MB',
                    Icons.storage_outlined),
                _statItem(
                    'Version',
                    pack.version,
                    Icons.tag),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showPackMetadata(context, pack),
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text('Metadata'),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _openPack(context, pack),
                  icon: const Icon(Icons.travel_explore),
                  label: const Text('Open Pack'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }
}
