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
