import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/run_provider.dart';
import 'providers/location_provider.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/strava_webview_screen.dart';

void main() async {
  print('[main.dart] TOP OF FILE');
  print('[main.dart] App started at:  [32m${Uri.base.toString()} [0m');
  print('[main.dart] Uri.base: ${Uri.base}');
  print('[main.dart] Query params: ${Uri.base.queryParameters}');
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    print('[GLOBAL ERROR]  [31m${details.exceptionAsString()} [0m');
    if (details.stack != null) {
      print('[GLOBAL ERROR STACK] ${details.stack}');
    }
  };
  print('[main.dart] Before runApp');
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
    print('[_MyAppState] build called');
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          print('[main.dart] Creating RunProvider');
          return RunProvider()..loadRuns();
        }),
        ChangeNotifierProxyProvider<RunProvider, LocationProvider>(
          create: (_) {
            print('[main.dart] Creating LocationProvider(null)');
            return LocationProvider(null);
          },
          update: (_, runProv, prev) {
            print('[main.dart] Updating LocationProvider with runProv: $runProv');
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
        home: Stack(
          children: [
            _stravaConnected
                ? HomeScreen()
                : StravaWebViewScreen(onImportComplete: _onStravaImportComplete),
            Consumer<RunProvider>(
              builder: (context, runProvider, child) {
                if (!runProvider.isSyncingCloud) return SizedBox.shrink();
                return Positioned(
                  right: 24,
                  bottom: 24,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(Icons.sync, color: Colors.orange, size: 32),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
