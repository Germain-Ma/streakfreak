import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/run_provider.dart';
import 'package:intl/intl.dart';

class StreakScreen extends StatelessWidget {
  const StreakScreen({super.key});

  @override
  Widget build(BuildContext context) {
    print('StreakScreen rebuilt');
    final runProvider = Provider.of<RunProvider>(context);
    final firstDay = runProvider.currentStreakFirstDay;
    final currentStreak = runProvider.currentStreak;
    final longestStreak = runProvider.longestStreak;
    final currentStreakTotalKm = runProvider.currentStreakTotalKm;
    final currentStreakAvgKm = runProvider.currentStreakAvgKm;
    final allTimeTotalKm = runProvider.allTimeTotalKm;
    final allTimeAvgKm = runProvider.allTimeAvgKm;
    final years = currentStreak ~/ 365;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Current Streak: $currentStreak days${years > 0 ? ' ($years years)' : ''}', style: Theme.of(context).textTheme.headlineSmall),
          Text('Current Streak Total km: ${currentStreakTotalKm.toStringAsFixed(2)}'),
          Text('Current Streak Avg km/day: ${currentStreakAvgKm.toStringAsFixed(2)}'),
          Text('First day of current streak: ${firstDay != null ? DateFormat.yMMMd().format(firstDay) : "-"}'),
          const SizedBox(height: 16),
          Text('All Time Total km: ${allTimeTotalKm.toStringAsFixed(2)}'),
          Text('All Time Avg km/activity: ${allTimeAvgKm.toStringAsFixed(2)}'),
          Text('Longest Streak: $longestStreak days'),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => runProvider.importCsv(),
            child: const Text('Import Garmin CSV'),
          ),
        ],
      ),
    );
  }
} 