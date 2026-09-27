enum ReleaseStatus {
  ready,
  reviewRequired,
  blocked,
}

class ReleaseGateResult {
  final ReleaseStatus status;
  final List<String> criticalBlockers;
  final List<String> warnings;
  final Map<String, bool> checks;
  final String timestamp;

  const ReleaseGateResult({
    required this.status,
    required this.criticalBlockers,
    required this.warnings,
    required this.checks,
    required this.timestamp,
  });

  bool get isReady => status == ReleaseStatus.ready;
  bool get isBlocked => status == ReleaseStatus.blocked;
  bool get isReviewRequired => status == ReleaseStatus.reviewRequired;

  String get displayStatus {
    switch (status) {
      case ReleaseStatus.ready:
        return 'READY';
      case ReleaseStatus.reviewRequired:
        return 'REVIEW REQUIRED';
      case ReleaseStatus.blocked:
        return 'BLOCKED';
    }
  }

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'display_status': displayStatus,
        'critical_blockers': criticalBlockers,
        'warnings': warnings,
        'checks': checks,
        'timestamp': timestamp,
      };
}
