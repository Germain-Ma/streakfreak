import 'package:flutter/material.dart';
import '../models/run.dart';
import '../models/activity.dart';
import '../services/csv_service.dart';
import '../services/storage_service.dart';
import 'package:intl/intl.dart';
import '../services/strava_service.dart';
// Remove geocoding imports
// import '../services/geocoding_service.dart';
// import '../services/web_geocoding_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RunProvider extends ChangeNotifier {
  final CsvService _csvService = CsvService();
  final StorageService _storageService = StorageService();
  final StravaService _stravaService = StravaService();
  // Remove geocoding service fields
  // final GeocodingService _geocodingService = GeocodingService();
  // final WebGeocodingService _webGeocodingService = WebGeocodingService();
  final SupabaseService _supabaseService = SupabaseService();
  StravaService get stravaService => _stravaService;
  List<Activity> _activities = [];
  // Progress tracking
  bool _isImporting = false;
  int _importProgress = 0;
  int _importTotal = 0;
  String _importStatus = '';
  String? _athleteId;
  bool _isSyncingCloud = false;
  bool get isSyncingCloud => _isSyncingCloud;

  bool get isImporting => _isImporting;
  int get importProgress => _importProgress;
  int get importTotal => _importTotal;
  String get importStatus => _importStatus;
  static int runsGetterCallCount = 0;

  List<Activity> get activities => _activities;

  List<Run> get runs {
    runsGetterCallCount++;
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

  double get totalKm {
    final r = runs;
    if (r.isEmpty) return 0.0;
    return r.fold(0.0, (sum, r) => sum + r.distanceKm);
  }

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

  void debugPrintAllActivities() {
    // Removed debug prints
  }

  /// Import activities from Strava API
  Future<void> importFromStrava() async {
    _isImporting = true;
    _importProgress = 0;
    _importTotal = 0;
    _importStatus = 'Calculating estimated time...';
    notifyListeners();

    await ensureAthleteId();
    if (_athleteId == null) {
      _importStatus = 'Could not determine Strava athlete ID.';
      notifyListeners();
      return;
    }

    final stravaActivities = await _stravaService.fetchActivities();
    final filteredActivities = stravaActivities.where((a) {
      final type = (a['type'] ?? '').toString().toLowerCase();
      return type == 'run' || type == 'trailrun';
    }).toList();

    _importTotal = filteredActivities.length;
    _importStatus = 'Syncing activities from Strava... (${_importProgress}/${_importTotal})';
    notifyListeners();

    // Remove all country lookup and assignment logic
    List<Activity> newActivities = [];
    for (int i = 0; i < filteredActivities.length; i++) {
      final a = filteredActivities[i];
      final startLat = (a['start_latlng'] is List && a['start_latlng'].isNotEmpty) ? double.tryParse(a['start_latlng'][0].toString()) ?? 0.0 : 0.0;
      final startLon = (a['start_latlng'] is List && a['start_latlng'].length > 1) ? double.tryParse(a['start_latlng'][1].toString()) ?? 0.0 : 0.0;
      final distanceMeters = (a['distance'] ?? 0).toString();
      final distanceKm = double.tryParse(distanceMeters) != null ? (double.parse(distanceMeters) / 1000).toString() : '0.0';
      final dateLocal = (a['start_date_local'] ?? a['start_date'] ?? '').toString();
      final avgHeartRate = a['average_heartrate']?.toString();
      final maxHeartRate = a['max_heartrate']?.toString();
      final fields = <String, String>{
        'Activity Type': (a['type'] ?? '').toString(),
        'Date': dateLocal,
        'Distance': distanceKm,
        'Title': (a['name'] ?? '').toString(),
        'Start Latitude': startLat.toString(),
        'Start Longitude': startLon.toString(),
        'Strava ID': (a['id'] ?? '').toString(),
        'Elevation Gain': (a['total_elevation_gain'] ?? '').toString(),
        'Moving Time': (a['moving_time'] ?? '').toString(),
        'Elapsed Time': (a['elapsed_time'] ?? '').toString(),
        'Average Speed': (a['average_speed'] ?? '').toString(),
        'Max Speed': (a['max_speed'] ?? '').toString(),
        'Calories': (a['calories'] ?? '').toString(),
        'Avg Heart Rate': avgHeartRate ?? '',
        'Max Heart Rate': maxHeartRate ?? '',
      };
      newActivities.add(Activity(fields));
      _importProgress = i + 1;
      _importStatus = 'Syncing activities from Strava... (${_importProgress}/${_importTotal})';
      notifyListeners();
    }

    _importStatus = 'Uploading to cloud...';
    notifyListeners();
    _isSyncingCloud = true;
    try {
      _activities = newActivities;
      await _storageService.saveActivities(_athleteId!, _activities);
      await _supabaseService.uploadActivities(_athleteId!, _activities);
    } finally {
      _isSyncingCloud = false;
      notifyListeners();
    }

    _importStatus = 'Finalizing...';
    notifyListeners();

    debugPrintAllActivities();
    _isImporting = false;
    _importProgress = 0;
    _importTotal = 0;
    _importStatus = '';
    notifyListeners();
  }

  Future<void> loadRuns() async {
    await ensureAthleteId();
    
    // If no athlete ID from Strava, try to load from local storage or use a default
    if (_athleteId == null) {
      final prefs = await SharedPreferences.getInstance();
      _athleteId = prefs.getString('strava_athlete_id');
      
      if (_athleteId == null) {
        // Fallback athlete ID for localhost development (from working web app)
        _athleteId = '44189670';
      }
    }
    
    if (_athleteId == null) {
      _activities = [];
      notifyListeners();
      return;
    }
    
    _isSyncingCloud = true;
    notifyListeners();
    try {
      // Fetch from Supabase
      final cloudActivities = await _supabaseService.fetchActivities(_athleteId!);
      // Optionally merge with local
      _activities = cloudActivities;
      await _storageService.saveActivities(_athleteId!, _activities);
    } finally {
      _isSyncingCloud = false;
      notifyListeners();
    }
  }

  Future<void> clearRuns() async {
    await ensureAthleteId();
    if (_athleteId == null) {
      _activities = [];
      notifyListeners();
      return;
    }
    _activities = [];
    await _storageService.clearActivities(_athleteId!);
    notifyListeners();
  }

  // Helper: Get runs with at least 1.61 km per day (for streak logic)
  List<Run> get _qualifiedRuns {
    // Group by local date (year, month, day) as in the activity's local time zone
    final byDate = <DateTime, double>{};
    for (final run in runs) {
      // Use the date as-is, assuming it is already in the activity's local time zone
      final localDay = DateTime(run.date.year, run.date.month, run.date.day);
      byDate[localDay] = (byDate[localDay] ?? 0) + run.distanceKm;
    }
    return byDate.entries
      .where((e) => e.value >= 1.61)
      .map<Run>((e) => Run(
        date: e.key,
        distanceKm: e.value,
        lat: 0,
        lon: 0,
        title: '',
        elevationGain: 0,
        movingTime: 0,
        elapsedTime: 0,
        avgSpeed: 0,
        maxSpeed: 0,
        calories: 0,
        stravaId: '',
      ))
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

  Future<void> ensureAthleteId() async {
    _athleteId ??= await _stravaService.getAthleteId();
  }
} 