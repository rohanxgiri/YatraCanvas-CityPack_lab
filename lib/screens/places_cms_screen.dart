import 'package:flutter/material.dart';
import '../app/app_state.dart';
import '../domain/curation/curated_place.dart';
import '../widgets/curation/add_place_wizard_dialog.dart';
import 'curated_place_detail_screen.dart';

class PlacesCmsScreen extends StatefulWidget {
  final AppState state;

  const PlacesCmsScreen({super.key, required this.state});

  @override
  State<PlacesCmsScreen> createState() => _PlacesCmsScreenState();
}

class _PlacesCmsScreenState extends State<PlacesCmsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _activeFilter = 'all';
  String? _selectedCategory;
  List<CuratedPlace> _places = [];
  bool _isLoading = true;

  final Map<String, String> _filters = {
    'all': 'All Places',
    'needs_attention': 'Needs Attention',
    'core': 'Core Destinations',
    'manually_edited': 'Manually Edited',
    'added_manually': 'Added Manually',
    'missing_image': 'Missing Photos',
    'missing_hours': 'Missing Hours',
    'location_issue': 'Location Issues',
    'excluded': 'Excluded Places',
  };

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadPlaces() async {
    setState(() => _isLoading = true);
    final results = await widget.state.getCuratedPlaces(
      query: _searchController.text.trim(),
      filter: _activeFilter,
      category: _selectedCategory,
      limit: 100,
    );

    if (mounted) {
      setState(() {
        _places = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final packName = widget.state.activePack?.name ?? 'City';

    return Scaffold(
      body: Column(
        children: [
          // Search & Action Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search $packName places by name...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    _loadPlaces();
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onSubmitted: (_) => _loadPlaces(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_location_alt, size: 18),
                      label: const Text('+ Add Place'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: () {
                        AddPlaceWizardDialog.show(
                          context,
                          cityId: widget.state.activePack!.id,
                          bbox: widget.state.qualityStats?['bbox'] as Map<String, dynamic>?,
                          onAdd: (addition) async {
                            await widget.state.addManualPlace(addition);
                            _loadPlaces();
                          },
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Quick Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.entries.map((f) {
                      final selected = _activeFilter == f.key;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          selected: selected,
                          label: Text(f.value, style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                          selectedColor: Colors.indigo.shade100,
                          onSelected: (_) {
                            setState(() => _activeFilter = f.key);
                            _loadPlaces();
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Count bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            color: Colors.grey.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_places.length} places displayed',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                ),
                Text(
                  'Tap any place to inspect provenance or correct details',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),

          // List of Places
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _places.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off, size: 48, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text('No places found matching "${_filters[_activeFilter]}"', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            const Text('Try adjusting filters or search query', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _places.length,
                        separatorBuilder: (ctx, idx) => const Divider(height: 1),
                        itemBuilder: (ctx, index) {
                          final p = _places[index];
                          return _buildPlaceTile(p);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceTile(CuratedPlace place) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: place.hasImage ? Colors.teal.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          place.hasImage ? Icons.image : Icons.image_not_supported_outlined,
          color: place.hasImage ? Colors.teal : Colors.grey,
          size: 22,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              place.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                decoration: place.isExcluded ? TextDecoration.lineThrough : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _buildStatusBadge(place),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            '${place.category.toUpperCase()} • ${place.tier.replaceAll('_', ' ')}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.access_time, size: 12, color: place.hasOpeningHours ? Colors.green : Colors.red),
              const SizedBox(width: 4),
              Text(
                place.openingHours ?? 'Missing hours',
                style: TextStyle(fontSize: 10, color: place.hasOpeningHours ? Colors.black87 : Colors.red.shade800),
              ),
            ],
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CuratedPlaceDetailScreen(place: place, state: widget.state),
          ),
        );
        _loadPlaces(); // Reload on return
      },
    );
  }

  Widget _buildStatusBadge(CuratedPlace place) {
    if (place.isExcluded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(4)),
        child: const Text('EXCLUDED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red)),
      );
    }
    if (place.isManuallyAdded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.purple.shade100, borderRadius: BorderRadius.circular(4)),
        child: const Text('MANUAL ADD', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.purple)),
      );
    }
    if (place.isManuallyEdited) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(4)),
        child: const Text('CURATED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green)),
      );
    }
    if (!place.hasImage || !place.hasOpeningHours) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(4)),
        child: const Text('INCOMPLETE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(4)),
      child: const Text('READY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.teal)),
    );
  }
}
