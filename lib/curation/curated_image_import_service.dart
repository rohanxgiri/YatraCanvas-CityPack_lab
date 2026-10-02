import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

class ImageImportException implements Exception {
  final String message;

  const ImageImportException(this.message);

  @override
  String toString() => message;
}

class ImportedPlaceImage {
  final String primaryImagePath;
  final String thumbnailImagePath;
  final int width;
  final int height;

  const ImportedPlaceImage({
    required this.primaryImagePath,
    required this.thumbnailImagePath,
    required this.width,
    required this.height,
  });
}

class _ProcessedImage {
  final Uint8List? primaryBytes;
  final Uint8List? thumbnailBytes;
  final int originalWidth;
  final int originalHeight;
  final int primaryWidth;
  final int primaryHeight;
  final String? errorMessage;

  const _ProcessedImage.success({
    required this.primaryBytes,
    required this.thumbnailBytes,
    required this.originalWidth,
    required this.originalHeight,
    required this.primaryWidth,
    required this.primaryHeight,
  }) : errorMessage = null;

  const _ProcessedImage.failure(this.errorMessage)
    : primaryBytes = null,
      thumbnailBytes = null,
      originalWidth = 0,
      originalHeight = 0,
      primaryWidth = 0,
      primaryHeight = 0;
}

_ProcessedImage _processImage(Uint8List sourceBytes) {
  final decoded = img.decodeImage(sourceBytes);
  if (decoded == null) {
    return const _ProcessedImage.failure(
      'This file is not a readable JPG, PNG, or WebP image.',
    );
  }

  final longEdge = decoded.width > decoded.height
      ? decoded.width
      : decoded.height;
  final shortEdge = decoded.width < decoded.height
      ? decoded.width
      : decoded.height;
  if (longEdge < CuratedImageImportService.minimumLongEdge ||
      shortEdge < CuratedImageImportService.minimumShortEdge) {
    return _ProcessedImage.failure(
      'This image is ${decoded.width} × ${decoded.height}. Use at least 640 × 480 pixels.',
    );
  }

  final primary = _resizeToLongEdge(
    decoded,
    CuratedImageImportService.primaryLongEdge,
  );
  final thumbnail = _resizeToLongEdge(
    decoded,
    CuratedImageImportService.thumbnailLongEdge,
  );
  return _ProcessedImage.success(
    primaryBytes: Uint8List.fromList(
      img.encodeWebP(primary, lossless: false, quality: 82, method: 4),
    ),
    thumbnailBytes: Uint8List.fromList(
      img.encodeWebP(thumbnail, lossless: false, quality: 76, method: 4),
    ),
    originalWidth: decoded.width,
    originalHeight: decoded.height,
    primaryWidth: primary.width,
    primaryHeight: primary.height,
  );
}

img.Image _resizeToLongEdge(img.Image source, int maximum) {
  final longEdge = source.width > source.height ? source.width : source.height;
  if (longEdge <= maximum) return img.Image.from(source);
  return source.width >= source.height
      ? img.copyResize(
          source,
          width: maximum,
          interpolation: img.Interpolation.average,
        )
      : img.copyResize(
          source,
          height: maximum,
          interpolation: img.Interpolation.average,
        );
}

class CuratedImageImportService {
  static const int maximumSourceBytes = 25 * 1024 * 1024;
  static const int minimumLongEdge = 640;
  static const int minimumShortEdge = 480;
  static const int primaryLongEdge = 1600;
  static const int thumbnailLongEdge = 480;

  final Directory? workspaceRoot;
  final DateTime Function() now;

  CuratedImageImportService({this.workspaceRoot, DateTime Function()? now})
    : now = now ?? DateTime.now;

  bool get canWriteToWorkspace => !kIsWeb;

  Directory get _workspaceRoot => workspaceRoot ?? Directory.current;

  Future<ImportedPlaceImage> importImage({
    required String cityId,
    required String placeId,
    required Uint8List sourceBytes,
    required String originalFilename,
    required String source,
    required String sourcePage,
    String author = '',
    required String license,
    required String licenseUrl,
    required String contributor,
  }) async {
    if (kIsWeb) {
      throw const ImageImportException(
        'Photo import writes Git tracked files and is available in the desktop app.',
      );
    }
    if (sourceBytes.isEmpty) {
      throw const ImageImportException('Choose an image file to continue.');
    }
    if (sourceBytes.length > maximumSourceBytes) {
      throw const ImageImportException(
        'The image is larger than 25 MB. Choose a smaller file.',
      );
    }
    if (source.trim().isEmpty || license.trim().isEmpty) {
      throw const ImageImportException(
        'Add the source and licence before importing.',
      );
    }

    final processed = await compute(_processImage, sourceBytes);
    if (processed.errorMessage != null) {
      throw ImageImportException(processed.errorMessage!);
    }
    if (author.trim().isEmpty || licenseUrl.trim().isEmpty ||
        (sourcePage.trim().isEmpty && source.trim().toLowerCase() != 'own work')) {
      throw const ImageImportException('Add the photographer or author, source page and license URL. Own work may omit the source page.');
    }

    final safeCityId = _safeSegment(cityId, label: 'city');
    final safePlaceId = _safeSegment(placeId, label: 'place');
    final curatedFolder = 'curated_${safePlaceId}_${sha256.convert(sourceBytes).toString().substring(0, 12)}';
    final packRelativePrimary = p.posix.join(
      'images',
      curatedFolder,
      'primary.webp',
    );
    final packRelativeThumbnail = p.posix.join(
      'images',
      curatedFolder,
      'thumbnail.webp',
    );

    final imageDirectory = Directory(
      p.join(
        _workspaceRoot.path,
        'assets',
        'city_packs',
        safeCityId,
        'images',
        curatedFolder,
      ),
    );
    final mediaDirectory = Directory(
      p.join(
        _workspaceRoot.path,
        'assets',
        'city_packs',
        safeCityId,
        'curation',
        'media',
      ),
    );
    await imageDirectory.create(recursive: true);
    await mediaDirectory.create(recursive: true);

    final primaryFile = File(p.join(imageDirectory.path, 'primary.webp'));
    final thumbnailFile = File(p.join(imageDirectory.path, 'thumbnail.webp'));
    final metadataFile = File(p.join(mediaDirectory.path, '$safePlaceId.json'));

    final metadata = <String, dynamic>{
      'schemaVersion': 1,
      'cityId': safeCityId,
      'placeId': safePlaceId,
      'primaryImagePath': packRelativePrimary,
      'thumbnailImagePath': packRelativeThumbnail,
      'originalFilename': p.basename(originalFilename),
      'originalSha256': sha256.convert(sourceBytes).toString(),
      'source': source.trim(),
      'sourcePage': sourcePage.trim(),
      'author': author.trim(),
      'license': license.trim(),
      'licenseUrl': licenseUrl.trim(),
      'originalWidth': processed.originalWidth,
      'originalHeight': processed.originalHeight,
      'primaryWidth': processed.primaryWidth,
      'primaryHeight': processed.primaryHeight,
      'contributor': contributor.trim().isEmpty
          ? 'Contributor'
          : contributor.trim(),
      'importedAt': now().toUtc().toIso8601String(),
    };
    final metadataBytes = utf8.encode(
      '${const JsonEncoder.withIndent('  ').convert(metadata)}\n',
    );

    await _registerAssetDirectory(safeCityId, curatedFolder);
    await _replaceFiles(
      primaryFile: primaryFile,
      primaryBytes: processed.primaryBytes!,
      thumbnailFile: thumbnailFile,
      thumbnailBytes: processed.thumbnailBytes!,
      metadataFile: metadataFile,
      metadataBytes: metadataBytes,
    );

    return ImportedPlaceImage(
      primaryImagePath: packRelativePrimary,
      thumbnailImagePath: packRelativeThumbnail,
      width: processed.primaryWidth,
      height: processed.primaryHeight,
    );
  }

  String _safeSegment(String value, {required String label}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == '.' || trimmed == '..') {
      throw ImageImportException('The $label identifier is invalid.');
    }
    final safe = trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    if (safe.contains('..')) {
      throw ImageImportException('The $label identifier is invalid.');
    }
    return safe;
  }

  Future<void> _registerAssetDirectory(String cityId, String placeId) async {
    final pubspec = File(p.join(_workspaceRoot.path, 'pubspec.yaml'));
    if (!await pubspec.exists()) {
      throw const ImageImportException(
        'pubspec.yaml was not found at the workspace root.',
      );
    }
    final assetLine = '    - assets/city_packs/$cityId/images/$placeId/';
    final content = await pubspec.readAsString();
    if (content.contains(assetLine)) return;

    final assetsHeader = RegExp(
      r'^  assets:[ \t\r]*$',
      multiLine: true,
    ).firstMatch(content);
    if (assetsHeader == null) {
      throw const ImageImportException(
        'The Flutter assets section is missing from pubspec.yaml.',
      );
    }
    final newline = content.contains('\r\n') ? '\r\n' : '\n';
    final headerLineEnd = content.indexOf('\n', assetsHeader.start);
    final insertAt = headerLineEnd < 0 ? content.length : headerLineEnd + 1;
    final separator = headerLineEnd < 0 ? newline : '';
    final updated =
        '${content.substring(0, insertAt)}$separator$assetLine$newline${content.substring(insertAt)}';
    await pubspec.writeAsString(updated, flush: true);
  }

  Future<void> _replaceFiles({
    required File primaryFile,
    required List<int> primaryBytes,
    required File thumbnailFile,
    required List<int> thumbnailBytes,
    required File metadataFile,
    required List<int> metadataBytes,
  }) async {
    final payloads = <File, List<int>>{
      primaryFile: primaryBytes,
      thumbnailFile: thumbnailBytes,
      metadataFile: metadataBytes,
    };

    final backups = <File, File>{};
    final temporary = <File, File>{};
    try {
      for (final entry in payloads.entries) {
        final temp = File('${entry.key.path}.importing');
        if (await temp.exists()) await temp.delete();
        await temp.writeAsBytes(entry.value, flush: true);
        temporary[entry.key] = temp;
      }
      for (final target in payloads.keys) {
        if (await target.exists()) {
          final backup = File('${target.path}.previous');
          if (await backup.exists()) await backup.delete();
          await target.rename(backup.path);
          backups[target] = backup;
        }
      }
      for (final entry in temporary.entries) {
        await entry.value.rename(entry.key.path);
      }
      for (final backup in backups.values) {
        if (await backup.exists()) {
          await backup.delete();
        }
      }
    } catch (error) {
      for (final target in payloads.keys) {
        if (await target.exists() && backups.containsKey(target)) {
          await target.delete();
        }
      }
      for (final entry in backups.entries) {
        if (await entry.value.exists()) {
          await entry.value.rename(entry.key.path);
        }
      }
      for (final temp in temporary.values) {
        if (await temp.exists()) {
          await temp.delete();
        }
      }
      throw ImageImportException('The image could not be saved: $error');
    }
  }
}
