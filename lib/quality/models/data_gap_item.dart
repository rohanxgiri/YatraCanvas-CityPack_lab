enum GapSeverity {
  critical,
  warning,
  info,
}

class DataGapItem {
  final String id;
  final String title;
  final int count;
  final GapSeverity severity;
  final String reason;
  final List<String> affectedPlaceIds;
  final String? filterPreset;

  const DataGapItem({
    required this.id,
    required this.title,
    required this.count,
    required this.severity,
    required this.reason,
    this.affectedPlaceIds = const [],
    this.filterPreset,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'count': count,
        'severity': severity.name,
        'reason': reason,
        'affected_count': affectedPlaceIds.length,
        'filter_preset': filterPreset,
      };
}
