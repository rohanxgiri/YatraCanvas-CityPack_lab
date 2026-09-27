import 'package:flutter/material.dart';
import '../app/app_state.dart';
import '../domain/lab_place.dart';
import '../widgets/place_card.dart';
import '../widgets/report_problem_dialog.dart';
import '../widgets/offline_badge.dart';
import 'place_detail_screen.dart';
import 'search_screen.dart';
import 'category_screen.dart';
import 'map_screen.dart';
import 'random_review_screen.dart';
import 'expected_places_screen.dart';
import 'test_trip_screen.dart';
import 'scenario_testing_screen.dart';
import 'qa_dashboard_screen.dart';
import 'diagnostics_screen.dart';

class DiscoverScreen extends StatefulWidget {
  final AppState state;

  const DiscoverScreen({super.key, required this.state});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  String _selectedTierFilter = 'All';
  Map<String, List<LabPlace>> _sections = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  void _loadFeed() async {
    final repo = widget.state.repository;
    if (repo == null) return;

    setState(() => _isLoading = true);
    final sections = await repo.getDiscoverSections(
      interests: widget.state.userInterests.toList(),
      limitPerSection: 25,
    );

    if (mounted) {
      setState(() {
        _sections = sections;
        _isLoading = false;
      });
    }
  }

  void _openDetail(LabPlace place) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlaceDetailScreen(
          place: place,
          state: widget.state,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pack = widget.state.activePack;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pack?.name ?? 'Discover Places',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('${pack?.state} • Discover Feed',
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: OfflineBadge(
              isStrictOffline: widget.state.strictOfflineMode,
              onTap: () => widget.state
                  .toggleStrictOffline(!widget.state.strictOfflineMode),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search Places',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SearchScreen(state: widget.state),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Geographic Map',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MapScreen(state: widget.state),
                ),
              );
            },
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filter bar: All, Core, Recommended, Discovery
                Container(
                  color: Colors.grey.shade100,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'Core', 'Recommended', 'Discovery']
                          .map((tier) {
                        final isSelected = _selectedTierFilter == tier;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(tier),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedTierFilter = tier);
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async => _loadFeed(),
                    child: ListView(
                      padding: const EdgeInsets.only(top: 8, bottom: 24),
                      children: _buildSectionWidgets(),
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.indigo,
        unselectedItemColor: Colors.grey.shade600,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.explore), label: 'Discover'),
          BottomNavigationBarItem(
              icon: Icon(Icons.category), label: 'Categories'),
          BottomNavigationBarItem(
              icon: Icon(Icons.shuffle), label: 'Random QA'),
          BottomNavigationBarItem(
              icon: Icon(Icons.luggage), label: 'Test Trip'),
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard), label: 'QA Stats'),
        ],
        onTap: (index) {
          if (index == 0) return;
          if (index == 1) {
            Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => CategoryScreen(state: widget.state)),
            );
          } else if (index == 2) {
            Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => RandomReviewScreen(state: widget.state)),
            );
          } else if (index == 3) {
            Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => TestTripScreen(state: widget.state)),
            );
          } else if (index == 4) {
            Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => QaDashboardScreen(state: widget.state)),
            );
          }
        },
      ),
    );
  }

  List<Widget> _buildSectionWidgets() {
    final List<Widget> widgets = [];

    for (final entry in _sections.entries) {
      final sectionTitle = entry.key;
      List<LabPlace> places = entry.value;

      // Apply tier filter
      if (_selectedTierFilter == 'Core') {
        places = places
            .where((p) => p.tier.toLowerCase() == 'core_destination')
            .toList();
      } else if (_selectedTierFilter == 'Recommended') {
        places =
            places.where((p) => p.tier.toLowerCase() == 'recommended').toList();
      } else if (_selectedTierFilter == 'Discovery') {
        places =
            places.where((p) => p.tier.toLowerCase() == 'discovery').toList();
      }

      if (places.isEmpty) continue;

      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(
                sectionTitle,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${places.length}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
        ),
      );

      for (final place in places) {
        final isInTrip =
            widget.state.tripSelection?.contains(place.id) ?? false;
        widgets.add(
          PlaceCard(
            place: place,
            repository: widget.state.repository!,
            isInTrip: isInTrip,
            onTap: () => _openDetail(place),
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
          ),
        );
      }
    }

    if (widgets.isEmpty) {
      widgets.add(
        const Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: Text('No places matched current filters in this pack.'),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildDrawer(BuildContext context) {
    final pack = widget.state.activePack;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.indigo),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  'CITY PACK LAB',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Active: ${pack?.name ?? "None"} (${pack?.version})',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  '${pack?.placeCount ?? 0} Places • Read-Only SQLite',
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.location_city),
            title: const Text('Change City Pack'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('Natural Search & Review'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => SearchScreen(state: widget.state)),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('Category Browser'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => CategoryScreen(state: widget.state)),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.map),
            title: const Text('Geographic Inspection Map'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => MapScreen(state: widget.state)),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.shuffle),
            title: const Text('Review Random Places (QA)'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) =>
                        RandomReviewScreen(state: widget.state)),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.find_in_page_outlined),
            title: const Text('Expected Places Check'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) =>
                        ExpectedPlacesScreen(state: widget.state)),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.luggage),
            title: const Text('Test Trip Basket & Map'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => TestTripScreen(state: widget.state)),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.checklist_rtl),
            title: const Text('Realistic QA Scenario Testing'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) =>
                        ScenarioTestingScreen(state: widget.state)),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.dashboard_customize),
            title: const Text('QA Dataset Dashboard & Export'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) =>
                        QaDashboardScreen(state: widget.state)),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.analytics_outlined),
            title: const Text('Diagnostics & Transparency'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => DiagnosticsScreen(state: widget.state)),
              );
            },
          ),
        ],
      ),
    );
  }
}
