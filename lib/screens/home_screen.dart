import 'package:flutter/material.dart';
import 'streak_screen.dart';
import 'map_screen.dart';
import 'insights_screen.dart';
import 'package:provider/provider.dart';
import '../providers/run_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

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
        actions: [
          Consumer<RunProvider>(
            builder: (context, runProvider, child) {
              if (runProvider.isImporting) {
                return Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF512F)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      runProvider.importTotal > 0 
                          ? '${runProvider.importProgress}/${runProvider.importTotal}'
                          : runProvider.importStatus,
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    const SizedBox(width: 8),
                  ],
                );
              } else {
                return IconButton(
                  icon: const Icon(Icons.sync, color: Color(0xFFFF512F)),
                  tooltip: 'Sync with Strava',
                  onPressed: () async {
                    // Show progress dialog for long imports
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext context) {
                        return Consumer<RunProvider>(
                          builder: (context, runProvider, child) {
                            return AlertDialog(
                              backgroundColor: const Color(0xFF23243B),
                              title: const Text('Syncing with Strava', style: TextStyle(color: Colors.white)),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (runProvider.importTotal > 0) ...[
                                    LinearProgressIndicator(
                                      value: runProvider.importProgress / runProvider.importTotal,
                                      backgroundColor: Colors.grey[800],
                                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF512F)),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      '${runProvider.importProgress}/${runProvider.importTotal} activities processed',
                                      style: const TextStyle(color: Colors.white70),
                                    ),
                                  ] else ...[
                                    const CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF512F)),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  Text(
                                    runProvider.importStatus,
                                    style: const TextStyle(color: Colors.white70),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );

                    await runProvider.smartSyncFromStrava();

                    // Close the progress dialog
                    if (mounted) {
                      Navigator.of(context).pop();
                    }

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Synced with Strava! Imported ${runProvider.activities.length} activities.'),
                        ),
                      );
                    }
                  },
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Minimal test widget for Supabase fetch
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Supabase activities loaded: ${runProvider.activities.length}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
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