import 'package:flutter/material.dart';
import '../app/app_state.dart';
import '../quality/models/quality_dimension.dart';

class OverviewScreen extends StatelessWidget {
  final AppState state;
  final VoidCallback onNavigateToCoverage;
  final VoidCallback onNavigateToReview;
  final VoidCallback onNavigateToRelease;

  const OverviewScreen({
    super.key,
    required this.state,
    required this.onNavigateToCoverage,
    required this.onNavigateToReview,
    required this.onNavigateToRelease,
  });

  @override
  Widget build(BuildContext context) {
    final pack = state.activePack;
    final dq = state.dataQualityScore;
    final tr = state.travelReadinessScore;
    final gate = state.releaseGateResult;
    final qa = state.manualQaSummary;
    final stats = state.qualityStats ?? {};

    if (pack == null || dq == null || tr == null || gate == null || qa == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalPlaces = (stats['total_places'] as int?) ?? pack.placeCount;
    final coreTotal = (stats['core_total'] as int?) ?? 0;
    final coreWithImg = (stats['core_with_images'] as int?) ?? 0;
    final coreWithHours = (stats['core_with_hours'] as int?) ?? 0;
    final withImages = (stats['with_images'] as int?) ?? 0;
    final withHours = (stats['with_opening_hours'] as int?) ?? 0;
    final outsideBounds = (stats['places_outside_bounds'] as int?) ?? 0;
    final multiSource = (stats['multi_source_count'] as int?) ?? 0;
    final sharedCoords = (stats['shared_coords_places_count'] as int?) ?? 0;

    final readyCount = totalPlaces - outsideBounds - sharedCoords;
    final reviewCount = outsideBounds + sharedCoords;
    final excludedCount = 0; // Configured exclusions

    final coordValidityPercent = totalPlaces > 0
        ? (((totalPlaces - outsideBounds) / totalPlaces) * 100).toStringAsFixed(1)
        : '100';
    final imagesPercent = totalPlaces > 0
        ? ((withImages / totalPlaces) * 100).toStringAsFixed(1)
        : '0';
    final hoursPercent = totalPlaces > 0
        ? ((withHours / totalPlaces) * 100).toStringAsFixed(1)
        : '0';
    final provenancePercent = totalPlaces > 0
        ? ((multiSource / totalPlaces) * 100).toStringAsFixed(1)
        : '0';
    final dupFreePercent = totalPlaces > 0
        ? (((totalPlaces - sharedCoords) / totalPlaces) * 100).toStringAsFixed(1)
        : '100';

    return RefreshIndicator(
      onRefresh: () => state.evaluateCityQuality(),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Header Card
          _buildHeaderCard(context, pack, totalPlaces, readyCount, reviewCount, excludedCount),
          const SizedBox(height: 16),

          // 4 Executive KPI Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'DATA QUALITY',
                  value: '${dq.overallScore}',
                  suffix: '/ 100',
                  color: dq.overallScore >= 80
                      ? Colors.teal
                      : (dq.overallScore >= 60 ? Colors.orange : Colors.red),
                  subtitle: '${dq.dimensions.length} verified dimensions',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'TRAVEL READINESS',
                  value: '${tr.overallScore}',
                  suffix: '/ 100',
                  color: tr.overallScore >= 75
                      ? Colors.indigo
                      : (tr.overallScore >= 55 ? Colors.deepOrange : Colors.red),
                  subtitle: 'Itinerary suitability',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'MANUAL QA',
                  value: qa.displayStatus,
                  suffix: '',
                  color: qa.isSufficient ? Colors.green : Colors.amber.shade800,
                  subtitle: '${qa.reviewedCount} of ${qa.minimumRequired} min sample',
                  isSmallValue: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'RELEASE STATUS',
                  value: gate.displayStatus,
                  suffix: '',
                  color: gate.isReady
                      ? Colors.green
                      : (gate.isReviewRequired ? Colors.amber.shade900 : Colors.red.shade700),
                  subtitle: '${gate.criticalBlockers.length} blockers, ${gate.warnings.length} warnings',
                  isSmallValue: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Core Quality Metrics Scan Bar
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DATASET INTEGRITY & COMPLETENESS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildScanRow(
                    label: 'Core destinations with photos',
                    value: '$coreWithImg / $coreTotal',
                    status: coreWithImg >= (coreTotal * 0.5) ? DimensionStatus.pass : DimensionStatus.warning,
                  ),
                  const Divider(height: 16),
                  _buildScanRow(
                    label: 'Core destinations with hours',
                    value: '$coreWithHours / $coreTotal',
                    status: coreWithHours >= (coreTotal * 0.4) ? DimensionStatus.pass : DimensionStatus.warning,
                  ),
                  const Divider(height: 16),
                  _buildScanRow(
                    label: 'Geographic coordinate validity',
                    value: '$coordValidityPercent%',
                    status: outsideBounds == 0 ? DimensionStatus.pass : DimensionStatus.warning,
                  ),
                  const Divider(height: 16),
                  _buildScanRow(
                    label: 'Overall places image coverage',
                    value: '$imagesPercent% ($withImages places)',
                    status: withImages > 100 ? DimensionStatus.pass : DimensionStatus.warning,
                  ),
                  const Divider(height: 16),
                  _buildScanRow(
                    label: 'Overall opening hours coverage',
                    value: '$hoursPercent% ($withHours places)',
                    status: withHours > 100 ? DimensionStatus.pass : DimensionStatus.warning,
                  ),
                  const Divider(height: 16),
                  _buildScanRow(
                    label: 'Multi-source provenance',
                    value: '$provenancePercent% ($multiSource places)',
                    status: DimensionStatus.pass,
                  ),
                  const Divider(height: 16),
                  _buildScanRow(
                    label: 'Duplicate-free coordinates',
                    value: '$dupFreePercent%',
                    status: sharedCoords < 500 ? DimensionStatus.pass : DimensionStatus.warning,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Release Blockers or Readiness Banner
          if (gate.criticalBlockers.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.block, color: Colors.red.shade800, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        '${gate.criticalBlockers.length} RELEASE BLOCKERS PREVENTING CERTIFICATION',
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...gate.criticalBlockers.map((b) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text(
                                b,
                                style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ZERO CRITICAL BLOCKERS',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          gate.isReady
                              ? 'City Pack meets all quality & travel readiness requirements.'
                              : 'Ready for human QA sign-off.',
                          style: TextStyle(color: Colors.green.shade900, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Quick Action Buttons
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: onNavigateToReview,
                icon: const Icon(Icons.rate_review_outlined),
                label: Text(
                  qa.isSufficient ? 'Continue Review' : 'Start Manual QA (${qa.reviewedCount}/${qa.minimumRequired})',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onNavigateToCoverage,
                icon: const Icon(Icons.grid_view_outlined),
                label: const Text('View Data Coverage & Gaps'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onNavigateToRelease,
                icon: const Icon(Icons.verified_outlined),
                label: const Text('Release Gate Decision'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    dynamic pack,
    int total,
    int ready,
    int review,
    int excluded,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueGrey.shade900, Colors.blueGrey.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                pack.name.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'v${pack.version}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${pack.state}, ${pack.country} • SQLite Dataset Integrity: ${pack.integrityStatus.name.toUpperCase()}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const Divider(color: Colors.white24, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPlaceCount(total.toString(), 'Total Places', Colors.white),
              _buildPlaceCount(ready.toString(), 'Production Ready', Colors.greenAccent),
              _buildPlaceCount(review.toString(), 'Under Review', Colors.orangeAccent),
              _buildPlaceCount(excluded.toString(), 'Excluded', Colors.redAccent.shade100),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceCount(String count, String label, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          count,
          style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String suffix,
    required Color color,
    required String subtitle,
    bool isSmallValue = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(70)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: isSmallValue ? 15 : 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (suffix.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  suffix,
                  style: const TextStyle(fontSize: 13, color: Colors.black45),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: Colors.black54),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildScanRow({
    required String label,
    required String value,
    required DimensionStatus status,
  }) {
    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case DimensionStatus.pass:
        statusColor = Colors.teal;
        statusIcon = Icons.check_circle_outline;
        break;
      case DimensionStatus.warning:
        statusColor = Colors.orange;
        statusIcon = Icons.warning_amber_rounded;
        break;
      case DimensionStatus.fail:
        statusColor = Colors.red;
        statusIcon = Icons.error_outline;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        break;
    }

    return Row(
      children: [
        Icon(statusIcon, color: statusColor, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: statusColor,
          ),
        ),
      ],
    );
  }
}
