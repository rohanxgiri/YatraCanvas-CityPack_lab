import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../app/app_state.dart';
import '../review/models/identity_conflict.dart';

class IdentityConflictsScreen extends StatefulWidget {
  final AppState state;
  const IdentityConflictsScreen({super.key, required this.state});
  @override
  State<IdentityConflictsScreen> createState() =>
      _IdentityConflictsScreenState();
}

class _IdentityConflictsScreenState extends State<IdentityConflictsScreen> {
  bool busy = false;
  Future<void> _resolve(
    IdentityConflict group,
    String action,
    String? survivor,
  ) async {
    if (kIsWeb) return;
    final notes = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          action == 'research' ? 'Needs Research' : 'Resolve identity conflict',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              action == 'merge'
                  ? 'Keep the selected source record as the canonical survivor. Review its inclusion in Inbox afterwards.'
                  : action == 'separate'
                  ? 'Assign a stable identity to each source entity. Review inclusion in Inbox afterwards.'
                  : action == 'exclude'
                  ? 'Exclude all members of this unpublished candidate group.'
                  : 'Retain this conflict as unresolved.',
            ),
            TextField(
              controller: notes,
              decoration: const InputDecoration(
                labelText: 'Evidence or research notes',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (notes.text.trim().isNotEmpty) Navigator.pop(ctx, true);
            },
            child: const Text('Save decision'),
          ),
        ],
      ),
    );
    final evidence = notes.text.trim();
    notes.dispose();
    if (confirmed != true) return;
    setState(() => busy = true);
    try {
      final pack = widget.state.activePack!;
      final file = File(
        p.join(
          'assets',
          'city_packs',
          pack.id,
          'curation',
          'identity_conflicts',
          '${group.fileId}.json',
        ),
      );
      await file.parent.create(recursive: true);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'schema_version': 1,
          'city_id': pack.id,
          'canonical_id': group.canonicalId,
          'action': action,
          'survivor': survivor,
          'author': widget.state.contributorName,
          'decided_at': DateTime.now().toUtc().toIso8601String(),
          'notes': evidence,
          'members': {
            for (final member in group.members)
              conflictMemberId(member): widget.state
                  .snapshotOf(member)
                  .toJson(),
          },
        }),
        flush: true,
      );
      await widget.state.loadReviewManifest(pack.id);
      await widget.state.evaluateCityQuality();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Resolution could not be saved: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.state,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Identity Conflicts')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '${widget.state.identityConflicts.where((c) => !c.resolved).length} unresolved conflict groups',
          ),
          for (final group in widget.state.identityConflicts)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      '${group.canonicalId}\n${group.type}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (group.changed)
                      const Text(
                        'Changed since conflict resolution',
                        style: TextStyle(color: Colors.red),
                      ),
                    if (group.resolved)
                      const Text(
                        'Identity resolved. Inclusion decisions remain in Inbox.',
                      ),
                    if (group.affectsPublished)
                      const Text(
                        'Published identity collision requires upstream repair. Unsafe reassignment is disabled.',
                      ),
                    if (group.members.map(conflictMemberId).toSet().length !=
                        group.members.length)
                      const Text(
                        'Members repeat the same source identity. Upstream repair is required before a safe resolution.',
                      ),
                    for (final member in group.members)
                      ListTile(
                        title: Text(member.name),
                        subtitle: SelectableText(
                          '${member.latitude}, ${member.longitude} · ${member.category} · ${member.tier}\n'
                          'Source IDs: ${member.externalIds}\nProvenance: ${member.sourceNames.join(", ")}\n'
                          'Distance from first: ${group.distance(group.members.first, member).round()} m',
                        ),
                        trailing: TextButton(
                          onPressed:
                              busy ||
                                  group.affectsPublished ||
                                  kIsWeb ||
                                  group.members
                                          .map(conflictMemberId)
                                          .toSet()
                                          .length !=
                                      group.members.length
                              ? null
                              : () => _resolve(
                                  group,
                                  'merge',
                                  conflictMemberId(member),
                                ),
                          child: const Text('Same Place: retain this record'),
                        ),
                      ),
                    Wrap(
                      spacing: 12,
                      children: [
                        TextButton(
                          onPressed:
                              busy ||
                                  group.affectsPublished ||
                                  kIsWeb ||
                                  group.members
                                          .map(conflictMemberId)
                                          .toSet()
                                          .length !=
                                      group.members.length
                              ? null
                              : () => _resolve(group, 'separate', null),
                          child: const Text('Different Places: keep separate'),
                        ),
                        TextButton(
                          onPressed:
                              busy ||
                                  group.affectsPublished ||
                                  kIsWeb ||
                                  group.members
                                          .map(conflictMemberId)
                                          .toSet()
                                          .length !=
                                      group.members.length
                              ? null
                              : () => _resolve(group, 'exclude', null),
                          child: const Text('Invalid group: exclude'),
                        ),
                        TextButton(
                          onPressed: busy || kIsWeb
                              ? null
                              : () => _resolve(group, 'research', null),
                          child: const Text('Needs Research'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
