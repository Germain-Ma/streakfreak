import 'package:flutter/material.dart';
import 'streak_screen.dart';
import 'map_screen.dart';
import 'insights_screen.dart';
import 'package:provider/provider.dart';
import '../providers/run_provider.dart';
import 'strava_webview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Automatically load runs when the screen is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final runProvider = Provider.of<RunProvider>(context, listen: false);
      runProvider.loadRuns();
    });
  }

  static const List<Widget> _tabs = <Widget>[
    StreakScreen(),
    MapScreen(),
    InsightsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onImportComplete() {
    // The RunProvider will have been updated by the StravaWebViewScreen
    // No need to do anything else here
  }

  @override
  Widget build(BuildContext context) {
    final runProvider = Provider.of<RunProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('StreakFreak'),
      ),
      body: Column(
        children: [
          // Supabase activities count
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Supabase activities loaded: ${runProvider.activities.length}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
            ),
          ),
          // Connect Strava button if no activities
          if (runProvider.activities.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StravaWebViewScreen(
                        onImportComplete: _onImportComplete,
                      ),
                    ),
                  );
                },
                child: const Text('Connect Strava to Load Your Activities'),
              ),
            ),
          Expanded(child: _tabs[_selectedIndex]),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Streak'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.insights), label: 'Insights'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
} 