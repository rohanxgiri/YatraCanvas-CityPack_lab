/// lib/widgets/review/review_candidate_card.dart
///
/// Compact card for a single DataFactory review candidate.
/// Shows the most important information without requiring the user to open a
/// detail view for obvious cases.
library;

import 'package:flutter/material.dart';
import '../../app/lab_theme.dart';
import '../../review/models/review_candidate.dart';
import '../../review/models/inbox_decision.dart';
import '../../review/services/review_reason_translator.dart';

class ReviewCandidateCard extends StatelessWidget {
  final ReviewCandidate candidate;
  final InboxDecision? decision;
  final bool isSelected;
  final bool bulkMode;
  final VoidCallback onTap;
  final ValueChanged<bool> onSelect;
  final ValueChanged<InboxVerdict> onQuickDecision;

  const ReviewCandidateCard({
    super.key,
    required this.candidate,
    required this.decision,
    required this.isSelected,
    required this.bulkMode,
    required this.onTap,
    required this.onSelect,
    required this.onQuickDecision,
  });

  @override
  Widget build(BuildContext context) {
    final translation =
        ReviewReasonTranslator.translateReason(candidate.travelRelevanceReason);
    final actionTranslation = ReviewReasonTranslator.translateAction(
        candidate.suggestedAction);

    final verdict = decision?.verdict;
    final isResolved = decision?.isResolved ?? false;
    final changedSince = decision?.changedSinceReview ?? false;

    Color cardBorder = Theme.of(context).dividerColor;
    if (changedSince) {
      cardBorder = Colors.purple;
    } else if (verdict == InboxVerdict.approved) {
      cardBorder = Colors.teal;
    } else if (verdict == InboxVerdict.rejected) {
      cardBorder = Colors.red.shade300;
    } else if (candidate.reviewPriority == ReviewPriority.high &&
        !isResolved) {
      cardBorder = Colors.orange.shade400;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: LabSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: cardBorder, width: isResolved || changedSince ? 1.5 : 0.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(LabSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ─────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (bulkMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 8, top: 2),
                      child: Checkbox(
                        value: isSelected,
                        visualDensity: VisualDensity.compact,
                        onChanged: (v) => onSelect(v ?? false),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          candidate.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        Text(
                          '${_capitalize(candidate.category)}'
                          '${candidate.subcategory != null ? " · ${_capitalize(candidate.subcategory!)}" : ""}'
                          ' · ${_tierLabel(candidate.tier)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: LabPalette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Priority + status badges
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _PriorityBadge(priority: candidate.reviewPriority),
                      const SizedBox(height: 4),
                      if (changedSince)
                        const _Badge(
                          label: 'CHANGED',
                          color: Colors.purple,
                        )
                      else if (verdict != null && verdict != InboxVerdict.unreviewed)
                        _VerdictBadge(verdict: verdict),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ── Issue summary ───────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (translation.isCritical)
                    const Padding(
                      padding: EdgeInsets.only(right: 4, top: 1),
                      child: Icon(Icons.warning_amber,
                          size: 14, color: Colors.red),
                    ),
                  Expanded(
                    child: Text(
                      translation.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: translation.isCritical
                            ? Colors.red.shade700
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                translation.description,
                style: TextStyle(fontSize: 11, color: LabPalette.muted),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              // ── Missing fields mini-row ─────────────────────────────
              if (candidate.missingFields.isNotEmpty) ...[
                const SizedBox(height: 8),
                _MissingFieldsRow(missingFields: candidate.missingFields),
              ],

              // ── Action buttons (only when unresolved) ───────────────
              if (!isResolved) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => onTap(),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          textStyle: const TextStyle(fontSize: 12),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                        child: const Text('Review'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () => onQuickDecision(InboxVerdict.approved),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          textStyle: const TextStyle(fontSize: 12),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                        child: Text(actionTranslation.keepLabel),
                      ),
                    ),
                  ],
                ),
              ] else if (changedSince) ...[
                // Changed — nudge to re-review
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.update, size: 14),
                  label: const Text('Review change', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.purple,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String _tierLabel(String tier) {
    switch (tier) {
      case 'core_destination':
        return 'Core';
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

class _PriorityBadge extends StatelessWidget {
  final ReviewPriority priority;

  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (priority) {
      case ReviewPriority.high:
        color = Colors.red.shade600;
        break;
      case ReviewPriority.medium:
        color = Colors.orange.shade700;
        break;
      case ReviewPriority.low:
        color = Colors.grey.shade600;
        break;
    }
    return _Badge(label: priority.label, color: color);
  }
}

class _VerdictBadge extends StatelessWidget {
  final InboxVerdict verdict;

  const _VerdictBadge({required this.verdict});

  @override
  Widget build(BuildContext context) {
    switch (verdict) {
      case InboxVerdict.approved:
        return const _Badge(label: 'KEPT', color: Colors.teal);
      case InboxVerdict.rejected:
        return const _Badge(label: 'EXCLUDED', color: Colors.red);
      case InboxVerdict.edited:
        return const _Badge(label: 'EDITED', color: Colors.indigo);
      case InboxVerdict.needsResearch:
        return const _Badge(label: 'RESEARCH', color: Colors.amber);
      case InboxVerdict.unreviewed:
        return const SizedBox.shrink();
    }
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(80), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _MissingFieldsRow extends StatelessWidget {
  final List<String> missingFields;

  const _MissingFieldsRow({required this.missingFields});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: missingFields.take(5).map((field) {
        String label;
        switch (field) {
          case 'primary_image':
            label = '📷 No image';
            break;
          case 'description':
            label = '📝 No description';
            break;
          case 'opening_hours':
            label = '🕐 No hours';
            break;
          case 'website':
            label = '🌐 No website';
            break;
          case 'address':
            label = '📍 No address';
            break;
          default:
            label = '⚠ $field';
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey.withAlpha(20),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.withAlpha(40)),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        );
      }).toList(),
    );
  }
}
