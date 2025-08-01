import 'package:flutter/material.dart';
import 'streak_screen.dart';
import 'map_screen.dart';
import 'insights_screen.dart';
import 'package:provider/provider.dart';
import '../providers/run_provider.dart';
import '../providers/location_provider.dart';
import 'strava_webview_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/strava_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isCheckingAuth = false;

  @override
  void initState() {
    super.initState();
    // Check authentication and data on app start
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkAuthenticationAndData();
    });
  }

  Future<void> _checkAuthenticationAndData() async {
    if (_isCheckingAuth) return;
    setState(() => _isCheckingAuth = true);

    try {
      print('[HomeScreen] Starting authentication check...');
      final runProvider = Provider.of<RunProvider>(context, listen: false);
      final stravaService = StravaService();
      
      // Check if there's a stored athlete ID
      final prefs = await SharedPreferences.getInstance();
      final storedAthleteId = prefs.getString('strava_athlete_id');
      print('[HomeScreen] Stored athlete ID: $storedAthleteId');
      
      if (storedAthleteId != null && storedAthleteId.isNotEmpty) {
        print('[HomeScreen] Found stored athlete ID, loading from database...');
        // We have a stored ID - load existing data from database
        await runProvider.loadRuns();
        print('[HomeScreen] Loaded ${runProvider.activities.length} activities from database');
        
        // Refresh location provider after runs are loaded
        final locationProvider = Provider.of<LocationProvider>(context, listen: false);
        await locationProvider.refresh();
        
        // Check if we have valid OAuth tokens to fetch new activities
        final accessToken = await stravaService.getValidAccessToken();
        print('[HomeScreen] Access token check: ${accessToken != null ? "Valid" : "Invalid/None"}');
        if (accessToken != null && !accessToken.startsWith('Error:')) {
          print('[HomeScreen] Valid OAuth found, syncing new activities...');
          // We have valid OAuth - check for new activities
          await _syncNewActivitiesFromStrava();
        } else {
          print('[HomeScreen] No valid OAuth, skipping Strava sync');
        }
      } else {
        print('[HomeScreen] No stored athlete ID found');
        // No stored ID - user needs to connect to Strava first
        // Don't auto-load anything, show the connect button
      }
    } catch (e) {
      print('[HomeScreen] Error during authentication check: $e');
      // Handle any errors silently
    } finally {
      if (mounted) {
        setState(() => _isCheckingAuth = false);
      }
    }
  }

  Future<void> _syncNewActivitiesFromStrava() async {
    try {
      print('[HomeScreen] Starting Strava sync...');
      final runProvider = Provider.of<RunProvider>(context, listen: false);
      await runProvider.importFromStrava();
      print('[HomeScreen] Strava sync completed, now have ${runProvider.activities.length} activities');
      
      // Refresh location provider after new activities are loaded
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      await locationProvider.refresh();
      print('[HomeScreen] Location provider refreshed');
    } catch (e) {
      print('[HomeScreen] Error during Strava sync: $e');
      // Handle sync errors silently
    }
  }

  Future<void> _connectToStrava() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StravaWebViewScreen(
          onImportComplete: _onImportComplete,
        ),
      ),
    );
    
    // After OAuth, check authentication and data again
    if (result == true) {
      await _checkAuthenticationAndData();
    }
  }

  void _onImportComplete() {
    // The RunProvider will have been updated by the StravaWebViewScreen
    // Refresh the UI
    setState(() {});
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
            // Sync button if we have activities and valid OAuth
            if (runProvider.activities.isNotEmpty && !_isCheckingAuth)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: _syncNewActivitiesFromStrava,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text(
                    'Sync New Activities from Strava',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            // Connect Strava button if no activities or checking auth
            if (runProvider.activities.isEmpty || _isCheckingAuth)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Welcome to StreakFreak!',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    if (_isCheckingAuth)
                      const Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Checking authentication and loading data...',
                            style: TextStyle(fontSize: 16, color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          const Text(
                            'Connect your Strava account to start tracking your running streaks.',
                            style: TextStyle(fontSize: 16, color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _connectToStrava,
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
                        ],
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