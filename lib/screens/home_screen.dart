import 'package:flutter/material.dart';
import 'streak_screen.dart';
import 'map_screen.dart';
import 'insights_screen.dart';
import 'package:provider/provider.dart';
import '../providers/run_provider.dart';
import '../providers/location_provider.dart';
import 'strava_webview_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    // Only auto-load if there's a valid stored athlete ID
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final runProvider = Provider.of<RunProvider>(context, listen: false);
      
      // Check if there's a stored athlete ID
      final prefs = await SharedPreferences.getInstance();
      final storedAthleteId = prefs.getString('strava_athlete_id');
      
      if (storedAthleteId != null && storedAthleteId.isNotEmpty) {
        // Auto-load for returning users with valid stored ID
        await runProvider.loadRuns();
        
        // Refresh location provider after runs are loaded
        final locationProvider = Provider.of<LocationProvider>(context, listen: false);
        await locationProvider.refresh();
      }
      // If no stored athlete ID, show clean interface for new users
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
      body: SingleChildScrollView(
        child: Column(
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
                child: Column(
                  children: [
                    const Text(
                      'Welcome to StreakFreak!',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Connect your Strava account to start tracking your running streaks.',
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                      child: const Text(
                        'Connect to Strava',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Debug button to clear stored athlete ID
                    ElevatedButton(
                      onPressed: () async {
                        await runProvider.clearStoredAthleteId();
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Stored athlete ID cleared. Refresh the page.')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text(
                        'Clear Stored ID (Debug)',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            // Tab content with fixed height to prevent overflow
            SizedBox(
              height: MediaQuery.of(context).size.height - 200, // Adjust height to fit screen
              child: _tabs[_selectedIndex],
            ),
          ],
        ),
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