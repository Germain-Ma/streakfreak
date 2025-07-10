import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/run_provider.dart';
import 'providers/location_provider.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/strava_webview_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _stravaConnected = false;
  int _importedTotal = 0;
  int _importedGps = 0;

  @override
  void initState() {
    super.initState();
    _stravaConnected = false;
  }

  void _onStravaImportComplete(int total, int gps) {
    setState(() {
      _stravaConnected = true;
      _importedTotal = total;
      _importedGps = gps;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RunProvider()..loadRuns()),
        ChangeNotifierProxyProvider<RunProvider, LocationProvider>(
          create: (_) => LocationProvider(null),
          update: (_, runProv, prev) {
            if (prev == null) return LocationProvider(runProv);
            prev.updateRunProvider(runProv);
            return prev;
          },
        ),
      ],
      child: MaterialApp(
        title: 'StreakFreak',
        theme: ThemeData(
          brightness: Brightness.dark,
          fontFamily: 'Roboto',
          scaffoldBackgroundColor: const Color(0xFF181A20),
          colorScheme: ColorScheme.dark(
            primary: const Color(0xFF1A2980),
            secondary: const Color(0xFFFF512F),
            background: const Color(0xFF181A20),
            surface: const Color(0xFF23243B),
          ),
          cardColor: const Color(0xFF23243B),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF181A20),
            elevation: 0,
            titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          textTheme: const TextTheme(
            headlineSmall: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            titleMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white70),
            bodyMedium: TextStyle(fontSize: 16, color: Colors.white70),
            bodyLarge: TextStyle(fontSize: 18, color: Colors.white),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF512F),
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        home: _stravaConnected
            ? const HomeScreen()
            : StravaWebViewScreen(onImportComplete: _onStravaImportComplete),
      ),
    );
  }
}
