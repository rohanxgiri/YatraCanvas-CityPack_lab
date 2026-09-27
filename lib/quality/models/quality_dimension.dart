enum DimensionStatus {
  pass,
  warning,
  fail,
  unknown,
  notMeasured,
}

class QualityDimension {
  final String id;
  final String label;
  final double? score; // 0.0 to 1.0, or null if unknown/notMeasured
  final double weight;
  final DimensionStatus status;
  final String reason;
  final int affectedCount;
  final List<String> affectedRecordIds;

  const QualityDimension({
    required this.id,
    required this.label,
    this.score,
    required this.weight,
    required this.status,
    required this.reason,
    this.affectedCount = 0,
    this.affectedRecordIds = const [],
  });

  String get displayPercentage {
    if (status == DimensionStatus.unknown) return 'UNKNOWN';
    if (status == DimensionStatus.notMeasured) return 'NOT MEASURED';
    if (score == null) return 'N/A';
    return '${(score! * 100).round()}%';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'score': score,
        'weight': weight,
        'status': status.name,
        'reason': reason,
        'affected_count': affectedCount,
        'affected_record_ids': affectedRecordIds.take(50).toList(),
      };
}
