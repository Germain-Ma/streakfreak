import 'package:flutter/material.dart';
import '../models/run.dart';
import '../models/activity.dart';
import '../services/csv_service.dart';
import '../services/storage_service.dart';
import 'package:intl/intl.dart';

class RunProvider extends ChangeNotifier {
  final CsvService _csvService = CsvService();
  final StorageService _storageService = StorageService();
  List<Activity> _activities = [];

  List<Activity> get activities => _activities;

  List<Run> get runs {
    // Try to extract Run from each Activity (if possible)
    return _activities.map((a) {
      try {
        return Run.fromCsv(a.fields);
      } catch (_) {
        return null;
      }
    }).whereType<Run>().toList();
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

  Future<void> importCsv() async {
    final newActivities = await _csvService.pickAndParseCsv();
    if (newActivities.isNotEmpty) {
      _activities = newActivities;
      // Optionally, persist activities as JSON if you want full data persistence
      notifyListeners();
    }
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
} 