import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/lab_theme.dart';
import '../review/models/review_candidate.dart';

class HomeScreen extends StatelessWidget {
  final AppState state;
  final VoidCallback onNavigateToFix;
  final VoidCallback? onNavigateToInbox;
  final VoidCallback onNavigateToReview;
  final VoidCallback onNavigateToPlaces;
  final VoidCallback onNavigateToRelease;

  const HomeScreen({
    super.key,
    required this.state,
    required this.onNavigateToFix,
    this.onNavigateToInbox,
    required this.onNavigateToReview,
    required this.onNavigateToPlaces,
    required this.onNavigateToRelease,
  });

  @override
  Widget build(BuildContext context) {
    final pack = state.activePack;
    final dq = state.dataQualityScore;
    final travel = state.travelReadinessScore;
    final gate = state.releaseGateResult;
    final qa = state.manualQaSummary;
    final stats = state.qualityStats ?? const <String, dynamic>{};

    if (pack == null ||
        dq == null ||
        travel == null ||
        gate == null ||
        qa == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalPlaces = (stats['total_places'] as int?) ?? pack.placeCount;
    final coreTotal = (stats['core_total'] as int?) ?? 0;
    final coreWithImages = (stats['core_with_images'] as int?) ?? 0;
    final coreWithHours = (stats['core_with_hours'] as int?) ?? 0;
    final outside = (stats['places_outside_bounds'] as int?) ?? 0;
    final coreOutside = (stats['core_outside_bounds'] as int?) ?? 0;
    final sharedCoordinates =
        (stats['shared_coords_places_count'] as int?) ?? 0;
    final openIssues = state.curationService.issues.values
        .where((issue) => issue.isOpen)
        .length;

    final missingPhotos = (coreTotal - coreWithImages).clamp(0, coreTotal);
    final missingHours = (coreTotal - coreWithHours).clamp(0, coreTotal);
    final locationIssues = outside + coreOutside;
    final duplicateClusters = sharedCoordinates > 0
        ? sharedCoordinates ~/ 2
        : 0;
    final fixCount = missingPhotos + missingHours + locationIssues + openIssues;
    final isBlocked = gate.criticalBlockers.isNotEmpty;

    return RefreshIndicator(
      onRefresh: state.evaluateCityQuality,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _StatusHero(
            cityName: pack.name,
            version: pack.version,
            totalPlaces: totalPlaces,
            corePlaces: coreTotal,
            isBlocked: isBlocked,
            releaseStatus: gate.displayStatus,
            blockers: gate.criticalBlockers,
            fixCount: fixCount,
            qaComplete: qa.isSufficient,
            onPrimaryAction: fixCount > 0
                ? onNavigateToFix
                : (qa.isSufficient ? onNavigateToRelease : onNavigateToReview),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Padding(
                padding: const EdgeInsets.all(LabSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Release runway',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: LabSpacing.xs),
                    Text(
                      'Finish the work in order. A strong score never skips a hard release gate.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: LabSpacing.md),
                    _ReleaseRunway(
                      fixCount: fixCount,
                      reviewed: qa.reviewedCount,
                      reviewMinimum: qa.minimumRequired,
                      reviewComplete: qa.isSufficient,
                      isReady: gate.isReady,
                      onFix: onNavigateToFix,
                      onReview: onNavigateToReview,
                      onRelease: onNavigateToRelease,
                    ),
                    const SizedBox(height: LabSpacing.xl),
                    _SectionHeading(
                      title: 'Priority work',
                      actionLabel: 'Open Fix Center',
                      onAction: onNavigateToFix,
                    ),
                    const SizedBox(height: LabSpacing.sm),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final hasInboxCandidates =
                            state.reviewCandidates.isNotEmpty;
                        final unresolvedInbox = state.unresolvedReviewCount;
                        final unresolvedHigh =
                            state.unresolvedHighPriorityCount;
                        final columns = constraints.maxWidth >= 1180
                            ? (hasInboxCandidates ? 5 : 4)
                            : constraints.maxWidth >= 880
                            ? (hasInboxCandidates ? 3 : 2)
                            : constraints.maxWidth >= 580
                            ? 2
                            : 1;
                        const gap = LabSpacing.sm;
                        final width =
                            (constraints.maxWidth - (columns - 1) * gap) /
                            columns;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            _TaskCard(
                              width: width,
                              icon: Icons.photo_camera_back_outlined,
                              count: missingPhotos,
                              title: 'Hero photos',
                              message: 'Core destinations missing a representative image',
                              accent: LabPalette.teal,
                              onTap: onNavigateToFix,
                            ),
                            _TaskCard(
                              width: width,
                              icon: Icons.schedule_outlined,
                              count: missingHours,
                              title: 'Opening hours',
                              message: 'Core destinations unusable for timed itineraries',
                              accent: LabPalette.saffron,
                              onTap: onNavigateToFix,
                            ),
                            _TaskCard(
                              width: width,
                              icon: Icons.location_off_outlined,
                              count: locationIssues,
                              title: 'Location checks',
                              message:
                                  'Places outside the expected city envelope',
                              accent: LabPalette.danger,
                              onTap: onNavigateToFix,
                            ),
                            _TaskCard(
                              width: width,
                              icon: Icons.content_copy_outlined,
                              count: duplicateClusters,
                              title: 'Duplicate clusters',
                              message: 'Shared coordinates that need a human decision',
                              accent: LabPalette.plum,
                              onTap: onNavigateToPlaces,
                            ),
                            if (hasInboxCandidates)
                              _TaskCard(
                                width: width,
                                icon: Icons.mark_email_unread_outlined,
                                count: unresolvedInbox,
                                title: 'Review Inbox',
                                message:
                                    '$unresolvedHigh high priority · ${state.reviewCandidates.where((c) => c.reviewPriority.label == 'MEDIUM' && !(state.inboxDecisions[c.canonicalId]?.isResolved ?? false)).length} medium · ${state.reviewCandidates.length} available',
                                accent: LabPalette.ink,
                                onTap: onNavigateToInbox ?? onNavigateToReview,
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: LabSpacing.xl),
                    _SectionHeading(
                      title: 'Evidence, not shortcuts',
                      actionLabel: 'View release checks',
                      onAction: onNavigateToRelease,
                    ),
                    const SizedBox(height: LabSpacing.sm),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 700;
                        final cards = [
                          _EvidenceCard(
                            label: 'Data quality',
                            value: dq.overallScore.round(),
                            target: 70,
                            explanation: 'Completeness, coordinates, provenance, and manual QA',
                          ),
                          _EvidenceCard(
                            label: 'Travel readiness',
                            value: travel.overallScore.round(),
                            target: 60,
                            explanation: 'Attraction depth, schedules, media, and itinerary fit',
                          ),
                        ];
                        return narrow
                            ? Column(
                                children: [
                                  cards.first,
                                  const SizedBox(height: LabSpacing.sm),
                                  cards.last,
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: cards.first),
                                  const SizedBox(width: LabSpacing.sm),
                                  Expanded(child: cards.last),
                                ],
                              );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusHero extends StatelessWidget {
  final String cityName;
  final String version;
  final int totalPlaces;
  final int corePlaces;
  final bool isBlocked;
  final String releaseStatus;
  final List<String> blockers;
  final int fixCount;
  final bool qaComplete;
  final VoidCallback onPrimaryAction;

  const _StatusHero({
    required this.cityName,
    required this.version,
    required this.totalPlaces,
    required this.corePlaces,
    required this.isBlocked,
    required this.releaseStatus,
    required this.blockers,
    required this.fixCount,
    required this.qaComplete,
    required this.onPrimaryAction,
  });

  @override
  Widget build(BuildContext context) {
    final headline = isBlocked
        ? '$cityName cannot ship yet'
        : '$cityName is ready for final review';
    final firstBlocker = blockers.isNotEmpty
        ? blockers.first.replaceAll('❌ ', '')
        : 'All critical checks have passed.';
    final actionLabel = fixCount > 0
        ? 'Fix the next issue'
        : qaComplete
        ? 'Review release checks'
        : 'Continue manual review';

    return ColoredBox(
      color: LabPalette.inkStrong,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: LabSpacing.lg,
              vertical: LabSpacing.xl,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final details = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: LabSpacing.xs,
                      runSpacing: LabSpacing.xs,
                      children: [
                        _HeroChip(
                          icon: isBlocked
                              ? Icons.block_outlined
                              : Icons.verified_outlined,
                          label: 'Release $releaseStatus',
                          color: isBlocked
                              ? LabPalette.saffronSoft
                              : LabPalette.successSoft,
                        ),
                        _HeroChip(
                          icon: Icons.storage_outlined,
                          label:
                              '$totalPlaces places · $corePlaces core · $version',
                          color: Colors.white12,
                          lightText: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: LabSpacing.md),
                    Text(
                      headline,
                      style: Theme.of(context).textTheme.displaySmall
                          ?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: LabSpacing.sm),
                    Text(
                      firstBlocker,
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(color: Colors.white70),
                    ),
                  ],
                );
                final action = ElevatedButton.icon(
                  onPressed: onPrimaryAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LabPalette.saffron,
                    foregroundColor: LabPalette.inkStrong,
                    padding: const EdgeInsets.symmetric(
                      horizontal: LabSpacing.lg,
                      vertical: LabSpacing.md,
                    ),
                  ),
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(actionLabel),
                );
                if (constraints.maxWidth < 720) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      details,
                      const SizedBox(height: LabSpacing.lg),
                      action,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: details),
                    const SizedBox(width: LabSpacing.xl),
                    action,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool lightText;

  const _HeroChip({
    required this.icon,
    required this.label,
    required this.color,
    this.lightText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: LabSpacing.sm,
        vertical: LabSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 17,
            color: lightText ? Colors.white : LabPalette.inkStrong,
          ),
          const SizedBox(width: LabSpacing.xs),
          Text(
            label,
            style: TextStyle(
              color: lightText ? Colors.white : LabPalette.inkStrong,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReleaseRunway extends StatelessWidget {
  final int fixCount;
  final int reviewed;
  final int reviewMinimum;
  final bool reviewComplete;
  final bool isReady;
  final VoidCallback onFix;
  final VoidCallback onReview;
  final VoidCallback onRelease;

  const _ReleaseRunway({
    required this.fixCount,
    required this.reviewed,
    required this.reviewMinimum,
    required this.reviewComplete,
    required this.isReady,
    required this.onFix,
    required this.onReview,
    required this.onRelease,
  });

  @override
  Widget build(BuildContext context) {
    final steps = [
      _RunwayStepData(
        number: 1,
        label: 'Fix',
        detail: fixCount == 0
            ? 'Priority gaps cleared'
            : '$fixCount priority issues',
        complete: fixCount == 0,
        active: fixCount > 0,
        onTap: onFix,
      ),
      _RunwayStepData(
        number: 2,
        label: 'Review',
        detail: reviewComplete
            ? 'Required sample complete'
            : '$reviewed of $reviewMinimum checked',
        complete: reviewComplete,
        active: fixCount == 0 && !reviewComplete,
        onTap: onReview,
      ),
      _RunwayStepData(
        number: 3,
        label: 'Release',
        detail: isReady ? 'Certified for production' : 'Hard gates still apply',
        complete: isReady,
        active: fixCount == 0 && reviewComplete,
        onTap: onRelease,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(LabSpacing.md),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 680) {
              return Column(
                children: [
                  for (var index = 0; index < steps.length; index++) ...[
                    _RunwayStep(data: steps[index]),
                    if (index < steps.length - 1)
                      const Divider(height: LabSpacing.lg),
                  ],
                ],
              );
            }
            return Row(
              children: [
                for (var index = 0; index < steps.length; index++) ...[
                  Expanded(child: _RunwayStep(data: steps[index])),
                  if (index < steps.length - 1)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: LabSpacing.sm),
                      child: Icon(
                        Icons.arrow_forward,
                        color: LabPalette.outline,
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RunwayStepData {
  final int number;
  final String label;
  final String detail;
  final bool complete;
  final bool active;
  final VoidCallback onTap;

  const _RunwayStepData({
    required this.number,
    required this.label,
    required this.detail,
    required this.complete,
    required this.active,
    required this.onTap,
  });
}

class _RunwayStep extends StatelessWidget {
  final _RunwayStepData data;

  const _RunwayStep({required this.data});

  @override
  Widget build(BuildContext context) {
    final accent = data.complete
        ? LabPalette.success
        : data.active
        ? LabPalette.saffron
        : LabPalette.muted;
    return InkWell(
      onTap: data.onTap,
      borderRadius: BorderRadius.circular(LabRadius.sm),
      child: Padding(
        padding: const EdgeInsets.all(LabSpacing.xs),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: accent,
              foregroundColor: data.active
                  ? LabPalette.inkStrong
                  : Colors.white,
              child: data.complete
                  ? const Icon(Icons.check, size: 20)
                  : Text(
                      '${data.number}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
            const SizedBox(width: LabSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    data.detail,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  const _SectionHeading({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
        ),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  final double width;
  final IconData icon;
  final int count;
  final String title;
  final String message;
  final Color accent;
  final VoidCallback onTap;

  const _TaskCard({
    required this.width,
    required this.icon,
    required this.count,
    required this.title,
    required this.message,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(LabRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(LabSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: accent.withAlpha(24),
                        borderRadius: BorderRadius.circular(LabRadius.sm),
                      ),
                      child: Icon(icon, color: accent),
                    ),
                    const Spacer(),
                    Text(
                      '$count',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: accent),
                    ),
                  ],
                ),
                const SizedBox(height: LabSpacing.md),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: LabSpacing.xxs),
                Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  final String label;
  final int value;
  final int target;
  final String explanation;

  const _EvidenceCard({
    required this.label,
    required this.value,
    required this.target,
    required this.explanation,
  });

  @override
  Widget build(BuildContext context) {
    final passes = value >= target;
    final color = passes ? LabPalette.success : LabPalette.danger;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(LabSpacing.md),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: value / 100,
                    strokeWidth: 7,
                    backgroundColor: LabPalette.outline,
                    color: color,
                  ),
                  Text(
                    '$value',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: LabSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: LabSpacing.xxs),
                  Text(explanation),
                  const SizedBox(height: LabSpacing.xs),
                  Text(
                    passes
                        ? 'Passes the $target point threshold'
                        : 'Needs ${target - value} more points to reach $target',
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
