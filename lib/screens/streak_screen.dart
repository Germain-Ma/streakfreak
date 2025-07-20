import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/run_provider.dart';
import 'package:intl/intl.dart';

class StreakScreen extends StatelessWidget {
  const StreakScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final runProvider = Provider.of<RunProvider>(context);
    final longestStreak = runProvider.longestStreak;
    final currentStreak = runProvider.currentStreak;
    final totalKm = runProvider.totalKm;
    final avgKmPerDay = runProvider.avgKmPerDay;
    
    // Get longest streak specific data
    final longestStreakFirstDay = runProvider.longestStreakFirstDay;
    final longestStreakLastDay = runProvider.longestStreakLastDay;
    final longestStreakRuns = runProvider.sortedQualifiedRuns;
    
    // Calculate longest streak total km and average
    double longestStreakTotalKm = 0.0;
    if (longestStreakFirstDay != null && longestStreakLastDay != null) {
      final streakRuns = longestStreakRuns.where((run) => 
        run.date.isAfter(longestStreakFirstDay.subtract(const Duration(days: 1))) &&
        run.date.isBefore(longestStreakLastDay.add(const Duration(days: 1)))
      ).toList();
      longestStreakTotalKm = streakRuns.fold(0.0, (sum, run) => sum + run.distanceKm);
    }
    final longestStreakAvgKm = longestStreak > 0 ? longestStreakTotalKm / longestStreak : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF181A20),
      // No AppBar here
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Only the banner, no extra title
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 0),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1A2980), Color(0xFFFF512F)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Longest Streak',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$longestStreak days',
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Current: $currentStreak days',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildStreakTable([
                    ['Days', longestStreak],
                    ['From', longestStreakFirstDay != null ? DateFormat.yMMMd().format(longestStreakFirstDay) : '-'],
                    ['To', longestStreakLastDay != null ? DateFormat.yMMMd().format(longestStreakLastDay) : '-'],
                    ['Total km', longestStreakTotalKm.toStringAsFixed(2)],
                    ['Avg km/day', longestStreakAvgKm.toStringAsFixed(2)],
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStreakTable(List<List<dynamic>> rows) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: const Color(0xFF23243B),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: Table(
          columnWidths: const {
            0: IntrinsicColumnWidth(),
            1: FlexColumnWidth(),
          },
          border: TableBorder.symmetric(inside: BorderSide(color: Colors.white10)),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            for (final row in rows)
              TableRow(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white10)),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(row[0].toString(), style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(row[1].toString(), style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white)),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
} 