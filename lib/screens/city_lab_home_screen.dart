import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../app/lab_theme.dart';
import 'curation_review_screen.dart';
import 'diagnostics_screen.dart';
import 'fix_center_screen.dart';
import 'home_screen.dart';
import 'places_cms_screen.dart';
import 'release_gate_screen.dart';

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

  void _showPrSummaryDialog() {
    final packName = widget.state.activePack?.name ?? 'City';
    final summaryMd = widget.state.curationService.generatePrSummary(packName);
    final summary = widget.state.curationService.getSummary();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.commit, color: Colors.indigo),
            const SizedBox(width: 8),
            Text(
              '$packName Curation Summary (For PR)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Human curation changes saved to assets/city_packs/<city>/curation/:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _statPill(
                        'Overrides',
                        '${summary.totalOverrides} places',
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _statPill(
                        'Additions',
                        '${summary.totalAdditions} places',
                        Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _statPill(
                        'Exclusions',
                        '${summary.totalExclusions} places',
                        Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SelectableText(
                    summaryMd,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy PR Markdown'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: summaryMd));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied PR curation summary to clipboard!'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showContributorProfileDialog() {
    final controller = TextEditingController(
      text: widget.state.contributorName,
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Contributor Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your name or GitHub handle to sign curation records:',
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Contributor Name',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.state.setContributorName(controller.text);
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _statPill(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pack = widget.state.activePack;
    if (pack == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('YatraCanvas City Lab')),
        body: const Center(child: Text('No city pack active.')),
      );
    }

    final pages = [
      HomeScreen(
        state: widget.state,
        onNavigateToFix: () => _navigateToTab(1),
        onNavigateToReview: () => _navigateToTab(2),
        onNavigateToPlaces: () => _navigateToTab(3),
        onNavigateToRelease: () => _navigateToTab(4),
      ),
      FixCenterScreen(state: widget.state),
      CurationReviewScreen(state: widget.state),
      PlacesCmsScreen(state: widget.state),
      ReleaseGateScreen(state: widget.state),
      if (widget.state.isAdminMode) DiagnosticsScreen(state: widget.state),
    ];

    if (_currentIndex >= pages.length) {
      _currentIndex = 0;
    }

    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Home',
      ),
      const NavigationDestination(
        icon: Icon(Icons.build_outlined),
        selectedIcon: Icon(Icons.build),
        label: 'Fix',
      ),
      const NavigationDestination(
        icon: Icon(Icons.rate_review_outlined),
        selectedIcon: Icon(Icons.rate_review),
        label: 'Review',
      ),
      const NavigationDestination(
        icon: Icon(Icons.place_outlined),
        selectedIcon: Icon(Icons.place),
        label: 'Places',
      ),
      const NavigationDestination(
        icon: Icon(Icons.verified_outlined),
        selectedIcon: Icon(Icons.verified),
        label: 'Release',
      ),
      if (widget.state.isAdminMode)
        const NavigationDestination(
          icon: Icon(Icons.analytics_outlined),
          selectedIcon: Icon(Icons.analytics),
          label: 'Advanced',
        ),
    ];
    final useRail = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  pack.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: LabPalette.saffronSoft,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'v${pack.version}',
                    style: TextStyle(
                      color: LabPalette.inkStrong,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Text(
              'YatraCanvas City Pack Curation Studio',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          // Mode switch pill (Contributor vs Admin)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: widget.state.isAdminMode
                  ? LabPalette.saffron
                  : LabPalette.teal,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: InkWell(
              onTap: () {
                widget.state.toggleAdminMode();
                setState(() {});
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.state.isAdminMode
                        ? Icons.admin_panel_settings
                        : Icons.person_outline,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.state.isAdminMode
                        ? 'Admin Mode'
                        : 'Contributor Mode',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          IconButton(
            icon: const Icon(Icons.commit),
            tooltip: 'View PR Curation Summary',
            onPressed: _showPrSummaryDialog,
          ),
          IconButton(
            icon: const Icon(Icons.badge_outlined),
            tooltip: 'Contributor Profile (${widget.state.contributorName})',
            onPressed: _showContributorProfileDialog,
          ),
        ],
      ),
      body: widget.state.isEvaluatingQuality
          ? const _EvaluationState()
          : useRail
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _currentIndex,
                  extended: true,
                  minExtendedWidth: 214,
                  groupAlignment: -0.78,
                  onDestinationSelected: _navigateToTab,
                  leading: const Padding(
                    padding: EdgeInsets.only(
                      top: LabSpacing.md,
                      bottom: LabSpacing.lg,
                    ),
                    child: Text(
                      'WORKBENCH',
                      style: TextStyle(
                        color: LabPalette.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  destinations: destinations
                      .map(
                        (destination) => NavigationRailDestination(
                          icon: destination.icon,
                          selectedIcon: destination.selectedIcon,
                          label: Text(destination.label),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: pages[_currentIndex]),
              ],
            )
          : pages[_currentIndex],
      bottomNavigationBar: useRail
          ? null
          : NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: _navigateToTab,
              destinations: destinations,
            ),
    );
  }
}

class _EvaluationState extends StatelessWidget {
  const _EvaluationState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: LabSpacing.md),
          Text('Recalculating quality and release gates…'),
        ],
      ),
    );
  }
}
