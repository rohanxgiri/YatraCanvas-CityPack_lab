import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../app/app_state.dart';
import '../domain/lab_place.dart';
import '../widgets/offline_badge.dart';
import 'place_detail_screen.dart';

class MapScreen extends StatefulWidget {
  final AppState state;
  final LabPlace? initialFocusPlace;
  final List<LabPlace>? initialPlaces;

  const MapScreen({
    super.key,
    required this.state,
    this.initialFocusPlace,
    this.initialPlaces,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  List<LabPlace> _places = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  String _selectedTier = 'All';
  LabPlace? _selectedPlace;

  // Mode: Online Tiles vs Offline Coordinate Canvas
  late bool _useOnlineTiles;

  @override
  void initState() {
    super.initState();
    _useOnlineTiles = !widget.state.strictOfflineMode;
    if (widget.initialFocusPlace != null) {
      _selectedPlace = widget.initialFocusPlace;
    }
    _loadPlaces();
  }

  void _loadPlaces() async {
    if (widget.initialPlaces != null) {
      setState(() {
        _places = widget.initialPlaces!;
        _isLoading = false;
      });
      return;
    }

    final repo = widget.state.repository;
    if (repo == null) return;

    setState(() => _isLoading = true);
    final places = await repo.getForMap(
      category: _selectedCategory == 'All' ? null : _selectedCategory.toLowerCase(),
      tier: _selectedTier == 'All' ? null : _selectedTier.toLowerCase(),
      limit: 600,
    );

    if (mounted) {
      setState(() {
        _places = places;
        _isLoading = false;
      });
    }
  }

  Color _getMarkerColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'core_destination':
        return Colors.amber.shade800;
      case 'recommended':
        return Colors.blue.shade700;
      case 'discovery':
        return Colors.teal.shade700;
      case 'support':
      default:
        return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pack = widget.state.activePack;
    final centerLat = widget.initialFocusPlace?.latitude ?? pack?.centerLat ?? 20.5937;
    final centerLon = widget.initialFocusPlace?.longitude ?? pack?.centerLon ?? 78.9629;

    // Strict offline mode overrides toggle
    final bool effectiveOnlineTiles = _useOnlineTiles && !widget.state.strictOfflineMode;

    return Scaffold(
      appBar: AppBar(
        title: Text('${pack?.name ?? "City"} Geographic Map'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: OfflineBadge(
              isStrictOffline: widget.state.strictOfflineMode,
              onTap: () {
                widget.state.toggleStrictOffline(!widget.state.strictOfflineMode);
                setState(() {});
              },
            ),
          ),
          IconButton(
            icon: Icon(effectiveOnlineTiles ? Icons.layers : Icons.layers_clear),
            tooltip: effectiveOnlineTiles ? 'Switch to Offline Canvas' : 'Enable OSM Tiles',
            onPressed: () {
              if (widget.state.strictOfflineMode) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Strict Offline Mode is Active. Network map tiles are blocked.'),
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
              setState(() => _useOnlineTiles = !_useOnlineTiles);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // FlutterMap
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(centerLat, centerLon),
              initialZoom: widget.initialFocusPlace != null ? 14 : 12,
              minZoom: 4,
              maxZoom: 18,
            ),
            children: [
              // Online Tile Layer or Strict Offline Canvas
              if (effectiveOnlineTiles)
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.yatracanvas.lab',
                )
              else
                // Strict Offline Grid Canvas
                _buildOfflineCanvasBackground(pack),

              // Markers Layer from City Pack ONLY
              MarkerLayer(
                markers: _places.map((place) {
                  final isSelected = _selectedPlace?.id == place.id;
                  final color = _getMarkerColor(place.tier);

                  return Marker(
                    point: LatLng(place.latitude, place.longitude),
                    width: isSelected ? 42 : 32,
                    height: isSelected ? 42 : 32,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedPlace = place);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: isSelected ? 3 : 1.5,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            )
                          ],
                        ),
                        child: Icon(
                          isSelected ? Icons.location_on : Icons.place,
                          color: Colors.white,
                          size: isSelected ? 24 : 18,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // Top filter chips
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('All Tiers', _selectedTier == 'All', () {
                    _selectedTier = 'All';
                    _loadPlaces();
                  }),
                  _filterChip('Core', _selectedTier == 'core_destination', () {
                    _selectedTier = 'core_destination';
                    _loadPlaces();
                  }),
                  _filterChip('Recommended', _selectedTier == 'recommended', () {
                    _selectedTier = 'recommended';
                    _loadPlaces();
                  }),
                  _filterChip('Discovery', _selectedTier == 'discovery', () {
                    _selectedTier = 'discovery';
                    _loadPlaces();
                  }),
                  const SizedBox(width: 8),
                  Container(height: 20, width: 1, color: Colors.grey.shade400),
                  const SizedBox(width: 8),
                  _filterChip('All Categories', _selectedCategory == 'All', () {
                    _selectedCategory = 'All';
                    _loadPlaces();
                  }),
                  _filterChip('Heritage', _selectedCategory == 'heritage', () {
                    _selectedCategory = 'heritage';
                    _loadPlaces();
                  }),
                  _filterChip('Food & Cafe', _selectedCategory == 'food', () {
                    _selectedCategory = 'food';
                    _loadPlaces();
                  }),
                  _filterChip('Nature', _selectedCategory == 'nature', () {
                    _selectedCategory = 'nature';
                    _loadPlaces();
                  }),
                  _filterChip('Religious', _selectedCategory == 'religious', () {
                    _selectedCategory = 'religious';
                    _loadPlaces();
                  }),
                ],
              ),
            ),
          ),

          // Bottom Preview Card if a place is selected
          if (_selectedPlace != null)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _selectedPlace!.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_selectedPlace!.tier.toUpperCase()} • ${_selectedPlace!.category}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                            Text(
                              'Lat: ${_selectedPlace!.latitude.toStringAsFixed(4)}, Lon: ${_selectedPlace!.longitude.toStringAsFixed(4)}',
                              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _selectedPlace = null),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PlaceDetailScreen(
                                place: _selectedPlace!,
                                state: widget.state,
                              ),
                            ),
                          );
                        },
                        child: const Text('Inspect'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (_isLoading)
            const Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('Loading map coordinates from pack...'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOfflineCanvasBackground(dynamic pack) {
    return Container(
      color: const Color(0xFFF1F5F9), // Subtle slate background
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.grid_4x4, size: 64, color: Colors.blueGrey.shade200),
            const SizedBox(height: 8),
            Text(
              'STRICT OFFLINE COORDINATE CANVAS',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey.shade700,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No remote tiles requested. Showing geographic POI distribution.',
              style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool isSelected, VoidCallback onSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: isSelected,
        backgroundColor: Colors.white,
        selectedColor: Colors.indigo.shade100,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}
