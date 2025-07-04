import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/run_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RunProvider()..loadRuns()),
      ],
      child: MaterialApp(
        title: 'StreakFreak',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
        home: const HomeScreen(),
      ),
    );
  }
}
