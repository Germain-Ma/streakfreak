import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/run_provider.dart';
import 'package:intl/intl.dart';

class StreakScreen extends StatelessWidget {
  const StreakScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final runProvider = Provider.of<RunProvider>(context);
    final firstDay = runProvider.firstDay;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Current Streak: ${runProvider.streak} days', style: Theme.of(context).textTheme.headlineSmall),
          Text('Total km: ${runProvider.totalKm.toStringAsFixed(2)}'),
          Text('Avg km/day: ${runProvider.avgKmPerDay.toStringAsFixed(2)}'),
          Text('First day: ${firstDay != null ? DateFormat.yMMMd().format(firstDay) : "-"}'),
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