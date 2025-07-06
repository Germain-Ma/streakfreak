import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/run_provider.dart';
import 'package:intl/intl.dart';
import '../providers/location_provider.dart';

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
    final years = currentStreak / 365;
    final currentStreakFirstDay = runProvider.currentStreakFirstDay;
    final currentStreakLastDay = runProvider.currentStreakLastDay;
    final longestStreakFirstDay = runProvider.longestStreakFirstDay;
    final longestStreakLastDay = runProvider.longestStreakLastDay;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Current Streak: $currentStreak days${currentStreak > 0 ? ' (' + years.toStringAsFixed(1) + ' years)' : ''}',
            style: Theme.of(context).textTheme.headlineSmall),
          Text('Current streak period: '
            + (currentStreakFirstDay != null && currentStreakLastDay != null
                ? '${DateFormat.yMMMd().format(currentStreakFirstDay)} - ${DateFormat.yMMMd().format(currentStreakLastDay)}'
                : '-')),
          Text('Current Streak Total km: ${currentStreakTotalKm.toStringAsFixed(2)}'),
          Text('Current Streak Avg km/day: ${currentStreakAvgKm.toStringAsFixed(2)}'),
          const SizedBox(height: 16),
          Text('All Time Total km: ${allTimeTotalKm.toStringAsFixed(2)}'),
          Text('All Time Avg km/activity: ${allTimeAvgKm.toStringAsFixed(2)}'),
          Text('Longest Streak: $longestStreak days'
            + (longestStreakFirstDay != null && longestStreakLastDay != null
                ? ' (${DateFormat.yMMMd().format(longestStreakFirstDay)} - ${DateFormat.yMMMd().format(longestStreakLastDay)})'
                : '')),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              await runProvider.importCsv();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.read<LocationProvider>().refresh();
              });
            },
            child: const Text('Import Garmin CSV'),
          ),
        ],
      ),
    );
  }
} 