import 'package:flutter/material.dart';
import '../models/run.dart';
import '../models/activity.dart';
import '../services/csv_service.dart';
import '../services/storage_service.dart';
import 'package:intl/intl.dart';
import '../services/strava_service.dart';

class RunProvider extends ChangeNotifier {
  final CsvService _csvService = CsvService();
  final StorageService _storageService = StorageService();
  final StravaService _stravaService = StravaService();
  StravaService get stravaService => _stravaService;
  List<Activity> _activities = [];
  static int runsGetterCallCount = 0;

  List<Activity> get activities => _activities;

  List<Run> get runs {
    runsGetterCallCount++;
    if (runsGetterCallCount == 1) {
      print('Total activities: ' + _activities.length.toString());
      final validRuns = _activities.map((a) {
        try {
          final type = (a.fields['Activity Type'] ?? '').toLowerCase();
          if (!type.contains('run')) return null;
          return Run.fromCsv(a.fields);
        } catch (e) {
          print('Skipped activity: $a, error: $e');
          return null;
        }
      }).whereType<Run>().toList();
      print('Parsed runs: ' + validRuns.length.toString());
      return validRuns;
    } else if (runsGetterCallCount == 2) {
      print('runs getter called 2 times');
    } else if (runsGetterCallCount % 10 == 0) {
      print('runs getter called $runsGetterCallCount times');
    }
    final validRuns = _activities.map((a) {
      try {
        final type = (a.fields['Activity Type'] ?? '').toLowerCase();
        if (!type.contains('run')) return null;
        return Run.fromCsv(a.fields);
      } catch (e) {
        return null;
      }
    }).whereType<Run>().toList();
    return validRuns;
  }

  // Computed stats
  int get streak {
    final r = runs;
    if (r.isEmpty) return 0;
    r.sort((a, b) => b.date.compareTo(a.date));
    int streak = 1;
    for (int i = 1; i < r.length; i++) {
      final diff = r[i - 1].date.difference(r[i].date).inDays;
      if (diff == 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  double get totalKm => runs.fold(0.0, (sum, r) => sum + r.distanceKm);

  double get avgKmPerDay {
    final r = runs;
    if (r.isEmpty) return 0.0;
    final days = r.last.date.difference(r.first.date).inDays + 1;
    return days > 0 ? totalKm / days : totalKm;
  }

  DateTime? get firstDay {
    final r = runs;
    return r.isEmpty ? null : r.map((r) => r.date).reduce((a, b) => a.isBefore(b) ? a : b);
  }

  /// Import activities from Strava API
  Future<void> importFromStrava() async {
    final stravaActivities = await _stravaService.fetchActivities();
    // Debug: print all activity types found
    final types = stravaActivities.map((a) => a['type']).toSet();
    print('Strava activity types found: ' + types.join(', '));
    // Only import activities of type 'Run' or 'Trail Run'
    final filteredActivities = stravaActivities.where((a) {
      final type = (a['type'] ?? '').toString().toLowerCase();
      return type == 'run' || type == 'trailrun';
    }).toList();
    // Convert Strava activities to Activity and Run objects
    _activities = filteredActivities.map((a) {
      // Map Strava fields to Activity fields
      // Convert distance from meters to kilometers
      final distanceMeters = (a['distance'] ?? 0).toString();
      final distanceKm = double.tryParse(distanceMeters) != null ? (double.parse(distanceMeters) / 1000).toString() : '0.0';
      // Use start_date_local if available, otherwise fallback to start_date
      final dateLocal = (a['start_date_local'] ?? a['start_date'] ?? '').toString();
      final fields = <String, String>{
        'Activity Type': (a['type'] ?? '').toString(),
        'Date': dateLocal,
        'Distance': distanceKm,
        'Title': (a['name'] ?? '').toString(),
        'Start Latitude': (a['start_latlng'] is List && a['start_latlng'].isNotEmpty) ? a['start_latlng'][0].toString() : '',
        'Start Longitude': (a['start_latlng'] is List && a['start_latlng'].length > 1) ? a['start_latlng'][1].toString() : '',
        'Strava ID': (a['id'] ?? '').toString(),
      };
      return Activity(fields);
    }).toList();
    await _storageService.saveActivities(_activities);
    // Debug: print all runs for June 17, 2025
    final runsOnJune17 = _activities.map((a) => Run.fromCsv(a.fields)).where((r) =>
      r.date.year == 2025 && r.date.month == 6 && r.date.day == 17).toList();
    print('Runs on 2025-06-17: count=${runsOnJune17.length}');
    for (final r in runsOnJune17) {
      print('  - ${r.date} | ${r.distanceKm} km | lat: ${r.lat}, lon: ${r.lon} | title: ${r.title}');
    }
    // Print all run dates and distances for the last 30 days
    final allRuns = _activities.map((a) => Run.fromCsv(a.fields)).toList();
    allRuns.sort((a, b) => b.date.compareTo(a.date));
    print('All runs in last 30 days:');
    final cutoff = DateTime.now().subtract(Duration(days: 30));
    for (final r in allRuns.where((r) => r.date.isAfter(cutoff))) {
      print('  - ${r.date} | ${r.distanceKm} km');
    }
    // Print dates included in the current streak
    final streakDates = currentStreakRuns.map((r) => r.date).toList();
    print('Current streak dates:');
    for (final d in streakDates) {
      print('  - $d');
    }
    notifyListeners();
  }

  Future<void> loadRuns() async {
    _activities = await _storageService.loadActivities();
    notifyListeners();
  }

  Future<void> clearRuns() async {
    _activities = [];
    await _storageService.clearActivities();
    notifyListeners();
  }

  // Helper: Get runs with at least 1.61 km per day (for streak logic)
  List<Run> get _qualifiedRuns {
    // Group by date, sum distances per day, and only include days with >= 1.61 km
    final byDate = <DateTime, double>{};
    for (final run in runs) {
      final day = DateTime(run.date.year, run.date.month, run.date.day);
      byDate[day] = (byDate[day] ?? 0) + run.distanceKm;
    }
    return byDate.entries
      .where((e) => e.value >= 1.61)
      .map<Run>((e) => Run(date: e.key, distanceKm: e.value, lat: 0, lon: 0, title: ''))
      .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  // --- New Streak and Stats Logic ---
  // Helper: Get sorted qualified runs (descending by date)
  List<Run> get _sortedQualifiedRuns => _qualifiedRuns;

  // Current streak (consecutive days up to most recent)
  int get currentStreak {
    final r = _sortedQualifiedRuns;
    if (r.isEmpty) return 0;
    int streak = 1;
    for (int i = 1; i < r.length; i++) {
      final diff = r[i - 1].date.difference(r[i].date).inDays;
      if (diff == 1) {
        streak++;
      } else if (diff > 1) {
        break;
      }
    }
    return streak;
  }

  // Longest streak (anywhere in the data)
  int get longestStreak {
    final r = _sortedQualifiedRuns;
    if (r.isEmpty) return 0;
    int maxStreak = 1;
    int streak = 1;
    for (int i = 1; i < r.length; i++) {
      final diff = r[i - 1].date.difference(r[i].date).inDays;
      if (diff == 1) {
        streak++;
        if (streak > maxStreak) maxStreak = streak;
      } else if (diff > 1) {
        streak = 1;
      }
    }
    return maxStreak;
  }

  // Current streak stats
  List<Run> get currentStreakRuns {
    final r = _sortedQualifiedRuns;
    if (r.isEmpty) return [];
    List<Run> streakRuns = [r.first];
    for (int i = 1; i < r.length; i++) {
      final diff = r[i - 1].date.difference(r[i].date).inDays;
      if (diff == 1) {
        streakRuns.add(r[i]);
      } else if (diff > 1) {
        break;
      }
    }
    return streakRuns;
  }

  double get currentStreakTotalKm => currentStreakRuns.fold(0.0, (sum, r) => sum + r.distanceKm);
  double get currentStreakAvgKm => currentStreakRuns.isEmpty ? 0.0 : currentStreakTotalKm / currentStreakRuns.length;
  DateTime? get currentStreakFirstDay => currentStreakRuns.isEmpty ? null : currentStreakRuns.last.date;
  DateTime? get currentStreakLastDay => currentStreakRuns.isEmpty ? null : currentStreakRuns.first.date;

  // All-time stats (still use all runs)
  double get allTimeTotalKm => runs.fold(0.0, (sum, r) => sum + r.distanceKm);
  double get allTimeAvgKm => runs.isEmpty ? 0.0 : allTimeTotalKm / runs.length;

  DateTime? get longestStreakFirstDay {
    final runs = _sortedQualifiedRuns;
    if (runs.isEmpty) return null;
    int maxStreak = 1, streak = 1, maxStart = 0, maxEnd = 0, start = 0;
    for (int i = 1; i < runs.length; i++) {
      final diff = runs[i - 1].date.difference(runs[i].date).inDays;
      if (diff == 1) {
        streak++;
      } else {
        if (streak > maxStreak) {
          maxStreak = streak;
          maxStart = start;
          maxEnd = i - 1;
        }
        streak = 1;
        start = i;
      }
    }
    if (streak > maxStreak) {
      maxStreak = streak;
      maxStart = start;
      maxEnd = runs.length - 1;
    }
    return runs[maxEnd].date;
  }

  DateTime? get longestStreakLastDay {
    final runs = _sortedQualifiedRuns;
    if (runs.isEmpty) return null;
    int maxStreak = 1, streak = 1, maxStart = 0, maxEnd = 0, start = 0;
    for (int i = 1; i < runs.length; i++) {
      final diff = runs[i - 1].date.difference(runs[i].date).inDays;
      if (diff == 1) {
        streak++;
      } else {
        if (streak > maxStreak) {
          maxStreak = streak;
          maxStart = start;
          maxEnd = i - 1;
        }
        streak = 1;
        start = i;
      }
    }
    if (streak > maxStreak) {
      maxStreak = streak;
      maxStart = start;
      maxEnd = runs.length - 1;
    }
    return runs[maxStart].date;
  }
} 