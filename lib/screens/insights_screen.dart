import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/run_provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  String _formatDuration(int seconds) {
    final d = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return h > 0 ? '${twoDigits(h)}:${twoDigits(m)}:${twoDigits(s)}' : '${twoDigits(m)}:${twoDigits(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final runProvider = Provider.of<RunProvider>(context);
    final runs = runProvider.runs;
    if (runs.isEmpty) {
      return const Center(child: Text('No run data available.'));
    }

    // All-time totals
    final totalRuns = runs.length;
    final totalKm = runs.fold(0.0, (sum, r) => sum + r.distanceKm);
    final totalElevation = runs.fold(0.0, (sum, r) => sum + r.elevationGain);
    final totalCalories = runs.fold(0, (sum, r) => sum + r.calories);
    final totalMovingTime = runs.fold(0, (sum, r) => sum + r.movingTime);
    final totalElapsedTime = runs.fold(0, (sum, r) => sum + r.elapsedTime);
    final avgKm = totalRuns > 0 ? totalKm / totalRuns : 0.0;
    final avgElevation = totalRuns > 0 ? totalElevation / totalRuns : 0.0;
    final avgCalories = totalRuns > 0 ? totalCalories / totalRuns : 0.0;
    final avgMovingTime = totalRuns > 0 ? totalMovingTime ~/ totalRuns : 0;
    final avgElapsedTime = totalRuns > 0 ? totalElapsedTime ~/ totalRuns : 0;
    final avgSpeed = runs.where((r) => r.avgSpeed > 0).fold(0.0, (sum, r) => sum + r.avgSpeed) / (runs.where((r) => r.avgSpeed > 0).length == 0 ? 1 : runs.where((r) => r.avgSpeed > 0).length);

    // Yearly/monthly breakdowns
    final byYear = <int, List<dynamic>>{}; // [distance, runs, elevation, time]
    final byMonth = <String, List<dynamic>>{}; // [distance, runs, elevation, time]
    for (final r in runs) {
      byYear[r.date.year] ??= [0.0, 0, 0.0, 0];
      byYear[r.date.year]![0] += r.distanceKm;
      byYear[r.date.year]![1] += 1;
      byYear[r.date.year]![2] += r.elevationGain;
      byYear[r.date.year]![3] += r.movingTime;
      final ym = '${r.date.year}-${r.date.month.toString().padLeft(2, '0')}';
      byMonth[ym] ??= [0.0, 0, 0.0, 0];
      byMonth[ym]![0] += r.distanceKm;
      byMonth[ym]![1] += 1;
      byMonth[ym]![2] += r.elevationGain;
      byMonth[ym]![3] += r.movingTime;
    }
    final sortedYears = byYear.keys.toList()..sort();
    final sortedMonths = byMonth.keys.toList()..sort();

    // Personal records
    final longestRun = runs.reduce((a, b) => a.distanceKm > b.distanceKm ? a : b);
    final highestElevation = runs.reduce((a, b) => a.elevationGain > b.elevationGain ? a : b);
    final fastestRun = runs.where((r) => r.avgSpeed > 0).isNotEmpty ? runs.where((r) => r.avgSpeed > 0).reduce((a, b) => a.avgSpeed > b.avgSpeed ? a : b) : null;
    final maxCalories = runs.reduce((a, b) => a.calories > b.calories ? a : b);

    // Streaks
    final currentStreak = runProvider.currentStreak;
    final longestStreak = runProvider.longestStreak;
    final currentStreakFirstDay = runProvider.currentStreakFirstDay;
    final currentStreakLastDay = runProvider.currentStreakLastDay;
    final longestStreakFirstDay = runProvider.longestStreakFirstDay;
    final longestStreakLastDay = runProvider.longestStreakLastDay;

    // Weekly distance (last 52 weeks)
    final now = DateTime.now();
    final weekStats = List.generate(52, (i) {
      final weekStart = now.subtract(Duration(days: (51 - i) * 7));
      final weekEnd = weekStart.add(const Duration(days: 6));
      final weekKm = runs.where((r) => r.date.isAfter(weekStart.subtract(const Duration(days: 1))) && r.date.isBefore(weekEnd.add(const Duration(days: 1)))).fold(0.0, (sum, r) => sum + r.distanceKm);
      return {'label': '${weekStart.year}-${weekStart.weekday}', 'km': weekKm};
    });

    // Country statistics (dummy for now)
    final countryStats = <String, int>{};
    for (final r in runs) {
      final country = r.country ?? 'Unknown';
      countryStats[country] = (countryStats[country] ?? 0) + 1;
    }
    final sortedCountries = countryStats.keys.toList()..sort((a, b) => countryStats[b]!.compareTo(countryStats[a]!));

    return Scaffold(
      backgroundColor: const Color(0xFF181A20),
      body: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Overall personal best (centered, no table)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Text('Your overall personal best', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 16),
                    Text(
                      'Total activities $totalRuns with total of ${totalKm.toStringAsFixed(1)}km',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    if (sortedYears.isNotEmpty)
                      Text(
                        '${sortedYears.last} was the best year with ${byYear[sortedYears.last]![0].toStringAsFixed(0)}km',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    if (sortedMonths.isNotEmpty)
                      Text(
                        '${DateFormat.yMMM().format(DateTime.parse(sortedMonths.last + "-01"))} was the best month with ${byMonth[sortedMonths.last]![0].toStringAsFixed(0)}km',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _recordLink(longestRun.title, longestRun.stravaId),
                        Text(" was your longest Run with ${longestRun.distanceKm.toStringAsFixed(0)}km", style: const TextStyle(color: Colors.white, fontSize: 16)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _recordLink(highestElevation.title, highestElevation.stravaId),
                        Text(" was the Run with the most elevation gain of ${highestElevation.elevationGain.toStringAsFixed(1)} m", style: const TextStyle(color: Colors.white, fontSize: 16)),
                      ],
                    ),
                    if (fastestRun != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _recordLink(fastestRun.title, fastestRun.stravaId),
                          Text(" was your best Run with a average of ${(fastestRun.avgSpeed * 3.6).toStringAsFixed(2)} km/h (${_formatDuration((1000 / fastestRun.avgSpeed).round())} /km)", style: const TextStyle(color: Colors.white, fontSize: 16)),
                        ],
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _recordLink(longestRun.title, longestRun.stravaId),
                        Text(" was your max tiles Run with 33 tiles", style: const TextStyle(color: Colors.white, fontSize: 16)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // 2. Distance per year chart
              _buildLineChart(
                sortedYears,
                byYear,
                0,
                'Distance per Year',
                Colors.blue,
                (v) => '${v.toStringAsFixed(0)} km',
              ),
              const SizedBox(height: 32),
              // 3. Distance per week (last 52 weeks) chart
              _buildBarChart(
                weekStats,
                'Distance per week over last 52 weeks',
                Colors.lightBlueAccent,
                (v) => '${v.toStringAsFixed(0)} km',
              ),
              const SizedBox(height: 32),
              // 4. General statistics
              _buildStatsTable('General statistics', [
                ['Activities', totalRuns],
                ['Total distance', '${totalKm.toStringAsFixed(1)} km'],
                ['Avg distance per activity', '${avgKm.toStringAsFixed(2)} km'],
                ['Max distance in', longestRun.title, '${longestRun.distanceKm.toStringAsFixed(2)} km'],
                ['Avg speed', '${(avgSpeed * 3.6).toStringAsFixed(2)} km/h'],
                if (fastestRun != null)
                  ['Max avg speed in', fastestRun.title, '${(fastestRun.avgSpeed * 3.6).toStringAsFixed(2)} km/h'],
                ['Trips around the world', (totalKm / 40075).toStringAsFixed(3)],
                ['Trips to the moon', (totalKm / 384400).toStringAsFixed(3)],
              ]),
              const SizedBox(height: 32),
              // 5. To date statistics
              _buildStatsTable('To date statistics', [
                ['This year', '${byYear[DateTime.now().year]?[0]?.toStringAsFixed(1) ?? '0'} km'],
                ['This year week average', '${(byYear[DateTime.now().year] != null ? (byYear[DateTime.now().year]![0] / 52).toStringAsFixed(1) : '0')} km'],
                ['Rolling year', '${byYear[DateTime.now().year]?[0]?.toStringAsFixed(1) ?? '0'} km'],
                ['Rolling year week average', '${(byYear[DateTime.now().year] != null ? (byYear[DateTime.now().year]![0] / 52).toStringAsFixed(1) : '0')} km'],
                ['This month', '${byMonth[DateFormat('yyyy-MM').format(DateTime.now())]?[0]?.toStringAsFixed(1) ?? '0'} km'],
                ['Rolling month', '${byMonth[DateFormat('yyyy-MM').format(DateTime.now())]?[0]?.toStringAsFixed(1) ?? '0'} km'],
                ['This week', '${(weekStats.last['km'] as num).toStringAsFixed(1)} km'],
                ['Rolling week', '${(weekStats.last['km'] as num).toStringAsFixed(1)} km'],
              ]),
              const SizedBox(height: 32),
              // 6. Time statistics
              _buildStatsTable('Time statistics', [
                ['Total moving time', _formatDuration(totalMovingTime)],
                ['Avg moving time', _formatDuration(avgMovingTime)],
                ['Max moving time in', highestElevation.title, _formatDuration(highestElevation.movingTime)],
                ['Total elapsed time', _formatDuration(totalElapsedTime)],
                ['Avg elapsed time', _formatDuration(avgElapsedTime)],
                ['Max elapsed time in', highestElevation.title, _formatDuration(highestElevation.elapsedTime)],
                ['Efficiency', '${(totalMovingTime / (totalElapsedTime == 0 ? 1 : totalElapsedTime) * 100).toStringAsFixed(1)}%'],
                ['Max streak', '${longestStreakFirstDay != null && longestStreakLastDay != null ? '${DateFormat.yMd().format(longestStreakFirstDay)} to ${DateFormat.yMd().format(longestStreakLastDay)}' : '-'}', '$longestStreak days'],
                ['Current streak', '${currentStreakFirstDay != null && currentStreakLastDay != null ? '${DateFormat.yMd().format(currentStreakFirstDay)} to ${DateFormat.yMd().format(currentStreakLastDay)}' : '-'}', '$currentStreak days'],
              ]),
              const SizedBox(height: 32),
              // 7. Elevation statistics
              _buildStatsTable('Elevation statistics', [
                ['Total elevation gain', '${totalElevation.toStringAsFixed(0)} m'],
                ['Avg elevation gain', '${avgElevation.toStringAsFixed(0)} m'],
                ['Max elevation in', highestElevation.title, '${highestElevation.elevationGain.toStringAsFixed(0)} m'],
                ['Mount Everest climbs', (totalElevation / 8848).toStringAsFixed(1)],
                ['Climb rate', '${(totalElevation / (totalKm == 0 ? 1 : totalKm)).toStringAsFixed(1)} m/km'],
              ]),
              const SizedBox(height: 32),
              // 8. Heart rate statistics
              _buildStatsTable('Heart rate statistics', [
                ['Activities with heart rate data', runs.where((r) => (r.avgHeartRate ?? 0) > 0).length],
                ['Avg heart rate',
                  runs.where((r) => (r.avgHeartRate ?? 0) > 0).isNotEmpty
                    ? (runs.where((r) => (r.avgHeartRate ?? 0) > 0).fold(0.0, (sum, r) => sum + (r.avgHeartRate ?? 0)) / runs.where((r) => (r.avgHeartRate ?? 0) > 0).length).toStringAsFixed(1)
                    : '-'],
                ['Max avg heart rate',
                  runs.where((r) => (r.avgHeartRate ?? 0) > 0).isNotEmpty
                    ? runs.where((r) => (r.avgHeartRate ?? 0) > 0).map((r) => r.avgHeartRate ?? 0).reduce((a, b) => a > b ? a : b).toStringAsFixed(1)
                    : '-'],
                ['Max heart rate',
                  runs.where((r) => (r.maxHeartRate ?? 0) > 0).isNotEmpty
                    ? runs.where((r) => (r.maxHeartRate ?? 0) > 0).map((r) => r.maxHeartRate ?? 0).reduce((a, b) => a > b ? a : b).toStringAsFixed(1)
                    : '-'],
                ['Avg max heart rate',
                  runs.where((r) => (r.maxHeartRate ?? 0) > 0).isNotEmpty
                    ? (runs.where((r) => (r.maxHeartRate ?? 0) > 0).fold(0.0, (sum, r) => sum + (r.maxHeartRate ?? 0)) / runs.where((r) => (r.maxHeartRate ?? 0) > 0).length).toStringAsFixed(1)
                    : '-'],
              ]),
              const SizedBox(height: 32),
              // 9. Distance breakdown statistics
              _buildStatsTable('Distance breakdown statistics', [
                ['Group', 'Activities', 'Distance', 'Elevation', 'Average', 'Pace', 'Moving time', 'Elapsed time'],
                ['0 - 20 km', runs.where((r) => r.distanceKm < 20).length, '${runs.where((r) => r.distanceKm < 20).fold(0.0, (sum, r) => sum + r.distanceKm).toStringAsFixed(0)} km', '${runs.where((r) => r.distanceKm < 20).fold(0.0, (sum, r) => sum + r.elevationGain).toStringAsFixed(0)} m', '${runs.where((r) => r.distanceKm < 20).isNotEmpty ? (runs.where((r) => r.distanceKm < 20).fold(0.0, (sum, r) => sum + r.avgSpeed) / runs.where((r) => r.distanceKm < 20).length * 3.6).toStringAsFixed(2) : '-'} km/h', '-', '-', '-'],
                ['20 - 40 km', runs.where((r) => r.distanceKm >= 20 && r.distanceKm < 40).length, '${runs.where((r) => r.distanceKm >= 20 && r.distanceKm < 40).fold(0.0, (sum, r) => sum + r.distanceKm).toStringAsFixed(0)} km', '${runs.where((r) => r.distanceKm >= 20 && r.distanceKm < 40).fold(0.0, (sum, r) => sum + r.elevationGain).toStringAsFixed(0)} m', '${runs.where((r) => r.distanceKm >= 20 && r.distanceKm < 40).isNotEmpty ? (runs.where((r) => r.distanceKm >= 20 && r.distanceKm < 40).fold(0.0, (sum, r) => sum + r.avgSpeed) / runs.where((r) => r.distanceKm >= 20 && r.distanceKm < 40).length * 3.6).toStringAsFixed(2) : '-'} km/h', '-', '-', '-'],
                ['40 - 60 km', runs.where((r) => r.distanceKm >= 40 && r.distanceKm < 60).length, '${runs.where((r) => r.distanceKm >= 40 && r.distanceKm < 60).fold(0.0, (sum, r) => sum + r.distanceKm).toStringAsFixed(0)} km', '${runs.where((r) => r.distanceKm >= 40 && r.distanceKm < 60).fold(0.0, (sum, r) => sum + r.elevationGain).toStringAsFixed(0)} m', '${runs.where((r) => r.distanceKm >= 40 && r.distanceKm < 60).isNotEmpty ? (runs.where((r) => r.distanceKm >= 40 && r.distanceKm < 60).fold(0.0, (sum, r) => sum + r.avgSpeed) / runs.where((r) => r.distanceKm >= 40 && r.distanceKm < 60).length * 3.6).toStringAsFixed(2) : '-'} km/h', '-', '-', '-'],
              ]),
              const SizedBox(height: 32),
              // 10. Country statistics
              _buildStatsTable('Country statistics', [
                ['Country', 'Activities'],
                ...(
                  countryStats.entries
                    .where((e) => (e.key != null && e.key.trim().isNotEmpty))
                    .toList()
                    ..sort((a, b) => b.value.compareTo(a.value))
                ).map((e) => [e.key, e.value]),
              ]),
              const SizedBox(height: 64),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLineChart(List<int> years, Map<int, List<dynamic>> byYear, int valueIndex, String title, Color color, String Function(double) valueLabel) {
    final spots = [
      for (final y in years) FlSpot(y.toDouble(), (byYear[y]?[valueIndex] as num?)?.toDouble() ?? 0.0),
    ];
    final lastSpot = spots.isNotEmpty ? spots.last : null;
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF23243B),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: null, getDrawingHorizontalLine: (value) => FlLine(color: Colors.white12, strokeWidth: 1)),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                        getTitlesWidget: (value, meta) {
                          if (lastSpot != null && value == lastSpot.y) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(valueLabel(value), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final year = value.toInt();
                          if (years.contains(year)) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(year.toString(), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: color,
                      barWidth: 4,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(List<Map<String, dynamic>> weekStats, String title, Color color, String Function(double) valueLabel) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF23243B),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  barGroups: [
                    for (int i = 0; i < weekStats.length; i++)
                      BarChartGroupData(x: i, barRods: [BarChartRodData(toY: weekStats[i]['km'], color: color, width: 6)])
                  ],
                  gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: null, getDrawingHorizontalLine: (value) => FlLine(color: Colors.white12, strokeWidth: 1)),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                        getTitlesWidget: (value, meta) {
                          if (value == weekStats.map((e) => e['km'] as double).reduce(max)) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(valueLabel(value), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 13, // Show every quarter
                        getTitlesWidget: (value, meta) {
                          if (value % 13 == 0 && value < weekStats.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text('W${value.toInt() + 1}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsTable(String title, List<List<dynamic>> rows) {
    // Ensure all rows have the same length as the header
    final int colCount = rows.isNotEmpty ? rows.first.length : 1;
    final paddedRows = rows.map((row) {
      if (row.length < colCount) {
        return [...row, ...List.filled(colCount - row.length, '')];
      } else if (row.length > colCount) {
        return row.sublist(0, colCount);
      }
      return row;
    }).toList();
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 900),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF23243B),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
            ),
            Table(
              columnWidths: const {},
              border: TableBorder(horizontalInside: BorderSide(color: Colors.white10)),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                for (final row in paddedRows)
                  TableRow(
                    children: [
                      for (final cell in row)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: cell is Widget ? cell : Text(cell.toString(), style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white)),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _recordLink(String title, String stravaId) {
    if (stravaId.isEmpty) return Text(title, style: const TextStyle(color: Colors.white));
    final url = 'https://www.strava.com/activities/$stravaId';
    return InkWell(
      onTap: () => launchUrl(Uri.parse(url)),
      child: Text(title, style: const TextStyle(color: Colors.blueAccent, decoration: TextDecoration.underline, fontSize: 16)),
    );
  }
} 