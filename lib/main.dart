import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/run_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  print('DEBUG: main() started - CACHE BUST: ${DateTime.now().millisecondsSinceEpoch}');
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    print('[main.dart] Building MyApp with MultiProvider');
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          print('[main.dart] Creating RunProvider');
          return RunProvider();
        }),
      ],
      child: MaterialApp(
        title: 'StreakFreak',
        home: HomeScreen(),
      ),
    );
  }
}
