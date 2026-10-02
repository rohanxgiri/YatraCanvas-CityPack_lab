import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../review/models/review_candidate.dart';

class CertificationBlockersScreen extends StatelessWidget {
  final AppState state;
  final VoidCallback? onOpenInbox;
  const CertificationBlockersScreen({
    super.key,
    required this.state,
    this.onOpenInbox,
  });
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) {
      final blockers = state.releaseGateResult?.criticalBlockers ?? [];
      final records = state.reviewCandidates.where(
        (c) =>
            c.reviewPriority == ReviewPriority.blocking &&
            !(state.inboxDecisions[c.canonicalId]?.isResolved ?? false),
      );
      return Scaffold(
        appBar: AppBar(title: const Text('Certification Blockers')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              '${state.activePack?.name ?? "City"}: ${blockers.length} blockers',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            for (final reason in blockers)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.block, color: Colors.red),
                  title: Text(reason),
                ),
              ),
            for (final candidate in records)
              Card(
                child: ListTile(
                  title: Text(candidate.name),
                  subtitle: Text(
                    '${candidate.tier}: ${candidate.travelRelevanceReason}',
                  ),
                  trailing: const Text('Unresolved'),
                ),
              ),
            if (blockers.isEmpty)
              const Text(
                'No current certification blockers. Validate before building.',
              ),
            if (onOpenInbox != null)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onOpenInbox!();
                },
                child: const Text('Open Review Inbox'),
              ),
          ],
        ),
      );
    },
  );
}
