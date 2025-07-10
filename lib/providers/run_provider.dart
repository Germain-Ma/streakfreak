import 'package:flutter/material.dart';
import '../models/run.dart';
import '../models/activity.dart';
import '../services/csv_service.dart';
import '../services/storage_service.dart';
import 'package:intl/intl.dart';
import '../services/strava_service.dart';
import '../services/geocoding_service.dart';
import '../services/web_geocoding_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

class RunProvider extends ChangeNotifier {
  final CsvService _csvService = CsvService();
  final StorageService _storageService = StorageService();
  final StravaService _stravaService = StravaService();
  final GeocodingService _geocodingService = GeocodingService();
  final WebGeocodingService _webGeocodingService = WebGeocodingService();
  StravaService get stravaService => _stravaService;
  List<Activity> _activities = [];
  // Progress tracking
  bool _isImporting = false;
  int _importProgress = 0;
  int _importTotal = 0;
  String _importStatus = '';
  // Supabase sync state
  bool _isSyncing = false;
  String _syncStatus = '';
  DateTime? _lastSyncTime;
  bool get isSyncing => _isSyncing;
  String get syncStatus => _syncStatus;
  DateTime? get lastSyncTime => _lastSyncTime;

  bool get isImporting => _isImporting;
  int get importProgress => _importProgress;
  int get importTotal => _importTotal;
  String get importStatus => _importStatus;
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

  void debugPrintAllActivities() {
    final allRuns = runs;
    final withGps = allRuns.where((r) => r.lat != 0.0 || r.lon != 0.0).length;
    final withoutGps = allRuns.length - withGps;
    print('--- DEBUG: Activities Summary ---');
    print('Total runs: ${allRuns.length}');
    print('Runs with GPS: $withGps');
    print('Runs without GPS: $withoutGps');
    if (allRuns.isNotEmpty) {
      print('First 2 runs:');
      for (final run in allRuns.take(2)) {
        print('  Date: ${run.date.toIso8601String()}, Distance: ${run.distanceKm}, Title: ${run.title}');
      }
      print('Last 2 runs:');
      for (final run in allRuns.reversed.take(2)) {
        print('  Date: ${run.date.toIso8601String()}, Distance: ${run.distanceKm}, Title: ${run.title}');
      }
    }
    print('--- END DEBUG ---');
  }

  /// Import activities from Strava API
  Future<void> importFromStrava() async {
    _isImporting = true;
    _importProgress = 0;
    _importTotal = 0;
    _importStatus = 'Fetching activities from Strava...';
    notifyListeners();

    final stravaActivities = await _stravaService.fetchActivities();
    final filteredActivities = stravaActivities.where((a) {
      final type = (a['type'] ?? '').toString().toLowerCase();
      return type == 'run' || type == 'trailrun';
    }).toList();

    _importTotal = filteredActivities.length;
    _importStatus = 'Processing ${_importTotal} activities...';
    notifyListeners();

    List<Activity> newActivities = [];
    List<Future<void>> countryFutures = [];
    List<String?> countryResults = List.filled(filteredActivities.length, null);
    int gpsDebugCount = 0;

    // Process activities in batches for better progress tracking
    const int batchSize = 50;
    for (int batchStart = 0; batchStart < filteredActivities.length; batchStart += batchSize) {
      final batchEnd = (batchStart + batchSize < filteredActivities.length)
          ? batchStart + batchSize
          : filteredActivities.length;

      for (int i = batchStart; i < batchEnd; i++) {
        final a = filteredActivities[i];
        final startLat = (a['start_latlng'] is List && a['start_latlng'].isNotEmpty) ? double.tryParse(a['start_latlng'][0].toString()) ?? 0.0 : 0.0;
        final startLon = (a['start_latlng'] is List && a['start_latlng'].length > 1) ? double.tryParse(a['start_latlng'][1].toString()) ?? 0.0 : 0.0;
        if ((startLat != 0.0 || startLon != 0.0) && gpsDebugCount < 5) {
          countryFutures.add((kIsWeb
              ? _webGeocodingService.countryFromLatLon(startLat, startLon)
              : _geocodingService.countryFromLatLon(startLat, startLon)).then((country) {
            print('[DEBUG] GPS: ($startLat, $startLon) -> Country: $country');
            countryResults[i] = country;
          }));
          gpsDebugCount++;
        } else if (startLat != 0.0 || startLon != 0.0) {
          countryFutures.add((kIsWeb
              ? _webGeocodingService.countryFromLatLon(startLat, startLon)
              : _geocodingService.countryFromLatLon(startLat, startLon)).then((country) {
            countryResults[i] = country;
          }));
        }
      }

      // Wait for current batch to complete
      await Future.wait(countryFutures);
      countryFutures.clear();

      // Update progress
      _importProgress = batchEnd;
      _importStatus = 'Processing activities... (${_importProgress}/${_importTotal})';
      notifyListeners();
    }

    _importStatus = 'Creating activity records...';
    notifyListeners();

    // Create activity records
    for (int i = 0; i < filteredActivities.length; i++) {
      final a = filteredActivities[i];
      final startLat = (a['start_latlng'] is List && a['start_latlng'].isNotEmpty) ? double.tryParse(a['start_latlng'][0].toString()) ?? 0.0 : 0.0;
      final startLon = (a['start_latlng'] is List && a['start_latlng'].length > 1) ? double.tryParse(a['start_latlng'][1].toString()) ?? 0.0 : 0.0;
      final country = countryResults[i];
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
        'Country': country ?? '',
        'Avg Heart Rate': avgHeartRate ?? '',
        'Max Heart Rate': maxHeartRate ?? '',
      };
      newActivities.add(Activity(fields));
    }

    _importStatus = 'Saving activities...';
    notifyListeners();

    _activities = newActivities;
    await _storageService.saveActivities(_activities);
    await _saveRunsToSupabase(_activities);

    _importStatus = 'Finalizing...';
    notifyListeners();

    debugPrintAllActivities();
    // Debug output for country statistics
    final runsList = runs;
    final countryStats = <String, int>{};
    for (final run in runsList) {
      final country = run.country ?? '';
      if (country.trim().isEmpty) continue;
      countryStats[country] = (countryStats[country] ?? 0) + 1;
    }
    final sortedCountries = countryStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    print('--- DEBUG: Country Statistics ---');
    for (final entry in sortedCountries) {
      print('${entry.key}: ${entry.value}');
    }
    print('--- END COUNTRY DEBUG ---');

    _isImporting = false;
    _importProgress = 0;
    _importTotal = 0;
    _importStatus = '';
    notifyListeners();
  }

  // Load runs: local -> Supabase -> Strava
  Future<void> loadRunsSmart() async {
    // 1. Try local
    final local = await _storageService.loadActivities();
    if (local.isNotEmpty) {
      _activities = local;
      notifyListeners();
      return;
    }
    // 2. Try Supabase
    final supabaseRuns = await _loadRunsFromSupabase();
    if (supabaseRuns.isNotEmpty) {
      _activities = supabaseRuns;
      await _storageService.saveActivities(_activities);
      notifyListeners();
      return;
    }
    // 3. Prompt Strava import (UI should handle this)
    _activities = [];
    notifyListeners();
  }

  // Load from Supabase
  Future<List<Activity>> _loadRunsFromSupabase() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];
    final response = await Supabase.instance.client
        .from('runs')
        .select()
        .eq('user_id', user.id)
        .order('date', ascending: false);
    if (response is List) {
      return response.map((row) => Activity(_supabaseRowToFields(row))).toList();
    }
    return [];
  }

  // Save to Supabase
  Future<void> _saveRunsToSupabase(List<Activity> activities) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    // Remove all user's runs first (for full sync)
    await Supabase.instance.client.from('runs').delete().eq('user_id', user.id);
    // Insert all
    for (final a in activities) {
      final fields = a.fields;
      await Supabase.instance.client.from('runs').insert({
        'user_id': user.id,
        'date': fields['Date'],
        'distance': double.tryParse(fields['Distance'] ?? '') ?? 0.0,
        'title': fields['Title'],
        'lat': double.tryParse(fields['Start Latitude'] ?? '') ?? 0.0,
        'lon': double.tryParse(fields['Start Longitude'] ?? '') ?? 0.0,
        'elevation_gain': double.tryParse(fields['Elevation Gain'] ?? '') ?? 0.0,
        'moving_time': int.tryParse(fields['Moving Time'] ?? '') ?? 0,
        'elapsed_time': int.tryParse(fields['Elapsed Time'] ?? '') ?? 0,
        'avg_speed': double.tryParse(fields['Average Speed'] ?? '') ?? 0.0,
        'max_speed': double.tryParse(fields['Max Speed'] ?? '') ?? 0.0,
        'calories': int.tryParse(fields['Calories'] ?? '') ?? 0,
        'strava_id': fields['Strava ID'],
        'country': fields['Country'],
        'avg_heart_rate': double.tryParse(fields['Avg Heart Rate'] ?? ''),
        'max_heart_rate': double.tryParse(fields['Max Heart Rate'] ?? ''),
      });
    }
  }

  // Helper: convert Supabase row to Activity fields
  Map<String, String> _supabaseRowToFields(Map row) {
    return {
      'Activity Type': 'run',
      'Date': row['date'] ?? '',
      'Distance': (row['distance'] ?? '').toString(),
      'Title': row['title'] ?? '',
      'Start Latitude': (row['lat'] ?? '').toString(),
      'Start Longitude': (row['lon'] ?? '').toString(),
      'Strava ID': row['strava_id'] ?? '',
      'Elevation Gain': (row['elevation_gain'] ?? '').toString(),
      'Moving Time': (row['moving_time'] ?? '').toString(),
      'Elapsed Time': (row['elapsed_time'] ?? '').toString(),
      'Average Speed': (row['avg_speed'] ?? '').toString(),
      'Max Speed': (row['max_speed'] ?? '').toString(),
      'Calories': (row['calories'] ?? '').toString(),
      'Country': row['country'] ?? '',
      'Avg Heart Rate': (row['avg_heart_rate'] ?? '').toString(),
      'Max Heart Rate': (row['max_heart_rate'] ?? '').toString(),
    };
  }

  // Sync local and Supabase (prefer most recent, or merge)
  Future<void> syncWithSupabase() async {
    _isSyncing = true;
    _syncStatus = 'Syncing with cloud...';
    notifyListeners();
    final local = await _storageService.loadActivities();
    final cloud = await _loadRunsFromSupabase();
    // Simple strategy: if local is newer or same, upload; if cloud is newer, download
    if (local.length >= cloud.length) {
      await _saveRunsToSupabase(local);
      _activities = local;
      _syncStatus = 'Uploaded local data to cloud.';
    } else {
      _activities = cloud;
      await _storageService.saveActivities(cloud);
      _syncStatus = 'Downloaded cloud data to local.';
    }
    _lastSyncTime = DateTime.now();
    _isSyncing = false;
    notifyListeners();
  }

  // Sync with Strava (if cloud/local are empty or outdated)
  Future<void> syncWithStravaIfNeeded() async {
    final local = await _storageService.loadActivities();
    final cloud = await _loadRunsFromSupabase();
    if (local.isEmpty && cloud.isEmpty) {
      await importFromStrava();
      await _saveRunsToSupabase(_activities);
    }
  }

  Future<void> clearRuns() async {
    _activities = [];
    await _storageService.clearActivities();
    notifyListeners();
  }

  // Efficient smart sync: local <-> Supabase <-> Strava
  Future<void> smartSync() async {
    _isSyncing = true;
    _syncStatus = 'Checking sync status...';
    notifyListeners();
    // 1. Load local and Supabase
    final local = await _storageService.loadActivities();
    final cloud = await _loadRunsFromSupabase();
    // 2. Compare by latest run date/ID
    DateTime? localLatest = _getLatestRunDate(local);
    DateTime? cloudLatest = _getLatestRunDate(cloud);
    // 3. Sync local <-> Supabase
    if (localLatest != null && (cloudLatest == null || localLatest.isAfter(cloudLatest))) {
      await _saveRunsToSupabase(local);
      _activities = local;
      _syncStatus = 'Uploaded local data to cloud.';
    } else if (cloudLatest != null && (localLatest == null || cloudLatest.isAfter(localLatest))) {
      _activities = cloud;
      await _storageService.saveActivities(cloud);
      _syncStatus = 'Downloaded cloud data to local.';
    } else {
      _activities = local;
      _syncStatus = 'Local and cloud are in sync.';
    }
    notifyListeners();
    // 4. Check Strava for new runs
    final stravaActivities = await _stravaService.fetchActivities();
    final stravaRuns = stravaActivities.where((a) {
      final type = (a['type'] ?? '').toString().toLowerCase();
      return type == 'run' || type == 'trailrun';
    }).toList();
    DateTime? stravaLatest = _getLatestStravaRunDate(stravaRuns);
    if (stravaLatest != null && (cloudLatest == null || stravaLatest.isAfter(cloudLatest))) {
      // Only import new runs from Strava
      final existingIds = cloud.map((a) => a.fields['Strava ID']).toSet();
      final newStravaRuns = stravaRuns.where((a) => !existingIds.contains((a['id'] ?? '').toString())).toList();
      if (newStravaRuns.isNotEmpty) {
        _syncStatus = 'Importing new runs from Strava...';
        notifyListeners();
        // Use existing import logic, but only for new runs
        List<Activity> newActivities = [];
        List<Future<void>> countryFutures = [];
        List<String?> countryResults = List.filled(newStravaRuns.length, null);
        int gpsDebugCount = 0;
        for (int i = 0; i < newStravaRuns.length; i++) {
          final a = newStravaRuns[i];
          final startLat = (a['start_latlng'] is List && a['start_latlng'].isNotEmpty) ? double.tryParse(a['start_latlng'][0].toString()) ?? 0.0 : 0.0;
          final startLon = (a['start_latlng'] is List && a['start_latlng'].length > 1) ? double.tryParse(a['start_latlng'][1].toString()) ?? 0.0 : 0.0;
          if ((startLat != 0.0 || startLon != 0.0) && gpsDebugCount < 5) {
            countryFutures.add((kIsWeb
                ? _webGeocodingService.countryFromLatLon(startLat, startLon)
                : _geocodingService.countryFromLatLon(startLat, startLon)).then((country) {
              countryResults[i] = country;
            }));
            gpsDebugCount++;
          } else if (startLat != 0.0 || startLon != 0.0) {
            countryFutures.add((kIsWeb
                ? _webGeocodingService.countryFromLatLon(startLat, startLon)
                : _geocodingService.countryFromLatLon(startLat, startLon)).then((country) {
              countryResults[i] = country;
            }));
          }
        }
        await Future.wait(countryFutures);
        for (int i = 0; i < newStravaRuns.length; i++) {
          final a = newStravaRuns[i];
          final startLat = (a['start_latlng'] is List && a['start_latlng'].isNotEmpty) ? double.tryParse(a['start_latlng'][0].toString()) ?? 0.0 : 0.0;
          final startLon = (a['start_latlng'] is List && a['start_latlng'].length > 1) ? double.tryParse(a['start_latlng'][1].toString()) ?? 0.0 : 0.0;
          final country = countryResults[i];
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
            'Country': country ?? '',
            'Avg Heart Rate': avgHeartRate ?? '',
            'Max Heart Rate': maxHeartRate ?? '',
          };
          newActivities.add(Activity(fields));
        }
        // Merge new activities with existing
        final merged = List<Activity>.from(cloud)..addAll(newActivities);
        _activities = merged;
        await _storageService.saveActivities(merged);
        await _saveRunsToSupabase(merged);
        _syncStatus = 'Imported new runs from Strava.';
      }
    }
    _lastSyncTime = DateTime.now();
    _isSyncing = false;
    notifyListeners();
  }

  DateTime? _getLatestRunDate(List<Activity> activities) {
    if (activities.isEmpty) return null;
    final dates = activities.map((a) => DateTime.tryParse(a.fields['Date'] ?? '')).whereType<DateTime>().toList();
    if (dates.isEmpty) return null;
    dates.sort((a, b) => b.compareTo(a));
    return dates.first;
  }

  DateTime? _getLatestStravaRunDate(List<Map<String, dynamic>> stravaRuns) {
    if (stravaRuns.isEmpty) return null;
    final dates = stravaRuns.map((a) => DateTime.tryParse((a['start_date_local'] ?? a['start_date'] ?? '').toString())).whereType<DateTime>().toList();
    if (dates.isEmpty) return null;
    dates.sort((a, b) => b.compareTo(a));
    return dates.first;
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
} 