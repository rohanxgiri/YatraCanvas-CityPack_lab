enum ManualQaState {
  notStarted,
  inProgress,
  sufficientSample,
  insufficientSample,
}

class ManualQaSummary {
  final ManualQaState state;
  final int reviewedCount;
  final int minimumRequired;
  final int approvedCount;
  final int issueCount;
  final int uncertainCount;
  final double? score; // 0.0 to 1.0 (null if sample < minimumRequired)
  final String notes;

  const ManualQaSummary({
    required this.state,
    required this.reviewedCount,
    required this.minimumRequired,
    required this.approvedCount,
    required this.issueCount,
    required this.uncertainCount,
    this.score,
    this.notes = '',
  });

  bool get isSufficient => state == ManualQaState.sufficientSample;

  double get defectRate =>
      reviewedCount > 0 ? (issueCount / reviewedCount) : 0.0;

  String get displayStatus {
    switch (state) {
      case ManualQaState.notStarted:
        return 'NOT STARTED';
      case ManualQaState.inProgress:
        return 'PENDING ($reviewedCount/$minimumRequired)';
      case ManualQaState.sufficientSample:
        return 'PASSED (${(score! * 100).round()}%)';
      case ManualQaState.insufficientSample:
        return 'INSUFFICIENT SAMPLE ($reviewedCount/$minimumRequired)';
    }
  }

  factory ManualQaSummary.fromQaSession(dynamic session, {int minimumRequired = 50}) {
    if (session == null) {
      return ManualQaSummary(
        state: ManualQaState.notStarted,
        reviewedCount: 0,
        minimumRequired: minimumRequired,
        approvedCount: 0,
        issueCount: 0,
        uncertainCount: 0,
        score: null,
      );
    }

    final randomReviews = (session.randomReviews as List<dynamic>?) ?? [];
    final issues = (session.issues as List<dynamic>?) ?? [];

    final reviewed = randomReviews.length;
    final issueCount = issues.length;
    int approved = 0;
    int uncertain = 0;

    for (final r in randomReviews) {
      final res = r.result as String? ?? '';
      if (res == 'looks_good' || res == 'approved') {
        approved++;
      } else if (res == 'uncertain' || res == 'unsure') {
        uncertain++;
      }
    }

    ManualQaState state;
    double? score;

    if (reviewed == 0 && issueCount == 0) {
      state = ManualQaState.notStarted;
      score = null;
    } else if (reviewed < minimumRequired) {
      state = ManualQaState.insufficientSample;
      score = null;
    } else {
      state = ManualQaState.sufficientSample;
      final defectRate = (issueCount / reviewed).clamp(0.0, 1.0);
      score = (1.0 - defectRate).clamp(0.0, 1.0);
    }

    return ManualQaSummary(
      state: state,
      reviewedCount: reviewed,
      minimumRequired: minimumRequired,
      approvedCount: approved,
      issueCount: issueCount,
      uncertainCount: uncertain,
      score: score,
    );
  }

  Map<String, dynamic> toJson() => {
        'state': state.name,
        'reviewed_count': reviewedCount,
        'minimum_required': minimumRequired,
        'approved_count': approvedCount,
        'issue_count': issueCount,
        'uncertain_count': uncertainCount,
        'defect_rate': defectRate,
        'score': score,
        'notes': notes,
      };
}
