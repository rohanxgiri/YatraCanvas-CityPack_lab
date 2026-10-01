/// lib/review/services/review_reason_translator.dart
///
/// Translates DataFactory machine reason codes into human-friendly titles,
/// descriptions, and recommended City Lab actions.
///
/// When a new reason code appears that is not registered here, the translator
/// returns a safe "unknown" fallback so City Lab does not crash.
library;

class ReasonTranslation {
  final String code;
  final String title;
  final String description;
  final String recommendedAction;
  final bool isCritical;

  const ReasonTranslation({
    required this.code,
    required this.title,
    required this.description,
    required this.recommendedAction,
    this.isCritical = false,
  });
}

class SuggestedActionTranslation {
  final String code;
  final String keepLabel;
  final String excludeLabel;
  final String reviewLabel;

  const SuggestedActionTranslation({
    required this.code,
    required this.keepLabel,
    required this.excludeLabel,
    required this.reviewLabel,
  });
}

class ReviewReasonTranslator {
  static const Map<String, ReasonTranslation> _reasons = {
    'CONTRADICTORY_BUILDING_AMENITY': ReasonTranslation(
      code: 'CONTRADICTORY_BUILDING_AMENITY',
      title: 'Conflicting place type',
      description:
          'This place has tourism or hospitality metadata but is also mapped '
          'as a residential building in OpenStreetMap. Verify whether it is '
          'genuinely a public place or a misclassified home.',
      recommendedAction:
          'Check OSM tags. If it is a real business, keep it. '
          'If it is a home address, exclude it.',
      isCritical: true,
    ),
    'SECONDARY_COMMERCIAL_REQUIRES_AUDIT': ReasonTranslation(
      code: 'SECONDARY_COMMERCIAL_REQUIRES_AUDIT',
      title: 'Secondary commercial place',
      description:
          'DataFactory flagged this as a commercial place (hotel, restaurant, '
          'shop, etc.) that could be useful to travellers but needs a human '
          'to confirm it meets the city pack quality bar. '
          'Most of these are straightforward approvals.',
      recommendedAction:
          'If the place is real, open, and relevant to travellers, '
          'keep it. If it seems closed, irrelevant, or low quality, exclude it.',
      isCritical: false,
    ),
    'INSUFFICIENT_TRAVEL_EVIDENCE': ReasonTranslation(
      code: 'INSUFFICIENT_TRAVEL_EVIDENCE',
      title: 'Weak travel evidence',
      description:
          'This place does not have enough signals (sources, ratings, '
          'descriptions) to confirm it is worth including in a travel city pack.',
      recommendedAction:
          'Research whether the place has a meaningful presence. '
          'If yes, keep it. If no clear travel value, exclude it.',
      isCritical: false,
    ),
    'POSSIBLE_DUPLICATE': ReasonTranslation(
      code: 'POSSIBLE_DUPLICATE',
      title: 'Possible duplicate',
      description:
          'DataFactory found another place with a very similar name and nearby '
          'coordinates. This might be the same place recorded twice.',
      recommendedAction:
          'Compare the two candidates. Keep the better one and exclude the other.',
      isCritical: false,
    ),
    'COORDINATE_OUTLIER': ReasonTranslation(
      code: 'COORDINATE_OUTLIER',
      title: 'Suspicious coordinates',
      description:
          'This place is located outside the expected city boundary or far '
          'from its expected neighbourhood.',
      recommendedAction:
          'Verify the coordinates. Correct them via the Edit action '
          'or exclude if the location is wrong.',
      isCritical: true,
    ),
    'IMAGE_IDENTITY_CONFLICT': ReasonTranslation(
      code: 'IMAGE_IDENTITY_CONFLICT',
      title: 'Image identity conflict',
      description:
          'The proposed image may depict a different place than the one listed. '
          'Multiple sources disagree on what image belongs here.',
      recommendedAction:
          'Review the image. Accept it if it depicts the correct place, '
          'or reject and replace it.',
      isCritical: false,
    ),
    'AMBIGUOUS_CATEGORY': ReasonTranslation(
      code: 'AMBIGUOUS_CATEGORY',
      title: 'Ambiguous category',
      description:
          'Sources disagree on whether this is a temple, heritage site, or '
          'another category. The classification affects how it appears in itineraries.',
      recommendedAction:
          'Pick the most accurate category using the Edit action.',
      isCritical: false,
    ),
  };

  static const Map<String, SuggestedActionTranslation> _actions = {
    'APPROVE_AS_SECONDARY_DESTINATION': SuggestedActionTranslation(
      code: 'APPROVE_AS_SECONDARY_DESTINATION',
      keepLabel: 'Keep in City Pack',
      excludeLabel: 'Exclude from City Pack',
      reviewLabel: 'Needs More Investigation',
    ),
    'VERIFY_AMENITY_SIGNIFICANCE': SuggestedActionTranslation(
      code: 'VERIFY_AMENITY_SIGNIFICANCE',
      keepLabel: 'Confirmed — Keep in City Pack',
      excludeLabel: 'Exclude (not a public place)',
      reviewLabel: 'Flag for Further Research',
    ),
    'EXCLUDE_AS_DUPLICATE': SuggestedActionTranslation(
      code: 'EXCLUDE_AS_DUPLICATE',
      keepLabel: 'Keep (not a duplicate)',
      excludeLabel: 'Exclude (confirmed duplicate)',
      reviewLabel: 'Investigate further',
    ),
    'CORRECT_COORDINATES': SuggestedActionTranslation(
      code: 'CORRECT_COORDINATES',
      keepLabel: 'Keep with corrected coordinates',
      excludeLabel: 'Exclude (coordinates unresolvable)',
      reviewLabel: 'Flag for coordinate correction',
    ),
  };

  static const _unknownReason = ReasonTranslation(
    code: 'UNKNOWN',
    title: 'Unknown issue type',
    description:
        'DataFactory flagged this place for review but the reason code is '
        'not recognised by this version of City Lab. '
        'Check the technical details below.',
    recommendedAction:
        'Review the raw reason code in the expanded technical details '
        'and make a judgment call.',
    isCritical: false,
  );

  static const _unknownAction = SuggestedActionTranslation(
    code: 'UNKNOWN',
    keepLabel: 'Keep in City Pack',
    excludeLabel: 'Exclude from City Pack',
    reviewLabel: 'Flag for Investigation',
  );

  static ReasonTranslation translateReason(String code) {
    return _reasons[code] ?? _unknownReason;
  }

  static SuggestedActionTranslation translateAction(String code) {
    return _actions[code] ?? _unknownAction;
  }

  /// Returns all reason codes that are currently unknown (not in the dictionary).
  /// Used to surface "Update City Lab" warnings.
  static List<String> findUnknownCodes(List<String> seenCodes) {
    return seenCodes.where((c) => !_reasons.containsKey(c)).toList();
  }
}
