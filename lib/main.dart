import 'package:flutter/material.dart';

import 'app/app_state.dart';
import 'app/lab_theme.dart';
import 'screens/city_pack_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CityPackLabApp());
}

class CityPackLabApp extends StatefulWidget {
  const CityPackLabApp({super.key});

  @override
  State<CityPackLabApp> createState() => _CityPackLabAppState();
}

class _CityPackLabAppState extends State<CityPackLabApp> {
  late final AppState _state;

  @override
  void initState() {
    super.initState();
    _state = AppState();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YatraCanvas CityPack Lab',
      debugShowCheckedModeBanner: false,
      theme: LabTheme.light(),
      home: CityPackScreen(state: _state),
    );
  }
}
