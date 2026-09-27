import 'dart:math' as math;
import 'lab_place.dart';

class TripSelection {
  final String cityId;
  int tripDays;
  final Map<String, int> placeDays; // placeId -> day (1..tripDays)

  TripSelection({
    required this.cityId,
    this.tripDays = 3,
    Map<String, int>? placeDays,
  }) : placeDays = placeDays ?? {};

  bool contains(String placeId) => placeDays.containsKey(placeId);

  int? getDayFor(String placeId) => placeDays[placeId];

  void addPlace(String placeId, {int day = 1}) {
    placeDays[placeId] = day.clamp(1, tripDays);
  }

  void removePlace(String placeId) {
    placeDays.remove(placeId);
  }

  void assignDay(String placeId, int day) {
    if (placeDays.containsKey(placeId)) {
      placeDays[placeId] = day.clamp(1, tripDays);
    }
  }

  void setDays(int days) {
    tripDays = days.clamp(1, 7);
    for (final entry in placeDays.entries) {
      if (entry.value > tripDays) {
        placeDays[entry.key] = tripDays;
      }
    }
  }

  void clear() {
    placeDays.clear();
  }

  /// Simple Lab geographic grouping based strictly on coordinates (K-Means/Distance grouping).
  /// Labeled: "Lab geographic grouping — not YatraCanvas itinerary optimization".
  void groupGeographically(List<LabPlace> places) {
    if (places.isEmpty || tripDays <= 1) return;

    // Filter only places in this basket
    final basketPlaces = places.where((p) => placeDays.containsKey(p.id)).toList();
    if (basketPlaces.length <= tripDays) {
      for (int i = 0; i < basketPlaces.length; i++) {
        placeDays[basketPlaces[i].id] = (i % tripDays) + 1;
      }
      return;
    }

    // Sort by latitude or cluster into `tripDays` geographic buckets
    basketPlaces.sort((a, b) {
      final cmp = a.latitude.compareTo(b.latitude);
      return cmp != 0 ? cmp : a.longitude.compareTo(b.longitude);
    });

    final chunkSize = (basketPlaces.length / tripDays).ceil();
    for (int i = 0; i < basketPlaces.length; i++) {
      final day = (i ~/ chunkSize) + 1;
      placeDays[basketPlaces[i].id] = math.min(day, tripDays);
    }
  }
}
