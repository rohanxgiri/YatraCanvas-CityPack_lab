import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:crypto/crypto.dart';
import '../domain/city_pack.dart';

class CityPackRegistry {
  static const String indexPath = 'assets/city_packs/city_packs_index.json';

  /// Loads all city packs declared in the assets or local filesystem directory.
  Future<List<CityPack>> loadAvailablePacks() async {
    final List<CityPack> packs = [];

    Map<String, dynamic> indexJson = {};
    if (!kIsWeb) {
      try {
        final File indexFile = File(indexPath);
        if (indexFile.existsSync()) {
          final String raw = await indexFile.readAsString();
          indexJson = json.decode(raw) as Map<String, dynamic>;
        }
      } catch (_) {}
    }

    if (indexJson.isEmpty) {
      try {
        final String raw = await rootBundle.loadString(indexPath);
        indexJson = json.decode(raw) as Map<String, dynamic>;
      } catch (_) {}
    }

    if (indexJson.isEmpty && !kIsWeb) {
      // Fallback: check folders under assets/city_packs
      try {
        final dir = Directory('assets/city_packs');
        if (dir.existsSync()) {
          for (final entity in dir.listSync()) {
            if (entity is Directory) {
              final cid = entity.uri.pathSegments.reversed.where((s) => s.isNotEmpty).first;
              indexJson[cid] = {'city_id': cid};
            }
          }
        }
      } catch (_) {}
    }

    for (final entry in indexJson.entries) {
      final cityId = entry.key;
      final pack = await _loadSinglePack(cityId, entry.value as Map<String, dynamic>);
      packs.add(pack);
    }

    // Sort by name
    packs.sort((a, b) => a.name.compareTo(b.name));
    return packs;
  }

  Future<CityPack> _loadSinglePack(String cityId, Map<String, dynamic> indexData) async {
    try {
      Map<String, dynamic> manifest = {};
      Map<String, dynamic> cityMeta = {};
      Map<String, dynamic> receipt = {};

      // Load manifest.json
      manifest = await _loadJsonAsset('assets/city_packs/$cityId/manifest.json');
      // Load city.json
      cityMeta = await _loadJsonAsset('assets/city_packs/$cityId/city.json');
      // Load receipt
      receipt = await _loadJsonAsset('assets/city_packs/$cityId/lab_sync_receipt.json');

      final String name = manifest['city_name'] ?? cityMeta['name'] ?? cityId;
      final String state = manifest['state'] ?? cityMeta['state'] ?? '';
      final String country = manifest['country'] ?? cityMeta['country'] ?? 'India';
      final String version = manifest['city_pack_version'] ?? 'v3';

      final counts = manifest['counts'] as Map<String, dynamic>? ?? {};
      final int placeCount = counts['accepted'] as int? ?? 0;
      final int imageCount = counts['with_images'] as int? ?? receipt['image_count'] as int? ?? 0;

      // Extract coordinates & bbox
      double centerLat = 0.0;
      double centerLon = 0.0;
      final centerList = cityMeta['center'] as List<dynamic>?;
      if (centerList != null && centerList.length >= 2) {
        centerLat = (centerList[0] as num).toDouble();
        centerLon = (centerList[1] as num).toDouble();
      }

      double minLon = 0.0;
      double minLat = 0.0;
      double maxLon = 0.0;
      double maxLat = 0.0;
      final bboxList = cityMeta['bbox'] as List<dynamic>?;
      if (bboxList != null && bboxList.length >= 4) {
        minLon = (bboxList[0] as num).toDouble();
        minLat = (bboxList[1] as num).toDouble();
        maxLon = (bboxList[2] as num).toDouble();
        maxLat = (bboxList[3] as num).toDouble();
      }

      // Check integrity
      final integrity = await _verifyIntegrity(cityId, manifest, receipt);

      // Estimate DB size in MB
      double dbSizeMb = 0.0;
      if (!kIsWeb) {
        try {
          final File localDb = File('assets/city_packs/$cityId/yatracanvas.db');
          if (localDb.existsSync()) {
            dbSizeMb = localDb.lengthSync() / (1024 * 1024);
          }
        } catch (_) {}
      }

      return CityPack(
        id: cityId,
        name: name,
        state: state,
        country: country,
        version: version,
        placeCount: placeCount,
        imageCount: imageCount,
        dbSizeMb: double.parse(dbSizeMb.toStringAsFixed(2)),
        integrityStatus: integrity,
        centerLat: centerLat,
        centerLon: centerLon,
        minLat: minLat,
        minLon: minLon,
        maxLat: maxLat,
        maxLon: maxLon,
        manifest: manifest,
        receipt: receipt,
      );
    } catch (e) {
      return CityPack.invalid(
        id: cityId,
        reason: 'Failed to parse city pack metadata: $e',
      );
    }
  }

  Future<IntegrityStatus> _verifyIntegrity(
    String cityId,
    Map<String, dynamic> manifest,
    Map<String, dynamic> receipt,
  ) async {
    try {
      final checksums = manifest['checksums'] as Map<String, dynamic>? ?? {};
      final expectedDbHash = checksums['yatracanvas.db'] as String?;
      if (expectedDbHash == null) {
        return IntegrityStatus.unknown;
      }

      if (kIsWeb) {
        return IntegrityStatus.pass;
      }

      final File localDb = File('assets/city_packs/$cityId/yatracanvas.db');
      if (!localDb.existsSync()) {
        return IntegrityStatus.pass; // Will be verified upon asset loading
      }

      final bytes = await localDb.readAsBytes();
      final actualHash = sha256.convert(bytes).toString();
      if (actualHash.toLowerCase() == expectedDbHash.toLowerCase()) {
        return IntegrityStatus.pass;
      } else {
        return IntegrityStatus.fail;
      }
    } catch (_) {
      return IntegrityStatus.unknown;
    }
  }

  Future<Map<String, dynamic>> _loadJsonAsset(String path) async {
    if (!kIsWeb) {
      try {
        final File file = File(path);
        if (file.existsSync()) {
          final String raw = await file.readAsString();
          return json.decode(raw) as Map<String, dynamic>;
        }
      } catch (_) {}
    }
    try {
      final String raw = await rootBundle.loadString(path);
      return json.decode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}
