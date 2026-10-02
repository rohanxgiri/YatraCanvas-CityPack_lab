import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import 'review_candidate.dart';

String conflictMemberId(ReviewCandidate candidate) {
  final sourceIds =
      candidate.externalIds.entries
          .expand((entry) => entry.value.map((id) => '${entry.key}:$id'))
          .toSet()
          .toList()
        ..sort();
  final identity = sourceIds.isNotEmpty
      ? sourceIds.join('\n')
      : '${candidate.name}|${candidate.latitude}|${candidate.longitude}';
  return sha256.convert(utf8.encode(identity)).toString().substring(0, 16);
}

class IdentityConflict {
  final String canonicalId;
  final List<ReviewCandidate> members;
  final List<Map<String, dynamic>> rawMembers;
  final bool changed;
  final bool resolved;
  const IdentityConflict({
    required this.canonicalId,
    required this.members,
    required this.rawMembers,
    this.changed = false,
    this.resolved = false,
  });
  String get fileId => sha256.convert(utf8.encode(canonicalId)).toString();
  bool get affectsPublished => members.any((m) => m.isPublished);
  String get type {
    final identities = members.map(conflictMemberId).toSet();
    if (identities.length == 1) {
      return 'Repeated source identity with incompatible records';
    }
    return 'Canonical ID shared by different source identities';
  }

  double distance(ReviewCandidate a, ReviewCandidate b) {
    double radians(double degrees) => degrees * math.pi / 180;
    final dlat = radians(b.latitude - a.latitude);
    final dlon = radians(b.longitude - a.longitude);
    final h =
        math.pow(math.sin(dlat / 2), 2) +
        math.cos(radians(a.latitude)) *
            math.cos(radians(b.latitude)) *
            math.pow(math.sin(dlon / 2), 2);
    return 6371000 * 2 * math.asin(math.sqrt(h.clamp(0, 1)));
  }
}
