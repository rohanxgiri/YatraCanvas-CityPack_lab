import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'city_pack_database.dart';

class LoadedCityPackContext {
  final String cityId;
  final String dbPath;
  final String imagesDirPath;
  final Database database;
  final CityPackDatabase packDatabase;

  LoadedCityPackContext({
    required this.cityId,
    required this.dbPath,
    required this.imagesDirPath,
    required this.database,
    required this.packDatabase,
  });
}

class CityPackLoader {
  static bool _ffiInitialized = false;
  static Directory? _overrideSupportDir;

  static void setOverrideDirectory(Directory? dir) {
    _overrideSupportDir = dir;
  }

  static void initFfiIfNeeded() {
    if (!_ffiInitialized) {
      if (kIsWeb) {
        databaseFactory = databaseFactoryFfiWeb;
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        sqfliteFfiInit();
        databaseFactory = createDatabaseFactoryFfi(noIsolate: true);
      }
      _ffiInitialized = true;
    }
  }

  /// Copies the bundled database to a runtime location in ApplicationSupportDirectory
  /// and opens it in strictly READ-ONLY mode.
  Future<LoadedCityPackContext> openCityPack(String cityId) async {
    initFfiIfNeeded();

    if (kIsWeb) {
      final dbName = '$cityId.db';
      final assetPath = 'assets/city_packs/$cityId/yatracanvas.db';
      final byteData = await rootBundle.load(assetPath);
      final bytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
      await databaseFactory.writeDatabaseBytes(dbName, bytes);
      final db = await databaseFactory.openDatabase(
        dbName,
        options: OpenDatabaseOptions(readOnly: true),
      );
      final packDb = CityPackDatabase(db, cityId);
      return LoadedCityPackContext(
        cityId: cityId,
        dbPath: dbName,
        imagesDirPath: 'assets/city_packs/$cityId/images',
        database: db,
        packDatabase: packDb,
      );
    }

    Directory targetDir;
    if (_overrideSupportDir != null) {
      targetDir = Directory(
        p.join(_overrideSupportDir!.path, 'city_packs', cityId),
      );
    } else {
      try {
        final appSupport = await getApplicationSupportDirectory();
        targetDir = Directory(p.join(appSupport.path, 'city_packs', cityId));
      } catch (_) {
        // Fallback for tests or environments where path_provider is not mocked
        targetDir = Directory(
          p.join(Directory.systemTemp.path, 'yatracanvas_lab', cityId),
        );
      }
    }

    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }

    final targetDbFile = File(p.join(targetDir.path, 'yatracanvas.db'));

    // Check if we have bundled file on local filesystem (desktop / tests)
    final localAssetDb = File('assets/city_packs/$cityId/yatracanvas.db');
    if (localAssetDb.existsSync()) {
      // SQLite files can change without changing size. Always refresh the
      // disposable runtime copy when reopening a synchronized pack.
      await localAssetDb.copy(targetDbFile.path);
    } else {
      // Load from Flutter asset bundle (mobile)
      final byteData = await rootBundle.load(
        'assets/city_packs/$cityId/yatracanvas.db',
      );
      final buffer = byteData.buffer;
      await targetDbFile.writeAsBytes(
        buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
        flush: true,
      );
    }

    // Determine images directory
    String imagesDirPath = '';
    final localImagesDir = Directory('assets/city_packs/$cityId/images');
    if (localImagesDir.existsSync()) {
      imagesDirPath = localImagesDir.path;
    } else {
      final targetImagesDir = Directory(p.join(targetDir.path, 'images'));
      imagesDirPath = targetImagesDir.path;
    }

    // Open SQLite database in READ-ONLY mode
    final db = await openReadOnlyDatabase(targetDbFile.absolute.path);
    final packDb = CityPackDatabase(db, cityId);

    return LoadedCityPackContext(
      cityId: cityId,
      dbPath: targetDbFile.absolute.path,
      imagesDirPath: imagesDirPath,
      database: db,
      packDatabase: packDb,
    );
  }
}
