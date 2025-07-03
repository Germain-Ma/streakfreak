import 'package:flutter/material.dart';
import '../models/run.dart';
import '../services/csv_service.dart';
import '../services/storage_service.dart';
import 'package:intl/intl.dart';

class RunProvider extends ChangeNotifier {
  final CsvService _csvService = CsvService();
  final StorageService _storageService = StorageService();
  List<Run> _runs = [];

  List<Run> get runs => _runs;

  // Computed stats
  int get streak {
    if (_runs.isEmpty) return 0;
    _runs.sort((a, b) => b.date.compareTo(a.date));
    int streak = 1;
    for (int i = 1; i < _runs.length; i++) {
      final diff = _runs[i - 1].date.difference(_runs[i].date).inDays;
      if (diff == 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  double get totalKm => _runs.fold(0.0, (sum, r) => sum + r.distanceKm);

  double get avgKmPerDay {
    if (_runs.isEmpty) return 0.0;
    final days = _runs.last.date.difference(_runs.first.date).inDays + 1;
    return days > 0 ? totalKm / days : totalKm;
  }

  DateTime? get firstDay => _runs.isEmpty ? null : _runs.map((r) => r.date).reduce((a, b) => a.isBefore(b) ? a : b);

  Future<void> importCsv() async {
    final newRuns = await _csvService.pickAndParseCsv();
    if (newRuns.isNotEmpty) {
      _runs = newRuns;
      await _storageService.saveRuns(_runs);
      notifyListeners();
    }
  }

  Future<void> loadRuns() async {
    _runs = await _storageService.loadRuns();
    notifyListeners();
  }

  Future<void> clearRuns() async {
    _runs = [];
    await _storageService.clearRuns();
    notifyListeners();
  }
} 