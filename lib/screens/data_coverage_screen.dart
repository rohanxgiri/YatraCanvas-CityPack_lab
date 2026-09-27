import 'package:flutter/material.dart';
import '../app/app_state.dart';
import '../domain/lab_place.dart';
import '../quality/models/data_gap_item.dart';
import 'place_detail_screen.dart';

class DataCoverageScreen extends StatefulWidget {
  final AppState state;

  const DataCoverageScreen({super.key, required this.state});

  @override
  State<DataCoverageScreen> createState() => _DataCoverageScreenState();
}

class _DataCoverageScreenState extends State<DataCoverageScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showDrillDownRecords(BuildContext context, DataGapItem gap) async {
    final repo = widget.state.repository;
    if (repo == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (ctx, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      gap.severity == GapSeverity.critical
                          ? Icons.error
                          : (gap.severity == GapSeverity.warning
                              ? Icons.warning_amber
                              : Icons.info_outline),
                      color: gap.severity == GapSeverity.critical
                          ? Colors.red
                          : (gap.severity == GapSeverity.warning ? Colors.orange : Colors.blue),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            gap.title,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${gap.count} records affected • ${gap.reason}',
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: FutureBuilder<List<LabPlace>>(
                  future: gap.filterPreset != null
                      ? repo.getPlacesForGap(gap.filterPreset!, limit: 100)
                      : repo.getPlacesByIds(gap.affectedPlaceIds.take(100).toList()),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error loading records: ${snapshot.error}'));
                    }
                    final places = snapshot.data ?? [];
                    if (places.isEmpty) {
                      return const Center(
                        child: Text('No affected records found in database.'),
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      itemCount: places.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final p = places[index];
                        return ListTile(
                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${p.tier.toUpperCase()} • ${p.category} • (${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)})',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 18),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PlaceDetailScreen(
                                  place: p,
                                  state: widget.state,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Coverage & Gaps'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.indigo,
          labelColor: Colors.indigo,
          unselectedLabelColor: Colors.black54,
          tabs: const [
            Tab(icon: Icon(Icons.table_chart_outlined), text: 'Coverage Matrix'),
            Tab(icon: Icon(Icons.rule_folder_outlined), text: 'Data Gap Analyzer'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCoverageMatrixTab(context),
          _buildGapAnalyzerTab(context),
        ],
      ),
    );
  }

  Widget _buildCoverageMatrixTab(BuildContext context) {
    final matrix = widget.state.categoryCoverageMatrix;
    if (matrix.isEmpty) {
      return const Center(child: Text('No category coverage data available.'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.insights, color: Colors.indigo),
                    SizedBox(width: 8),
                    Text(
                      'CATEGORY COVERAGE BENCHMARK',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Audit completeness of photo assets, operating schedules, coordinates, and contact details across travel categories.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 16,
                    headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
                    columns: const [
                      DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Places', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                      DataColumn(label: Text('Photos', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Hours', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Geo', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Details', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: matrix.map((row) {
                      final total = (row['total'] as int?) ?? 1;
                      final withImg = (row['with_images'] as int?) ?? 0;
                      final withHours = (row['with_hours'] as int?) ?? 0;
                      final withGeo = (row['with_geo'] as int?) ?? 0;
                      final withDetails = (row['with_details'] as int?) ?? 0;

                      final imgPct = ((withImg / total) * 100).round();
                      final hoursPct = ((withHours / total) * 100).round();
                      final geoPct = ((withGeo / total) * 100).round();
                      final detailsPct = ((withDetails / total) * 100).round();

                      return DataRow(cells: [
                        DataCell(Text(
                          (row['category'] as String? ?? 'other').replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                        )),
                        DataCell(Text('$total', style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(_buildPercentCell(imgPct, withImg, total)),
                        DataCell(_buildPercentCell(hoursPct, withHours, total)),
                        DataCell(_buildPercentCell(geoPct, withGeo, total)),
                        DataCell(_buildPercentCell(detailsPct, withDetails, total)),
                      ]);
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPercentCell(int percent, int count, int total) {
    Color color;
    if (percent >= 80) {
      color = Colors.teal;
    } else if (percent >= 40) {
      color = Colors.orange.shade800;
    } else {
      color = Colors.red.shade700;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$percent%',
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildGapAnalyzerTab(BuildContext context) {
    final gaps = widget.state.dataGaps;

    if (gaps.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 48),
              SizedBox(height: 12),
              Text(
                'Zero Critical Gaps Found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text('All verified dataset checks are compliant.'),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'WHAT HAVEN\'T WE GOT? (DATA GAPS)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 0.8),
          ),
        ),
        ...gaps.map((gap) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: gap.severity == GapSeverity.critical
                      ? Colors.red.shade300
                      : (gap.severity == GapSeverity.warning ? Colors.orange.shade300 : Colors.grey.shade300),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            gap.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                        _buildSeverityBadge(gap.severity),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      gap.reason,
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${gap.count} places affected',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: gap.severity == GapSeverity.critical ? Colors.red.shade800 : Colors.black54,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _showDrillDownRecords(context, gap),
                          icon: const Icon(Icons.list_alt, size: 16),
                          label: const Text('Review Records', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildSeverityBadge(GapSeverity severity) {
    Color bg;
    Color fg;
    String label;
    switch (severity) {
      case GapSeverity.critical:
        bg = Colors.red.shade100;
        fg = Colors.red.shade900;
        label = 'CRITICAL';
        break;
      case GapSeverity.warning:
        bg = Colors.orange.shade100;
        fg = Colors.orange.shade900;
        label = 'WARNING';
        break;
      case GapSeverity.info:
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade900;
        label = 'INFO';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
