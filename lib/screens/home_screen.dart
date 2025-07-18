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
      ),
      body: Column(
        children: [
          // Minimal test widget for Supabase fetch
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Supabase activities loaded: \\${runProvider.activities.length}',
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