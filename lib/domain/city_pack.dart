enum IntegrityStatus { pass, fail, unknown }

class CityPack {
  final String id;
  final String name;
  final String state;
  final String country;
  final String version;
  final int placeCount;
  final int imageCount;
  final double dbSizeMb;
  final IntegrityStatus integrityStatus;
  final double centerLat;
  final double centerLon;
  final double minLat;
  final double minLon;
  final double maxLat;
  final double maxLon;
  final Map<String, dynamic> manifest;
  final Map<String, dynamic> receipt;
  final bool isValid;
  final String? invalidReason;

  const CityPack({
    required this.id,
    required this.name,
    required this.state,
    required this.country,
    required this.version,
    required this.placeCount,
    required this.imageCount,
    required this.dbSizeMb,
    required this.integrityStatus,
    required this.centerLat,
    required this.centerLon,
    required this.minLat,
    required this.minLon,
    required this.maxLat,
    required this.maxLon,
    this.manifest = const {},
    this.receipt = const {},
    this.isValid = true,
    this.invalidReason,
  });

  factory CityPack.invalid({
    required String id,
    required String reason,
    String? name,
  }) {
    return CityPack(
      id: id,
      name: name ?? id,
      state: 'Unknown',
      country: 'Unknown',
      version: 'N/A',
      placeCount: 0,
      imageCount: 0,
      dbSizeMb: 0.0,
      integrityStatus: IntegrityStatus.fail,
      centerLat: 0.0,
      centerLon: 0.0,
      minLat: 0.0,
      minLon: 0.0,
      maxLat: 0.0,
      maxLon: 0.0,
      isValid: false,
      invalidReason: reason,
    );
  }
}
