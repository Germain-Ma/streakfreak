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
    // TODO: Check persistent storage for Strava connection status
    // For now, always show WebView until connected in this session
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
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        ),
        home: _stravaConnected
            ? const HomeScreen()
            : StravaWebViewScreen(onImportComplete: _onStravaImportComplete),
      ),
    );
  }
}
