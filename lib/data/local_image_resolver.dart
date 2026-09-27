import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class LocalImageResolver {
  final String cityId;
  final String imagesDirPath;

  LocalImageResolver({
    required this.cityId,
    required this.imagesDirPath,
  });

  /// Resolves the local image file for a place, or null if no local image exists.
  /// Strictly checks local filesystem only. NEVER requests external networks.
  File? resolveImage(String? relativeImagePath) {
    if (kIsWeb) {
      return null;
    }
    if (relativeImagePath == null || relativeImagePath.trim().isEmpty) {
      return null;
    }

    final cleanRel = relativeImagePath.replaceAll('\\', '/');

    // Candidate 1: imagesDirPath + relative path
    if (imagesDirPath.isNotEmpty) {
      // If relative path already starts with 'images/', avoid duplicate 'images/images/'
      String subPath = cleanRel;
      if (subPath.startsWith('images/')) {
        subPath = subPath.substring('images/'.length);
      }
      final file = File(p.join(imagesDirPath, subPath));
      if (file.existsSync()) {
        return file;
      }
      // Also try direct join
      final file2 = File(p.join(imagesDirPath, cleanRel));
      if (file2.existsSync()) {
        return file2;
      }
    }

    // Candidate 2: assets/city_packs/<cityId>/<relativeImagePath>
    final assetFile = File('assets/city_packs/$cityId/$cleanRel');
    if (assetFile.existsSync()) {
      return assetFile;
    }

    return null;
  }

  String? resolveAssetPath(String? relativeImagePath) {
    if (relativeImagePath == null || relativeImagePath.trim().isEmpty) {
      return null;
    }
    final cleanRel = relativeImagePath.replaceAll('\\', '/');
    return 'assets/city_packs/$cityId/$cleanRel';
  }
}
