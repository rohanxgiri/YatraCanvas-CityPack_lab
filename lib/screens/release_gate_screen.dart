import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../quality/models/release_gate_result.dart';
import '../review/models/review_candidate.dart';
import '../app/city_lab_operations.dart';
import 'certification_blockers_screen.dart';

import 'dart:io';

import 'package:path/path.dart' as p;

class ReleaseGateScreen extends StatefulWidget {
  final AppState state;
  final VoidCallback? onOpenInbox;

  const ReleaseGateScreen({super.key, required this.state, this.onOpenInbox});

  @override
  State<ReleaseGateScreen> createState() => _ReleaseGateScreenState();
}

class _ReleaseGateScreenState extends State<ReleaseGateScreen> {
  bool _isExporting = false;

  Future<void> _exportRepairPatch() async {
    final ids = TextEditingController();
    final selection = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export repair patch'),
        content: TextField(
          controller: ids,
          decoration: const InputDecoration(
            labelText: 'Place IDs (optional, separated by commas)',
            helperText: 'Leave blank for all current repairs. Older overlays require re-review.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ids.text),
            child: const Text('Export repairs'),
          ),
        ],
      ),
    );
    ids.dispose();
    if (selection == null || !mounted) return;
    setState(() => _isExporting = true);
    try {
      final operations = CityLabOperations();
      await operations.load();
      if (operations.sourcePath.isEmpty) {
        throw StateError(
          'Set your DataFactory checkout in operational settings first.',
        );
      }
      final city = widget.state.activePack!.id;
      final output = p.join(
        operations.projectPath,
        'artifacts',
        'patches',
        '${city}_${DateTime.now().millisecondsSinceEpoch}.zip',
      );
      final result = await operations.run('patch', [
        '--city',
        city,
        '--source',
        operations.sourcePath,
        '--output',
        output,
        for (final id
            in selection
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)) ...['--place-id', id],
      ]);
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Repair patch exported'),
          content: SelectableText(
            '${result['change_count']} repairs, ${result['media_count']} media files\n$output\nReview with DataFactory citylab-import --dry-run before apply.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _buildCertifiedPack() async {
    setState(() => _isExporting = true);
    try {
      await widget.state.evaluateCityQuality();
      if (!(widget.state.releaseGateResult?.isReady ?? false)) {
        throw StateError(
          '${widget.state.activePack?.name} cannot be certified yet. '
          '${widget.state.releaseGateResult?.criticalBlockers.length ?? 0} blockers remain.',
        );
      }
      final evidence = await widget.state.exportCertifiedRelease();
      if (evidence == null) {
        throw StateError('Release evidence is unavailable.');
      }
      final operations = CityLabOperations();
      await operations.load();
      final city = widget.state.activePack!.id;
      final buildDir = Directory(
        p.join(
          operations.projectPath,
          'artifacts',
          'certified',
          '${city}_${DateTime.now().millisecondsSinceEpoch}',
        ),
      );
      final evidenceFile = File('${buildDir.path}_evidence.json');
      await evidenceFile.parent.create(recursive: true);
      await evidenceFile.writeAsString(evidence['release.json']!, flush: true);
      final result = await operations.run('build', [
        '--city',
        city,
        '--evidence',
        evidenceFile.path,
        '--output',
        buildDir.path,
      ]);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Certified Pack Built'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    '$city ${widget.state.activePack!.version}\n${(result['release'] as Map)['place_count']} places\nSQLite integrity: ${result['integrity']}\nMedia integrity: ${result['media']}\nSchema: ${result['schema']}\n'
                    'Certification evidence: written\nOutput: ${result['output']}',
                  ),
                  ExpansionTile(
                    title: const Text('Technical logs'),
                    children: [SelectableText(result['logs'] as String)],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

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
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showExportSuccessModal(Map<String, String> exported) {
    final ready = widget.state.releaseGateResult?.isReady ?? false;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              ready ? Icons.verified : Icons.description,
              color: ready ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            Text(
              ready
                  ? 'Certified Release Evidence Exported'
                  : 'Blocked Release Report Exported',
              style: const TextStyle(fontSize: 17),
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
                  'The following release artifacts were generated:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 10),
                _buildArtifactTile(
                  'release.json',
                  exported['release.json'] ?? '',
                ),
                _buildArtifactTile(
                  'quality_report.json',
                  exported['quality_report.json'] ?? '',
                ),
                _buildArtifactTile(
                  'release_report.md',
                  exported['release_report.md'] ?? '',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => CertificationBlockersScreen(
                  state: widget.state,
                  onOpenInbox: widget.onOpenInbox,
                ),
              ),
            ),
            child: const Text('View Blockers'),
          ),
          TextButton(
            onPressed: _isExporting ? null : _buildCertifiedPack,
            child: const Text('Build Certified Pack'),
          ),
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
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
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
                style: const TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: Colors.black87,
                ),
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

    if (pack == null ||
        dq == null ||
        tr == null ||
        gate == null ||
        qa == null) {
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
        bannerSubtitle =
            'Zero critical blockers, but ${gate.warnings.length} warning(s) require QA sign-off.';
        break;
      case ReleaseStatus.blocked:
        bannerColor = Colors.red.shade800;
        bannerIcon = Icons.block;
        bannerTitle = 'RELEASE BLOCKED';
        bannerSubtitle =
            '${gate.criticalBlockers.length} critical blocker(s) prevent integration into YatraCanvas.';
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
                Text(
                  '${pack.name} ${pack.version}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'Critical blockers: ${gate.criticalBlockers.length} · High priority unresolved: ${widget.state.unresolvedHighPriorityCount} · Warnings: ${gate.warnings.length}',
                ),
                Text(
                  'Medium reviews: ${widget.state.reviewCandidates.where((c) => c.reviewPriority.label == 'MEDIUM' && !(widget.state.inboxDecisions[c.canonicalId]?.isResolved ?? false)).length}',
                ),
                if (gate.criticalBlockers.isNotEmpty &&
                    widget.onOpenInbox != null)
                  TextButton(
                    onPressed: widget.onOpenInbox,
                    child: const Text('Open Review Inbox'),
                  ),
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
                  tr.overallScore >= 60
                      ? Colors.indigo
                      : Colors.orange.shade800,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildRecapTile(
                  'Manual QA',
                  qa.displayStatus,
                  qa.isSufficient ? Colors.green : Colors.red.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Explicit Gate Checklist
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CONFIGURED RELEASE GATES',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildGateRow(
                    'Database integrity',
                    gate.checks['database_integrity'] ?? false,
                    'Bundled database checksum verified',
                  ),
                  const Divider(height: 16),
                  _buildGateRow(
                    'Media licenses',
                    gate.checks['media_licenses_valid'] ?? false,
                    'Attached media must carry license metadata',
                  ),
                  const Divider(height: 16),
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
                    'Minimum ${qa.minimumRequired} stratified human reviews within the configured defect limit',
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
                    ...gate.criticalBlockers.map(
                      (b) => Padding(
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
                      ),
                    ),
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
                        Icon(
                          Icons.warning_amber,
                          color: Colors.orange.shade900,
                        ),
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
                    ...gate.warnings.map(
                      (w) => Padding(
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
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          OutlinedButton.icon(
            onPressed: _isExporting ? null : _exportRepairPatch,
            icon: const Icon(Icons.upload_file),
            label: const Text('Export DataFactory repair patch'),
          ),
          const SizedBox(height: 12),
          // Export Action Button
          if (!gate.isReady) ...[
            const ElevatedButton(
              onPressed: null,
              child: Text('Certify City Pack — blocked by release checks'),
            ),
            const SizedBox(height: 8),
          ],
          ElevatedButton.icon(
            onPressed: _isExporting ? null : _exportCertifiedRelease,
            icon: _isExporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.file_download),
            label: Text(
              gate.isReady
                  ? 'Certify City Pack & Export Release Evidence'
                  : 'Export Quality & Release Gate Report',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: gate.isReady
                  ? Colors.green.shade800
                  : Colors.indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
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
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
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
