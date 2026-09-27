# YatraCanvas CityPack Lab Environment

## Environment Overview

- **Host OS**: Windows 11 / Windows Server 2025 (Build 26200.9457)
- **Architecture**: x64
- **Flutter Version**: 3.47.0 (Channel stable, revision `4cf2416426`)
- **Dart Version**: 3.13.0
- **DevTools**: 2.60.0
- **Android SDK**: Android SDK 36.0.0 (Platform android-37.0, build-tools 36.0.0, Java OpenJDK 25.0.2 JBR)
- **Desktop Support**: Windows Desktop enabled (using `sqflite_common_ffi` with `sqlite3_flutter_libs`), headless VM testing supported via Dart test framework.

## Flutter Doctor Summary

```
[√] Flutter (Channel stable, 3.47.0, on Microsoft Windows [Version 10.0.26200.9457], locale en-US)
    • Flutter version 3.47.0 on channel stable at C:\Users\girir\develop\flutter
    • Dart version 3.13.0
[√] Windows Version (Windows 11 or higher, 25H2, 2009)
[!] Android toolchain - develop for Android devices (Android SDK version 36.0.0)
    • Android SDK at C:\Users\girir\AppData\Local\Android\sdk
    • Platform android-37.0, build-tools 36.0.0
[√] Chrome - develop for the web
[X] Visual Studio - develop Windows apps (Desktop C++ workload not installed; headless & Android/testing workflows unaffected)
[√] Connected devices (Windows desktop, Chrome, Edge)
[√] Network resources available
```

## Primary Target & Architecture

- **Primary Target**: Android / Mobile first (matching YatraCanvas core design).
- **Secondary Target**: Windows / Dart VM test runner via `sqflite_common_ffi`.
- **Database Engine**: SQLite via `sqflite` / `sqflite_common_ffi` reading strictly immutable bundled packs copied into local app support storage.
- **Map Visualization**: `flutter_map` (v8.3.2) with online OSM tiles toggle and strict offline canvas mode.
- **External Network Access**: Zero remote POI / enricher requests; strict transparency diagnostics.
