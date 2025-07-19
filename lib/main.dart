import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/run_provider.dart';
import 'providers/location_provider.dart';
import 'screens/home_screen.dart';
import 'screens/strava_webview_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Simple error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  };
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _stravaConnected = false;

  @override
  void initState() {
    super.initState();
    // Check if we have a Strava OAuth callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkStravaCallback();
    });
  }

  void _checkStravaCallback() {
    // Check if URL contains Strava OAuth callback parameters
    final uri = Uri.base;
    final code = uri.queryParameters['code'];
    final scope = uri.queryParameters['scope'];
    
    // Only treat as Strava callback if it has the specific Strava scope
    if (code != null && code.isNotEmpty && 
        scope != null && scope.contains('activity:read_all')) {
      // This is a Strava OAuth callback, not Supabase
      setState(() {
        _stravaConnected = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RunProvider()),
        ChangeNotifierProxyProvider<RunProvider, LocationProvider>(
          create: (_) => LocationProvider(null),
          update: (_, runProv, __) => LocationProvider(runProv),
        ),
      ],
      child: MaterialApp(
        title: 'StreakFreak',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          brightness: Brightness.dark,
        ),
        home: _stravaConnected ? HomeScreen() : StravaWebViewScreen(
          onImportComplete: _onStravaImportComplete,
        ),
      ),
    );
  }

  void _onStravaImportComplete() {
    setState(() {
      _stravaConnected = true;
    });
  }
}
