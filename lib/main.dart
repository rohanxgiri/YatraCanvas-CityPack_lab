import 'package:flutter/material.dart';
import 'app/app_state.dart';
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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A8A), // Deep Indigo
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
          elevation: 1,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: CityPackScreen(state: _state),
    );
  }
}
