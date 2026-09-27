import 'package:flutter/material.dart';
import '../app/app_state.dart';
import '../qa/qa_export_service.dart';

class QaDashboardScreen extends StatefulWidget {
  final AppState state;

  const QaDashboardScreen({super.key, required this.state});

  @override
  State<QaDashboardScreen> createState() => _QaDashboardScreenState();
}

class _QaDashboardScreenState extends State<QaDashboardScreen> {
  Map<String, dynamic>? _stats;
  bool _isLoadingStats = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _loadStats() async {
    final repo = widget.state.repository;
    if (repo == null) return;

    final s = await repo.getQualityStats();
    if (mounted) {
      setState(() {
        _stats = s;
        _isLoadingStats = false;
      });
    }
  }

  void _exportQaReport() async {
    setState(() => _isExporting = true);
    try {
      final res = await widget.state.exportQaReport();
      if (mounted) {
        setState(() {
          _isExporting = false;
        });

        if (res != null) {
          _showExportDialog(res);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showExportDialog(QaExportResult res) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.file_download_done, color: Colors.green),
            SizedBox(width: 8),
            Text('QA Report Exported', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Saved files to local device:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SelectableText('JSON: ${res.jsonFilePath}',
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
              const SizedBox(height: 4),
              SelectableText('Markdown: ${res.mdFilePath}',
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
              const Divider(height: 24),
              const Text('Markdown Preview:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      res.mdContent,
                      style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pack = widget.state.activePack;
    final session = widget.state.currentSession;
    final issues = session?.issues ?? [];
    final randomReviews = session?.randomReviews ?? [];

    final int totalReviewed = randomReviews.length;
    final int issueCount = issues.length;
    final double issueRate = totalReviewed > 0 ? (issueCount / totalReviewed) * 100 : 0.0;

    // Breakdown map
    final Map<String, int> issueBreakdown = {};
    for (final i in issues) {
      issueBreakdown[i.issueType.label] = (issueBreakdown[i.issueType.label] ?? 0) + 1;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${pack?.name ?? "City"} QA Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export QA Report',
            onPressed: _isExporting ? null : _exportQaReport,
          ),
        ],
      ),
      body: _isLoadingStats
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Prominent manual QA disclaimer (Phase 26)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.amber.shade900),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Manual QA Data: These metrics reflect manual tester annotations, not whole-dataset statistical completeness.',
                            style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Pack High-Level Metrics
                  const Text('Dataset Overview',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _metricCard('Total Places', '${_stats?['total_places'] ?? pack?.placeCount}', Icons.place),
                      _metricCard('With Images', '${_stats?['with_images'] ?? 0}', Icons.image),
                      _metricCard('No Images', '${_stats?['without_images'] ?? 0}', Icons.image_not_supported),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _metricCard('Wikidata IDs', '${_stats?['with_wikidata'] ?? 0}', Icons.dataset),
                      _metricCard('OSM IDs', '${_stats?['with_osm'] ?? 0}', Icons.map),
                      _metricCard('Opening Hours', '${_stats?['with_opening_hours'] ?? 0}', Icons.access_time),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // QA Progress Metrics
                  const Text('Manual QA Session Progress',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _qaStatRow('Random POIs Reviewed', '$totalReviewed places'),
                          _qaStatRow('Reported QA Issues', '$issueCount issues'),
                          _qaStatRow('Issue Flag Rate', '${issueRate.toStringAsFixed(1)}%'),
                          _qaStatRow('Expected Landmark Checks', '${session?.expectedPlaceChecks.length ?? 0}'),
                          _qaStatRow('Search Queries Reviewed', '${session?.searchReviews.length ?? 0}'),
                          _qaStatRow('Test Trip Selections', '${session?.tripSelections.length ?? 0}'),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Issue Breakdown
                  if (issueBreakdown.isNotEmpty) ...[
                    const Text('Issue Type Breakdown',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: issueBreakdown.entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.flag, size: 14, color: Colors.red.shade700),
                                  const SizedBox(width: 8),
                                  Text(entry.key, style: const TextStyle(fontSize: 13)),
                                  const Spacer(),
                                  Text('${entry.value}',
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Reported Issues List with Delete capability (Phase 36)
                  Row(
                    children: [
                      Text('Logged Issues ($issueCount)',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _isExporting ? null : _exportQaReport,
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Export Report'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (issues.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No QA issues logged yet for this city.'),
                    )
                  else
                    ...issues.map((issue) {
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(issue.placeName,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            '${issue.issueType.label}\nNote: ${issue.note.isEmpty ? "None" : issue.note}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            tooltip: 'Delete Issue',
                            onPressed: () async {
                              await widget.state.deleteIssue(issue.id);
                              setState(() {});
                            },
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  Widget _metricCard(String label, String value, IconData icon) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, size: 20, color: Colors.indigo),
              const SizedBox(height: 6),
              Text(value,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(label,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _qaStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
