import 'package:flutter/material.dart';
import '../app/app_state.dart';
import '../domain/lab_place.dart';
import '../widgets/place_card.dart';
import '../widgets/report_problem_dialog.dart';
import 'place_detail_screen.dart';

class CategoryScreen extends StatefulWidget {
  final AppState state;

  const CategoryScreen({super.key, required this.state});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  Map<String, int> _categories = {};
  String _selectedCategory = 'all';
  String _sortBy = 'priority'; // priority, name, tier, relevance
  bool _onlyTravelRelevant = false;
  List<LabPlace> _places = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategoriesAndPlaces();
  }

  void _loadCategoriesAndPlaces() async {
    final repo = widget.state.repository;
    if (repo == null) return;

    setState(() => _isLoading = true);
    final cats = await repo.getCategories(onlyTravelRelevant: _onlyTravelRelevant);
    final places = await repo.getByCategory(
      category: _selectedCategory,
      sortBy: _sortBy,
      onlyTravelRelevant: _onlyTravelRelevant,
      limit: 100,
    );

    if (mounted) {
      setState(() {
        _categories = cats;
        _places = places;
        _isLoading = false;
      });
    }
  }

  void _selectCategory(String cat) async {
    setState(() {
      _selectedCategory = cat;
      _isLoading = true;
    });

    final repo = widget.state.repository;
    if (repo == null) return;

    final places = await repo.getByCategory(
      category: cat,
      sortBy: _sortBy,
      onlyTravelRelevant: _onlyTravelRelevant,
      limit: 100,
    );

    if (mounted) {
      setState(() {
        _places = places;
        _isLoading = false;
      });
    }
  }

  void _changeSort(String sort) async {
    setState(() {
      _sortBy = sort;
      _isLoading = true;
    });

    final repo = widget.state.repository;
    if (repo == null) return;

    final places = await repo.getByCategory(
      category: _selectedCategory,
      sortBy: sort,
      onlyTravelRelevant: _onlyTravelRelevant,
      limit: 100,
    );

    if (mounted) {
      setState(() {
        _places = places;
        _isLoading = false;
      });
    }
  }

  void _toggleTravelRelevant(bool value) async {
    setState(() {
      _onlyTravelRelevant = value;
      _isLoading = true;
    });
    _loadCategoriesAndPlaces();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Category Browser'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort By',
            onSelected: _changeSort,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'priority', child: Text('Default (Priority)')),
              const PopupMenuItem(value: 'name', child: Text('Name (A–Z)')),
              const PopupMenuItem(value: 'tier', child: Text('Tier (Core first)')),
              const PopupMenuItem(value: 'relevance', child: Text('Travel Relevance')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter bar: Travel-relevant toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                Text(
                  _onlyTravelRelevant
                      ? 'Showing: Only Travel-Relevant (> 0.0)'
                      : 'Showing: All Records in Dataset (QA View)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _onlyTravelRelevant ? Colors.indigo : Colors.deepOrange.shade800,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: _onlyTravelRelevant,
                  activeTrackColor: Colors.indigo.shade200,
                  activeThumbColor: Colors.indigo,
                  onChanged: _toggleTravelRelevant,
                ),
              ],
            ),
          ),

          // Categories horizontal list / chips
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: const Text('ALL CATEGORIES', style: TextStyle(fontSize: 11)),
                    selected: _selectedCategory == 'all',
                    onSelected: (_) => _selectCategory('all'),
                  ),
                ),
                ..._categories.entries.map((entry) {
                  final cat = entry.key;
                  final count = entry.value;
                  final isSelected = _selectedCategory == cat;

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(
                        '${cat.toUpperCase()} ($count)',
                        style: const TextStyle(fontSize: 11),
                      ),
                      selected: isSelected,
                      onSelected: (_) => _selectCategory(cat),
                    ),
                  );
                }),
              ],
            ),
          ),

          // Results count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  '${_places.length} places in ${_selectedCategory.toUpperCase()}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const Spacer(),
                Text(
                  'Sort: $_sortBy',
                  style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600),
                ),
              ],
            ),
          ),

          // Places list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _places.isEmpty
                    ? Center(
                        child: Text(
                          'No places in this category under current filters.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _places.length,
                        itemBuilder: (context, index) {
                          final place = _places[index];
                          final isInTrip = widget.state.tripSelection?.contains(place.id) ?? false;

                          return PlaceCard(
                            place: place,
                            repository: widget.state.repository!,
                            isInTrip: isInTrip,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PlaceDetailScreen(
                                    place: place,
                                    state: widget.state,
                                  ),
                                ),
                              );
                            },
                            onToggleTrip: () {
                              if (isInTrip) {
                                widget.state.removePlaceFromTrip(place.id);
                              } else {
                                widget.state.addPlaceToTrip(place.id);
                              }
                              setState(() {});
                            },
                            onReport: () {
                              ReportProblemDialog.show(
                                context,
                                place: place,
                                packVersion: widget.state.activePack?.version ?? 'v3',
                                onSubmit: (issue) => widget.state.reportIssue(issue),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
