/// lib/review/models/inbox_decision.dart
///
/// City Lab workflow state for a DataFactory review candidate.
///
/// IMPORTANT INVARIANTS:
/// - Never modifies the original DataFactory record.
/// - Stores BOTH the DataFactory suggested action and the human decision.
/// - Preserves enough information to detect "changed since review".
/// - Stored in `assets/city_packs/<city>/curation/inbox_decisions/<canonical_id>.json`
library;

import 'dart:convert';

/// The City Lab human decision for a single review candidate.
enum InboxVerdict {
  /// Not yet looked at.
  unreviewed,

  /// Human decided: keep this place in the city pack.
  approved,

  /// Human decided: remove this place from the city pack.
  rejected,

  /// Human edited field values via PlaceOverride; record needs context.
  edited,

  /// Human wants more information before deciding.
  needsResearch,
}

extension InboxVerdictX on InboxVerdict {
  String get label {
    switch (this) {
      case InboxVerdict.unreviewed:
        return 'UNREVIEWED';
      case InboxVerdict.approved:
        return 'APPROVED';
      case InboxVerdict.rejected:
        return 'REJECTED';
      case InboxVerdict.edited:
        return 'EDITED';
      case InboxVerdict.needsResearch:
        return 'NEEDS_RESEARCH';
    }
  }

  String get displayLabel {
    switch (this) {
      case InboxVerdict.unreviewed:
        return 'Unreviewed';
      case InboxVerdict.approved:
        return 'Kept in City Pack';
      case InboxVerdict.rejected:
        return 'Excluded from City Pack';
      case InboxVerdict.edited:
        return 'Edited';
      case InboxVerdict.needsResearch:
        return 'Needs Research';
    }
  }

  bool get isResolved =>
      this == InboxVerdict.approved ||
      this == InboxVerdict.rejected ||
      this == InboxVerdict.edited;
}

/// Full inbox decision record — what a human decided about a review candidate,
/// plus enough DataFactory snapshot to detect changes on regeneration.
class InboxDecision {
  final String canonicalId;
  final String cityId;
  final String packVersion;

  // Human decision
  final InboxVerdict verdict;
  final String? verdictNote;

  // Audit trail
  final String author;
  final String decidedAt;

  /// DataFactory state at the time the human made this decision.
  /// Used to detect "changed since review".
  final InboxDecisionSnapshot snapshot;

  /// Whether this decision needs re-review because DataFactory regenerated
  /// the candidate with different values.
  final bool changedSinceReview;

  /// Human-readable summary of what changed (filled when changedSinceReview=true).
  final String? changedFields;

  const InboxDecision({
    required this.canonicalId,
    required this.cityId,
    required this.packVersion,
    required this.verdict,
    this.verdictNote,
    required this.author,
    required this.decidedAt,
    required this.snapshot,
    this.changedSinceReview = false,
    this.changedFields,
  });

  bool get isResolved => verdict.isResolved && !changedSinceReview;

  InboxDecision copyWith({
    InboxVerdict? verdict,
    String? verdictNote,
    String? author,
    String? decidedAt,
    InboxDecisionSnapshot? snapshot,
    bool? changedSinceReview,
    String? changedFields,
  }) {
    return InboxDecision(
      canonicalId: canonicalId,
      cityId: cityId,
      packVersion: packVersion,
      verdict: verdict ?? this.verdict,
      verdictNote: verdictNote ?? this.verdictNote,
      author: author ?? this.author,
      decidedAt: decidedAt ?? this.decidedAt,
      snapshot: snapshot ?? this.snapshot,
      changedSinceReview: changedSinceReview ?? this.changedSinceReview,
      changedFields: changedFields ?? this.changedFields,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'canonical_id': canonicalId,
      'city_id': cityId,
      'pack_version': packVersion,
      'verdict': verdict.label,
      'author': author,
      'decided_at': decidedAt,
      'snapshot': snapshot.toJson(),
      'changed_since_review': changedSinceReview,
    };
    if (verdictNote != null) map['verdict_note'] = verdictNote;
    if (changedFields != null) map['changed_fields'] = changedFields;
    return map;
  }

  factory InboxDecision.fromJson(Map<String, dynamic> json) {
    final verdictStr = json['verdict'] as String? ?? 'UNREVIEWED';
    InboxVerdict verdict;
    switch (verdictStr) {
      case 'APPROVED':
        verdict = InboxVerdict.approved;
        break;
      case 'REJECTED':
        verdict = InboxVerdict.rejected;
        break;
      case 'EDITED':
        verdict = InboxVerdict.edited;
        break;
      case 'NEEDS_RESEARCH':
        verdict = InboxVerdict.needsResearch;
        break;
      default:
        verdict = InboxVerdict.unreviewed;
    }

    return InboxDecision(
      canonicalId: json['canonical_id'] as String,
      cityId: json['city_id'] as String,
      packVersion: json['pack_version'] as String? ?? 'v3',
      verdict: verdict,
      verdictNote: json['verdict_note'] as String?,
      author: json['author'] as String? ?? 'contributor',
      decidedAt:
          json['decided_at'] as String? ?? DateTime.now().toIso8601String(),
      snapshot: InboxDecisionSnapshot.fromJson(
        (json['snapshot'] as Map<String, dynamic>?) ?? {},
      ),
      changedSinceReview: json['changed_since_review'] as bool? ?? false,
      changedFields: json['changed_fields'] as String?,
    );
  }

  String toFormattedJson() =>
      const JsonEncoder.withIndent('  ').convert(toJson());

  /// Creates an UNREVIEWED decision as a placeholder for a new candidate.
  factory InboxDecision.unreviewed({
    required String canonicalId,
    required String cityId,
    required String packVersion,
    required String author,
    required InboxDecisionSnapshot snapshot,
  }) {
    return InboxDecision(
      canonicalId: canonicalId,
      cityId: cityId,
      packVersion: packVersion,
      verdict: InboxVerdict.unreviewed,
      author: author,
      decidedAt: DateTime.now().toIso8601String(),
      snapshot: snapshot,
    );
  }
}

/// Snapshot of key DataFactory fields at decision time.
/// Used to detect whether DataFactory regeneration changed something meaningful.
class InboxDecisionSnapshot {
  final Map<String, dynamic>? semanticFields;
  final String travelRelevanceReason;
  final double travelRelevanceScore;
  final double confidence;
  final String suggestedAction;
  final List<String> missingFields;

  const InboxDecisionSnapshot({
    this.semanticFields,
    required this.travelRelevanceReason,
    required this.travelRelevanceScore,
    required this.confidence,
    required this.suggestedAction,
    this.missingFields = const [],
  });

  Map<String, dynamic> toJson() => {
    if (semanticFields != null) 'semantic_fields': semanticFields,
    'travel_relevance_reason': travelRelevanceReason,
    'travel_relevance_score': travelRelevanceScore,
    'confidence': confidence,
    'suggested_action': suggestedAction,
    'missing_fields': missingFields,
  };

  factory InboxDecisionSnapshot.fromJson(Map<String, dynamic> json) {
    return InboxDecisionSnapshot(
      semanticFields: json['semantic_fields'] as Map<String, dynamic>?,
      travelRelevanceReason: json['travel_relevance_reason'] as String? ?? '',
      travelRelevanceScore:
          (json['travel_relevance_score'] as num?)?.toDouble() ?? 0.5,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      suggestedAction: json['suggested_action'] as String? ?? '',
      missingFields:
          (json['missing_fields'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}
