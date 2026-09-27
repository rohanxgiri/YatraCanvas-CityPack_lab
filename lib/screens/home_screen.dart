import 'package:flutter/material.dart';
import '../app/app_state.dart';
import '../widgets/score_ring.dart';

class HomeScreen extends StatelessWidget {
  final AppState state;
  final VoidCallback onNavigateToFix;
  final VoidCallback onNavigateToReview;
  final VoidCallback onNavigateToPlaces;
  final VoidCallback onNavigateToRelease;

  const HomeScreen({
    super.key,
    required this.state,
    required this.onNavigateToFix,
    required this.onNavigateToReview,
    required this.onNavigateToPlaces,
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
    final coreOutsideBounds = (stats['core_outside_bounds'] as int?) ?? 0;
    final placesOutsideBounds = (stats['places_outside_bounds'] as int?) ?? 0;
    final sharedCoords = (stats['shared_coords_places_count'] as int?) ?? 0;

    final missingPhotosCount = coreTotal - coreWithImg;
    final missingHoursCount = coreTotal - coreWithHours;
    final locationIssuesCount = coreOutsideBounds + placesOutsideBounds;
    final duplicatesCount = sharedCoords > 0 ? (sharedCoords ~/ 2) : 0;
    final openIssuesCount = state.curationService.issues.values.where((i) => i.isOpen).length;

    final totalFixCount = (missingPhotosCount > 0 ? missingPhotosCount : 0) +
        (missingHoursCount > 0 ? missingHoursCount : 0) +
        locationIssuesCount +
        openIssuesCount;

    // Composite City Health (blended DQ & TR)
    final cityHealth = ((dq.overallScore * 0.5) + (tr.overallScore * 0.5)).round();
    final healthAssessment = cityHealth >= 80
        ? 'Excellent, nearly ready for production'
        : (cityHealth >= 65 ? 'Good, but needs attention' : 'Requires significant curation');

    return RefreshIndicator(
      onRefresh: () => state.evaluateCityQuality(),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        children: [
          // 1. Executive Headline & City Health
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  ScoreRing(
                    score: cityHealth.toDouble(),
                    size: 96,
                    strokeWidth: 9,
                    color: cityHealth >= 80 ? Colors.teal : (cityHealth >= 60 ? Colors.orange : Colors.red),
                    label: 'Health',
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              pack.name.toUpperCase(),
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(4)),
                              child: Text('v${pack.version}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          healthAssessment,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: cityHealth >= 75 ? Colors.teal.shade800 : Colors.orange.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$totalPlaces cataloged places • $coreTotal Core Destinations',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 2. Primary Hero Action CTA
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo.shade700, Colors.indigo.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.indigo.withAlpha(40),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        totalFixCount > 0 ? '$totalFixCount ISSUES NEED FIXING' : 'DATASET IS IN GOOD SHAPE',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        totalFixCount > 0
                            ? 'Fix flagship photos, missing opening hours and coordinates.'
                            : 'All priority issues resolved. Run verification or export release.',
                        style: TextStyle(color: Colors.indigo.shade100, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.build_circle, size: 18),
                  label: Text(totalFixCount > 0 ? 'Fix ${pack.name}' : 'Open Fix Center'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.indigo.shade900,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: onNavigateToFix,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 3. Actionable Issue Breakdown Grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ACTIONABLE TASKS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5)),
              TextButton(onPressed: onNavigateToFix, child: const Text('Go to Fix Center →')),
            ],
          ),
          const SizedBox(height: 8),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: [
              _buildTaskCard(
                icon: Icons.photo_library_outlined,
                color: Colors.teal,
                title: '$missingPhotosCount Missing Photos',
                subtitle: 'Core sights lacking hero image',
                onTap: onNavigateToFix,
              ),
              _buildTaskCard(
                icon: Icons.access_time_outlined,
                color: Colors.orange,
                title: '$missingHoursCount Missing Hours',
                subtitle: 'Flagship destinations lack schedule',
                onTap: onNavigateToFix,
              ),
              _buildTaskCard(
                icon: Icons.pin_drop_outlined,
                color: Colors.deepOrange,
                title: '$locationIssuesCount Location Issues',
                subtitle: 'Places outside boundary envelope',
                onTap: onNavigateToFix,
              ),
              _buildTaskCard(
                icon: Icons.copy_outlined,
                color: Colors.purple,
                title: '$duplicatesCount Potential Duplicates',
                subtitle: 'Identical coordinates cluster',
                onTap: onNavigateToFix,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 4. Manual QA Verification Status Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.rate_review_outlined, color: Colors.indigo, size: 20),
                          SizedBox(width: 8),
                          Text('MANUAL QA VERIFICATION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: qa.isSufficient ? Colors.green.shade50 : Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          qa.displayStatus,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: qa.isSufficient ? Colors.green.shade800 : Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: (qa.reviewedCount / qa.minimumRequired).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(qa.isSufficient ? Colors.green : Colors.indigo),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${qa.reviewedCount} of ${qa.minimumRequired} sample verified (${qa.approvedCount} approved, ${qa.issueCount} defects)',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      TextButton(
                        onPressed: onNavigateToReview,
                        child: Text(qa.reviewedCount == 0 ? 'Start Reviewing →' : 'Continue Review →'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 5. Release Gate Status Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    gate.isReady ? Icons.verified : Icons.gpp_bad,
                    color: gate.isReady ? Colors.green : (gate.criticalBlockers.isNotEmpty ? Colors.red : Colors.orange),
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RELEASE GATE: ${gate.displayStatus}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          gate.criticalBlockers.isNotEmpty
                              ? '${gate.criticalBlockers.length} critical blocker(s) remaining before production'
                              : (gate.warnings.isNotEmpty ? '0 blockers, ${gate.warnings.length} soft warnings' : 'Certified ready for production deployment'),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: onNavigateToRelease,
                    child: const Text('View Release'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
