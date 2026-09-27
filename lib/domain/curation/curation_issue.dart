import 'dart:convert';

enum CurationIssueStatus {
  open,
  assigned,
  fixed,
  verified,
  ignored;

  String get code => name;

  String get label {
    switch (this) {
      case CurationIssueStatus.open:
        return 'Open';
      case CurationIssueStatus.assigned:
        return 'Assigned';
      case CurationIssueStatus.fixed:
        return 'Fixed';
      case CurationIssueStatus.verified:
        return 'Verified';
      case CurationIssueStatus.ignored:
        return 'Ignored';
    }
  }

  static CurationIssueStatus fromCode(String? code) {
    if (code == null) return CurationIssueStatus.open;
    for (final s in CurationIssueStatus.values) {
      if (s.name == code.toLowerCase() || s.code == code.toLowerCase()) {
        return s;
      }
    }
    return CurationIssueStatus.open;
  }
}

/// Represents an actionable issue logged against a place.
/// Stored deterministically as an entity-level JSON file in:
/// `assets/city_packs/<city>/curation/issues/<issue_id>.json`
class CurationIssue {
  final String id;
  final String placeId;
  final String cityId;
  final String placeName;
  final String issueType; // wrong_image, wrong_hours, wrong_location, wrong_category, duplicate, closed, other
  final CurationIssueStatus status;
  final String? assignedTo;
  final String note;
  final String author;
  final String createdAt;
  final String updatedAt;
  final String? resolvedAt;
  final String? resolutionNote;

  const CurationIssue({
    required this.id,
    required this.placeId,
    required this.cityId,
    required this.placeName,
    required this.issueType,
    this.status = CurationIssueStatus.open,
    this.assignedTo,
    required this.note,
    required this.author,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    this.resolutionNote,
  });

  bool get isOpen => status == CurationIssueStatus.open || status == CurationIssueStatus.assigned;
  bool get isResolved => status == CurationIssueStatus.fixed || status == CurationIssueStatus.verified || status == CurationIssueStatus.ignored;

  CurationIssue copyWith({
    CurationIssueStatus? status,
    String? assignedTo,
    String? note,
    String? updatedAt,
    String? resolvedAt,
    String? resolutionNote,
  }) {
    return CurationIssue(
      id: id,
      placeId: placeId,
      cityId: cityId,
      placeName: placeName,
      issueType: issueType,
      status: status ?? this.status,
      assignedTo: assignedTo ?? this.assignedTo,
      note: note ?? this.note,
      author: author,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolutionNote: resolutionNote ?? this.resolutionNote,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'place_id': placeId,
      'city_id': cityId,
      'place_name': placeName,
      'issue_type': issueType,
      'status': status.code,
      'note': note,
      'author': author,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
    if (assignedTo != null) map['assigned_to'] = assignedTo;
    if (resolvedAt != null) map['resolved_at'] = resolvedAt;
    if (resolutionNote != null) map['resolution_note'] = resolutionNote;
    return map;
  }

  factory CurationIssue.fromJson(Map<String, dynamic> json) {
    return CurationIssue(
      id: json['id'] as String,
      placeId: json['place_id'] as String,
      cityId: json['city_id'] as String,
      placeName: json['place_name'] as String? ?? 'Unnamed Place',
      issueType: json['issue_type'] as String? ?? 'other',
      status: CurationIssueStatus.fromCode(json['status'] as String?),
      assignedTo: json['assigned_to'] as String?,
      note: json['note'] as String? ?? '',
      author: json['author'] as String? ?? 'contributor',
      createdAt: json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      updatedAt: json['updated_at'] as String? ?? DateTime.now().toIso8601String(),
      resolvedAt: json['resolved_at'] as String?,
      resolutionNote: json['resolution_note'] as String?,
    );
  }

  String toFormattedJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}
