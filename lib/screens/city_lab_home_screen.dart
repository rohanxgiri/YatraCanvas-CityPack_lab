import 'package:flutter/material.dart';
import '../app/app_state.dart';
import 'overview_screen.dart';
import 'data_coverage_screen.dart';
import 'review_screen.dart';
import 'release_gate_screen.dart';
import 'diagnostics_screen.dart';
import 'discover_screen.dart';
import 'map_screen.dart';
import 'search_screen.dart';

class CityLabHomeScreen extends StatefulWidget {
  final AppState state;
  final int initialTabIndex;

  const CityLabHomeScreen({
    super.key,
    required this.state,
    this.initialTabIndex = 0,
  });

  @override
  State<CityLabHomeScreen> createState() => _CityLabHomeScreenState();
}

class _CityLabHomeScreenState extends State<CityLabHomeScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
  }

  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final pack = widget.state.activePack;
    if (pack == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('City Lab')),
        body: const Center(child: Text('No city pack active.')),
      );
    }

    final pages = [
      OverviewScreen(
        state: widget.state,
        onNavigateToCoverage: () => _navigateToTab(1),
        onNavigateToReview: () => _navigateToTab(2),
        onNavigateToRelease: () => _navigateToTab(3),
      ),
      DataCoverageScreen(state: widget.state),
      ReviewScreen(state: widget.state),
      ReleaseGateScreen(state: widget.state),
      DiagnosticsScreen(state: widget.state),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  pack.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'v${pack.version}',
                    style: TextStyle(
                      color: Colors.indigo.shade900,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Text(
              'YatraCanvas QA & Release Gate System',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search Simulation',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SearchScreen(state: widget.state)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.explore_outlined),
            tooltip: 'Discover Feed Preview',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => DiscoverScreen(state: widget.state)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Geographic Map View',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => MapScreen(state: widget.state)),
              );
            },
          ),
        ],
      ),
      body: widget.state.isEvaluatingQuality
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Calculating Data Quality & Release Gate...'),
                ],
              ),
            )
          : pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _navigateToTab,
        indicatorColor: Colors.indigo.shade100,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: Colors.indigo),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view, color: Colors.indigo),
            label: 'Coverage',
          ),
          NavigationDestination(
            icon: Icon(Icons.rate_review_outlined),
            selectedIcon: Icon(Icons.rate_review, color: Colors.indigo),
            label: 'Review',
          ),
          NavigationDestination(
            icon: Icon(Icons.verified_outlined),
            selectedIcon: Icon(Icons.verified, color: Colors.indigo),
            label: 'Release Gate',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics, color: Colors.indigo),
            label: 'Diagnostics',
          ),
        ],
      ),
    );
  }
}
