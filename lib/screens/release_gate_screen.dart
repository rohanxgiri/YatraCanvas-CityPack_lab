import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app/app_state.dart';
import '../quality/models/release_gate_result.dart';

class ReleaseGateScreen extends StatefulWidget {
  final AppState state;

  const ReleaseGateScreen({super.key, required this.state});

  @override
  State<ReleaseGateScreen> createState() => _ReleaseGateScreenState();
}

class _ReleaseGateScreenState extends State<ReleaseGateScreen> {
  bool _isExporting = false;

  void _exportCertifiedRelease() async {
    setState(() => _isExporting = true);
    try {
      final res = await widget.state.exportCertifiedRelease();
      if (mounted) {
        setState(() => _isExporting = false);
        if (res != null) {
          _showExportSuccessModal(res);
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

  void _showExportSuccessModal(Map<String, String> exported) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified, color: Colors.green),
            SizedBox(width: 8),
            Text('Certified Release Exported', style: TextStyle(fontSize: 17)),
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
                  'The following release artifacts were generated:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 10),
                _buildArtifactTile('release.json', exported['release.json'] ?? ''),
                _buildArtifactTile('quality_report.json', exported['quality_report.json'] ?? ''),
                _buildArtifactTile('release_report.md', exported['release_report.md'] ?? ''),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildArtifactTile(String filename, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                filename,
                style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 12),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                tooltip: 'Copy content to clipboard',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Copied $filename to clipboard')),
                  );
                },
              ),
            ],
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 90),
            child: SingleChildScrollView(
              child: Text(
                content,
                style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pack = widget.state.activePack;
    final dq = widget.state.dataQualityScore;
    final tr = widget.state.travelReadinessScore;
    final gate = widget.state.releaseGateResult;
    final qa = widget.state.manualQaSummary;

    if (pack == null || dq == null || tr == null || gate == null || qa == null) {
      return const Center(child: CircularProgressIndicator());
    }

    Color bannerColor;
    IconData bannerIcon;
    String bannerTitle;
    String bannerSubtitle;

    switch (gate.status) {
      case ReleaseStatus.ready:
        bannerColor = Colors.green;
        bannerIcon = Icons.check_circle;
        bannerTitle = 'PRODUCTION READY FOR YATRACANVAS';
        bannerSubtitle = 'All critical quality, travel readiness, and manual QA release gates have passed.';
        break;
      case ReleaseStatus.reviewRequired:
        bannerColor = Colors.orange.shade800;
        bannerIcon = Icons.warning_amber_rounded;
        bannerTitle = 'REVIEW REQUIRED BEFORE RELEASE';
        bannerSubtitle = 'Zero critical blockers, but ${gate.warnings.length} warning(s) require QA sign-off.';
        break;
      case ReleaseStatus.blocked:
        bannerColor = Colors.red.shade800;
        bannerIcon = Icons.block;
        bannerTitle = 'RELEASE BLOCKED';
        bannerSubtitle = '${gate.criticalBlockers.length} critical blocker(s) prevent integration into YatraCanvas.';
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Production Release Gate'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Re-evaluate Release Gate',
            onPressed: () => widget.state.evaluateCityQuality(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Large Decision Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: bannerColor.withAlpha(25),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: bannerColor, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(bannerIcon, color: bannerColor, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            gate.displayStatus,
                            style: TextStyle(
                              color: bannerColor,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            bannerTitle,
                            style: TextStyle(
                              color: bannerColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  bannerSubtitle,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Executive Metric Scores Recap
          Row(
            children: [
              Expanded(
                child: _buildRecapTile(
                  'Data Quality',
                  '${dq.overallScore}/100',
                  dq.overallScore >= 70 ? Colors.teal : Colors.red,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildRecapTile(
                  'Travel Readiness',
                  '${tr.overallScore}/100',
                  tr.overallScore >= 60 ? Colors.indigo : Colors.orange.shade800,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildRecapTile(
                  'Manual QA',
                  qa.isSufficient ? 'SUFFICIENT' : 'INCOMPLETE',
                  qa.isSufficient ? Colors.green : Colors.red.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Explicit Gate Checklist
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CONFIGURED RELEASE GATES',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Colors.black54),
                  ),
                  const SizedBox(height: 14),
                  _buildGateRow(
                    'SQLite & Manifest Schema Valid',
                    gate.checks['schema_valid'] ?? false,
                    'All required tables, indices, and manifest attributes valid',
                  ),
                  const Divider(height: 16),
                  _buildGateRow(
                    'Core POI Geographic Integrity',
                    gate.checks['core_geo_integrity'] ?? false,
                    'Zero flagship tourist destinations outside city boundary envelope',
                  ),
                  const Divider(height: 16),
                  _buildGateRow(
                    'Manual QA Sample Completed',
                    gate.checks['manual_qa_sufficient'] ?? false,
                    'Minimum ${qa.minimumRequired} stratified human reviews with < 20% defects',
                  ),
                  const Divider(height: 16),
                  _buildGateRow(
                    'Itinerary Sights Depth',
                    gate.checks['sufficient_attractions'] ?? false,
                    'Minimum 10 cultural/tourist attractions to build itineraries',
                  ),
                  const Divider(height: 16),
                  _buildGateRow(
                    'Data Quality Threshold (>= 70)',
                    gate.checks['data_quality_threshold'] ?? false,
                    'Current overall score: ${dq.overallScore}/100',
                  ),
                  const Divider(height: 16),
                  _buildGateRow(
                    'Travel Readiness Threshold (>= 60)',
                    gate.checks['travel_readiness_threshold'] ?? false,
                    'Current travel score: ${tr.overallScore}/100',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Critical Blockers List
          if (gate.criticalBlockers.isNotEmpty) ...[
            Card(
              color: Colors.red.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.red.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error, color: Colors.red.shade800),
                        const SizedBox(width: 8),
                        Text(
                          '${gate.criticalBlockers.length} CRITICAL RELEASE BLOCKERS',
                          style: TextStyle(
                            color: Colors.red.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...gate.criticalBlockers.map((b) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('❌ ', style: TextStyle(fontSize: 12)),
                              Expanded(
                                child: Text(
                                  b,
                                  style: TextStyle(
                                    color: Colors.red.shade900,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Warnings List
          if (gate.warnings.isNotEmpty) ...[
            Card(
              color: Colors.orange.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.orange.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.orange.shade900),
                        const SizedBox(width: 8),
                        Text(
                          '${gate.warnings.length} RELEASE WARNINGS',
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...gate.warnings.map((w) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('⚠️ ', style: TextStyle(fontSize: 12)),
                              Expanded(
                                child: Text(
                                  w,
                                  style: TextStyle(
                                    color: Colors.orange.shade900,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Export Action Button
          ElevatedButton.icon(
            onPressed: _isExporting ? null : _exportCertifiedRelease,
            icon: _isExporting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.file_download),
            label: Text(
              gate.isReady
                  ? 'Export Certified Release Artifacts (release.json)'
                  : 'Export Quality & Release Gate Report',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: gate.isReady ? Colors.green.shade800 : Colors.indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildRecapTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildGateRow(String title, bool passed, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          passed ? Icons.check_circle : Icons.cancel,
          color: passed ? Colors.green : Colors.red,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: passed ? Colors.black87 : Colors.red.shade900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: passed ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            passed ? 'PASS' : 'FAIL',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: passed ? Colors.green.shade800 : Colors.red.shade800,
            ),
          ),
        ),
      ],
    );
  }
}
