import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/navigation_provider.dart';
import 'screens/map_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Show error details in release mode (instead of gray box)
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      child: Container(
        color: Colors.black,
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Text(
            'ERROR:\n${details.exception}\n\nSTACK:\n${details.stack}',
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ),
      ),
    );
  };
  runApp(const BoatNaviApp());
}

class BoatNaviApp extends StatelessWidget {
  const BoatNaviApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NavigationProvider()..init(),
      child: MaterialApp(
        title: 'Boat Navi',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.dark(
            primary: const Color(0xFF00E5FF),
            secondary: const Color(0xFF00E5FF),
            surface: const Color(0xFF0D1F3C),
            onPrimary: const Color(0xFF0A1628),
            onSecondary: const Color(0xFF0A1628),
            onSurface: Colors.white,
          ),
          scaffoldBackgroundColor: const Color(0xFF0A1628),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0D1F3C),
            foregroundColor: Color(0xFF00E5FF),
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            color: const Color(0xFF0D1F3C),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF00E5FF), width: 0.5),
            ),
          ),
          useMaterial3: true,
        ),
        initialRoute: '/',
        routes: {
          '/': (_) => const MapScreen(),
          '/settings': (_) => const SettingsScreen(),
        },
      ),
    );
  }
}
