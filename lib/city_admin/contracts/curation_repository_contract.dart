import '../../domain/curation/curation_issue.dart';
import '../../domain/curation/place_addition.dart';
import '../../domain/curation/place_exclusion.dart';
import '../../domain/curation/place_override.dart';
import '../../domain/curation/place_review.dart';

/// Storage contract for human curation.
///
/// The City Admin core depends on this interface. The standalone lab supplies a
/// file backed implementation today. A future authenticated admin application
/// can supply an API backed implementation without changing curation rules.
abstract interface class CurationRepositoryContract {
  Future<List<PlaceOverride>> loadOverrides(String cityId);

  Future<void> saveOverride(PlaceOverride override);

  Future<void> deleteOverride(String cityId, String placeId);

  Future<List<PlaceAddition>> loadAdditions(String cityId);

  Future<void> saveAddition(PlaceAddition addition);

  Future<void> deleteAddition(String cityId, String additionId);

  Future<List<PlaceExclusion>> loadExclusions(String cityId);

  Future<void> saveExclusion(PlaceExclusion exclusion);

  Future<void> deleteExclusion(String cityId, String placeId);

  Future<List<PlaceReview>> loadReviews(String cityId);

  Future<void> saveReview(PlaceReview review);

  Future<List<CurationIssue>> loadIssues(String cityId);

  Future<void> saveIssue(CurationIssue issue);

  Future<void> deleteIssue(String cityId, String issueId);
}
