import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../domain/qa_issue.dart';
import '../domain/qa_session.dart';

class QaRepository {
  static Directory? _overrideSessionsDir;
  static final Map<String, QaSession> _webSessions = {};

  static void setOverrideDirectory(Directory dir) {
    _overrideSessionsDir = dir;
  }

  Future<Directory> _getSessionsDirectory() async {
    if (_overrideSessionsDir != null) {
      if (!_overrideSessionsDir!.existsSync()) {
        _overrideSessionsDir!.createSync(recursive: true);
      }
      return _overrideSessionsDir!;
    }

    Directory base;
    try {
      base = await getApplicationDocumentsDirectory();
    } catch (_) {
      base = Directory(p.join(Directory.systemTemp.path, 'yatracanvas_lab_docs'));
    }

    final dir = Directory(p.join(base.path, 'qa_sessions'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  File _getSessionFile(Directory dir, String cityId) {
    return File(p.join(dir.path, 'qa_$cityId.json'));
  }

  Future<QaSession> loadSession(String cityId, String packVersion) async {
    if (kIsWeb) {
      if (_webSessions.containsKey(cityId)) {
        return _webSessions[cityId]!;
      }
      final now = DateTime.now().toIso8601String();
      final fresh = QaSession(
        cityId: cityId,
        packVersion: packVersion,
        createdAt: now,
        lastModified: now,
      );
      _webSessions[cityId] = fresh;
      return fresh;
    }

    final dir = await _getSessionsDirectory();
    final file = _getSessionFile(dir, cityId);

    if (file.existsSync()) {
      try {
        final content = await file.readAsString();
        final map = json.decode(content) as Map<String, dynamic>;
        return QaSession.fromJson(map);
      } catch (_) {
        // Corrupt session file, create fresh
      }
    }

    final now = DateTime.now().toIso8601String();
    final fresh = QaSession(
      cityId: cityId,
      packVersion: packVersion,
      createdAt: now,
      lastModified: now,
    );
    await saveSession(fresh);
    return fresh;
  }

  Future<void> saveSession(QaSession session) async {
    if (kIsWeb) {
      session.lastModified = DateTime.now().toIso8601String();
      _webSessions[session.cityId] = session;
      return;
    }

    final dir = await _getSessionsDirectory();
    final file = _getSessionFile(dir, session.cityId);
    session.lastModified = DateTime.now().toIso8601String();
    await file.writeAsString(json.encode(session.toJson()), flush: true);
  }

  Future<void> addIssue(QaIssue issue) async {
    final session = await loadSession(issue.cityId, issue.packVersion);
    session.issues.removeWhere((i) => i.id == issue.id);
    session.issues.add(issue);
    await saveSession(session);
  }

  Future<void> deleteIssue(String cityId, String issueId) async {
    final session = await loadSession(cityId, 'v3');
    session.issues.removeWhere((i) => i.id == issueId);
    await saveSession(session);
  }

  Future<void> addRandomReview(String cityId, RandomReviewRecord record) async {
    final session = await loadSession(cityId, 'v3');
    session.randomReviews.add(record);
    await saveSession(session);
  }

  Future<void> addSearchResultReview(
    String cityId,
    SearchResultReviewRecord record,
  ) async {
    final session = await loadSession(cityId, 'v3');
    session.searchReviews.add(record);
    await saveSession(session);
  }

  Future<void> addExpectedPlaceCheck(
    String cityId,
    ExpectedPlaceCheckRecord record,
  ) async {
    final session = await loadSession(cityId, 'v3');
    session.expectedPlaceChecks.add(record);
    await saveSession(session);
  }

  Future<void> addScenarioResult(
    String cityId,
    ScenarioResultRecord record,
  ) async {
    final session = await loadSession(cityId, 'v3');
    session.scenarioResults.add(record);
    await saveSession(session);
  }

  Future<void> saveTripSelection(
    String cityId,
    Map<String, int> selections,
  ) async {
    final session = await loadSession(cityId, 'v3');
    session.tripSelections.clear();
    session.tripSelections.addAll(selections);
    await saveSession(session);
  }
}
