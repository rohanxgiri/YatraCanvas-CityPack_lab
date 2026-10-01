/// lib/widgets/review/review_detail_panel.dart
///
/// Side panel that shows full inspector for a single DataFactory review candidate.
/// Shows:
///   - Place identity (name, alternates, category, tier, coordinates)
///   - DataFactory decision summary
///   - Human-friendly reason explanation
///   - Evidence breakdown
///   - Source provenance
///   - Data completeness
///   - Human actions (Keep / Exclude / Needs Research / Edit / Undo)
library;

import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/lab_theme.dart';
import '../../review/models/review_candidate.dart';
import '../../review/models/inbox_decision.dart';
import '../../review/services/review_reason_translator.dart';

class ReviewDetailPanel extends StatefulWidget {
  final ReviewCandidate candidate;
  final InboxDecision? decision;
  final AppState state;
  final VoidCallback onClose;
  final ValueChanged<InboxDecision> onDecision;
  final VoidCallback onUndo;

  const ReviewDetailPanel({
    super.key,
    required this.candidate,
    required this.decision,
    required this.state,
    required this.onClose,
    required this.onDecision,
    required this.onUndo,
  });

  @override
  State<ReviewDetailPanel> createState() => _ReviewDetailPanelState();
}

class _ReviewDetailPanelState extends State<ReviewDetailPanel> {
  bool _showTechnical = false;
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _noteController.text = widget.decision?.verdictNote ?? '';
  }

  @override
  void didUpdateWidget(ReviewDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.candidate.canonicalId != widget.candidate.canonicalId) {
      _noteController.text = widget.decision?.verdictNote ?? '';
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  InboxDecision _buildDecision(InboxVerdict verdict) {
    final pack = widget.state.activePack!;
    return InboxDecision(
      canonicalId: widget.candidate.canonicalId,
      cityId: pack.id,
      packVersion: pack.version,
      verdict: verdict,
      verdictNote: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      author: widget.state.contributorName,
      decidedAt: DateTime.now().toIso8601String(),
      snapshot: widget.state.snapshotOf(widget.candidate),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.candidate;
    final decision = widget.decision;
    final translation =
        ReviewReasonTranslator.translateReason(c.travelRelevanceReason);
    final actionTranslation =
        ReviewReasonTranslator.translateAction(c.suggestedAction);
    final changedSince = decision?.changedSinceReview ?? false;

    return Column(
      children: [
        // ── Panel header ─────────────────────────────────────────────
        Container(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          padding: const EdgeInsets.symmetric(
              horizontal: LabSpacing.md, vertical: LabSpacing.sm),
          child: Row(
            children: [
              const Icon(Icons.policy_outlined, size: 16),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Review Details',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: widget.onClose,
                tooltip: 'Close panel',
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // ── Scrollable body ──────────────────────────────────────────
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(LabSpacing.md),
            children: [
              // ── Changed since review banner ──────────────────────
              if (changedSince) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.withAlpha(60)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.update, size: 14, color: Colors.purple),
                          SizedBox(width: 6),
                          Text(
                            'Changed since review',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        decision!.changedFields ?? 'DataFactory updated this candidate.',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ── Place identity ───────────────────────────────────
              _SectionHeader('Place identity'),
              _IdentityRow('Name', c.name),
              if (c.nameHi != null) _IdentityRow('Name (Hindi)', c.nameHi!),
              if (c.alternateNames.isNotEmpty)
                _IdentityRow(
                    'Also known as', c.alternateNames.take(3).join(', ')),
              _IdentityRow('Category',
                  '${_capitalize(c.category)}${c.subcategory != null ? " · ${_capitalize(c.subcategory!)}" : ""}'),
              _IdentityRow('Tier', _tierLabel(c.tier)),
              _IdentityRow(
                  'Coordinates',
                  '${c.latitude.toStringAsFixed(5)}, '
                      '${c.longitude.toStringAsFixed(5)}'),
              const SizedBox(height: 16),

              // ── DataFactory decision ──────────────────────────────
              _SectionHeader('DataFactory decision'),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.withAlpha(60)),
                ),
                child: Row(
                  children: [
                    const Text(
                      'REVIEW',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(c.confidence * 100).toStringAsFixed(0)}% confidence',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Reason (human-friendly) ───────────────────────────
              _SectionHeader('Issue'),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: translation.isCritical
                      ? Colors.red.withAlpha(10)
                      : Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: translation.isCritical
                          ? Colors.red.withAlpha(40)
                          : Theme.of(context).dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (translation.isCritical)
                      Row(
                        children: [
                          const Icon(Icons.warning_amber,
                              size: 14, color: Colors.red),
                          const SizedBox(width: 4),
                          Text(
                            translation.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        translation.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      translation.description,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      translation.recommendedAction,
                      style: const TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Evidence ─────────────────────────────────────────
              if (c.travelRelevanceEvidence.isNotEmpty) ...[
                _SectionHeader('Evidence'),
                _EvidenceView(evidence: c.travelRelevanceEvidence),
                const SizedBox(height: 16),
              ],

              // ── OSM Tags (if present) ─────────────────────────────
              if (c.osmTags.isNotEmpty) ...[
                _SectionHeader('Source tags'),
                _OsmTagsView(tags: c.osmTags),
                const SizedBox(height: 16),
              ],

              // ── Source provenance ─────────────────────────────────
              _SectionHeader('Source provenance'),
              ...c.sourcesProvenance.map((s) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        _SourceIcon(source: s.source),
                        const SizedBox(width: 6),
                        Text(
                          s.source,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        if (s.sourceId != null) ...[
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              s.sourceId!,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )),
              const SizedBox(height: 16),

              // ── Data completeness ─────────────────────────────────
              _SectionHeader('Data completeness'),
              _CompletenessView(candidate: c),
              const SizedBox(height: 16),

              // ── Technical details (expandable) ───────────────────
              InkWell(
                onTap: () =>
                    setState(() => _showTechnical = !_showTechnical),
                child: Row(
                  children: [
                    Icon(
                      _showTechnical
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 16,
                      color: LabPalette.muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Technical details',
                      style: TextStyle(
                          fontSize: 12, color: LabPalette.muted),
                    ),
                  ],
                ),
              ),
              if (_showTechnical) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        'Reason code: ${c.travelRelevanceReason}',
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 11),
                      ),
                      SelectableText(
                        'Suggested action: ${c.suggestedAction}',
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 11),
                      ),
                      SelectableText(
                        'canonical_id: ${c.canonicalId}',
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 11),
                      ),
                      SelectableText(
                        'confidence: ${c.confidence}',
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 11),
                      ),
                      SelectableText(
                        'travel_score: ${c.travelRelevanceScore}',
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // ── Note field ───────────────────────────────────────
              _SectionHeader('Decision note (optional)'),
              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Add context for future reviewers…',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                style: const TextStyle(fontSize: 12),
              ),

              // ── Existing decision info ───────────────────────────
              if (decision != null && decision.verdict != InboxVerdict.unreviewed) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.withAlpha(40)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current decision: ${decision.verdict.displayLabel}',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'By ${decision.author} at '
                        '${decision.decidedAt.substring(0, 10)}',
                        style: const TextStyle(
                            fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── Action buttons ────────────────────────────────────────────
        const Divider(height: 1),
        Container(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          padding: const EdgeInsets.all(LabSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Primary: Keep / Exclude
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () =>
                          widget.onDecision(_buildDecision(InboxVerdict.approved)),
                      icon: const Icon(Icons.check, size: 16),
                      label: Text(
                        actionTranslation.keepLabel,
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () =>
                          widget.onDecision(_buildDecision(InboxVerdict.rejected)),
                      icon: const Icon(Icons.close, size: 16),
                      label: Text(
                        actionTranslation.excludeLabel,
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Secondary: Needs Research
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => widget.onDecision(
                          _buildDecision(InboxVerdict.needsResearch)),
                      icon: const Icon(Icons.flag_outlined, size: 14),
                      label: Text(
                        actionTranslation.reviewLabel,
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.amber.shade700,
                        padding:
                            const EdgeInsets.symmetric(vertical: 6),
                      ),
                    ),
                  ),
                  if (decision != null &&
                      decision.verdict != InboxVerdict.unreviewed) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: widget.onUndo,
                      icon: const Icon(Icons.undo, size: 14),
                      label: const Text('Undo',
                          style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 16),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String _tierLabel(String tier) {
    switch (tier) {
      case 'core_destination':
        return 'Core Destination';
      case 'recommended':
        return 'Recommended';
      case 'discovery':
        return 'Discovery';
      case 'support':
        return 'Support';
      default:
        return tier;
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: LabPalette.muted,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _IdentityRow extends StatelessWidget {
  final String label;
  final String value;

  const _IdentityRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: LabPalette.muted),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidenceView extends StatelessWidget {
  final Map<String, dynamic> evidence;

  const _EvidenceView({required this.evidence});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: evidence.entries
          .where((e) => e.value != null)
          .map((e) {
        final value = e.value is List
            ? (e.value as List).join(', ')
            : e.value.toString();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  e.key,
                  style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Colors.grey),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _OsmTagsView extends StatelessWidget {
  final Map<String, String> tags;

  const _OsmTagsView({required this.tags});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: tags.entries.map((e) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  e.key,
                  style: const TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: Colors.blue),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '= ${e.value}',
                style:
                    const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _CompletenessView extends StatelessWidget {
  final ReviewCandidate candidate;

  const _CompletenessView({required this.candidate});

  @override
  Widget build(BuildContext context) {
    final fields = [
      ('Name', candidate.name.isNotEmpty),
      ('Coordinates', candidate.latitude != 0.0 && candidate.longitude != 0.0),
      ('Category', candidate.category.isNotEmpty),
      ('Image', !candidate.missingFields.contains('primary_image')),
      ('Description', !candidate.missingFields.contains('description')),
      ('Opening hours', !candidate.missingFields.contains('opening_hours')),
      ('Website', candidate.website != null),
      ('Address', !candidate.missingFields.contains('address')),
    ];

    return Column(
      children: fields.map((f) {
        final label = f.$1;
        final present = f.$2;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Icon(
                present ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 14,
                color: present ? Colors.teal : Colors.grey.shade400,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: present ? null : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SourceIcon extends StatelessWidget {
  final String source;

  const _SourceIcon({required this.source});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    switch (source.toLowerCase()) {
      case 'openstreetmap':
      case 'osm':
        icon = Icons.map_outlined;
        color = Colors.green;
        break;
      case 'wikidata':
        icon = Icons.account_tree_outlined;
        color = Colors.indigo;
        break;
      case 'wikipedia':
        icon = Icons.article_outlined;
        color = Colors.blue;
        break;
      case 'wikivoyage':
        icon = Icons.travel_explore_outlined;
        color = Colors.teal;
        break;
      case 'overture':
        icon = Icons.layers_outlined;
        color = Colors.orange;
        break;
      default:
        icon = Icons.source_outlined;
        color = Colors.grey;
    }
    return Icon(icon, size: 14, color: color);
  }
}
