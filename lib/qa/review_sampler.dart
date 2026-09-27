import '../data/local_place_repository.dart';
import '../domain/lab_place.dart';

class ReviewSampler {
  final LocalPlaceRepository repository;

  ReviewSampler(this.repository);

  Future<List<LabPlace>> samplePlaces({
    required int sampleSize,
    String? tier,
    String? category,
    int seed = 42,
  }) async {
    return repository.getRandomPlaces(
      count: sampleSize,
      tier: tier,
      category: category,
      seed: seed,
    );
  }
}
