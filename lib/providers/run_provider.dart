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
import 'dart:convert'; // Added for jsonDecode
import 'package:http/http.dart' as http;

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
    print('[RunProvider.runs] getter called, _activities.length: ${_activities.length}');
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
    print('[RunProvider.streak] getter called');
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
    print('[RunProvider.totalKm] getter called');
    final r = runs;
    if (r.isEmpty) return 0.0;
    return r.fold(0.0, (sum, r) => sum + r.distanceKm);
  }

  double get avgKmPerDay {
    print('[RunProvider.avgKmPerDay] getter called');
    final r = runs;
    if (r.isEmpty) return 0.0;
    final days = r.last.date.difference(r.first.date).inDays + 1;
    return days > 0 ? totalKm / days : totalKm;
  }

  DateTime? get firstDay {
    print('[RunProvider.firstDay] getter called');
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
    print('[importFromStrava] ENTERED, athleteId:  [36m$_athleteId [0m');
    print('[importFromStrava] START');
    _isImporting = true;
    _importProgress = 0;
    _importTotal = 0;
    _importStatus = 'Calculating estimated time...';
    notifyListeners();

    await ensureAthleteId();
    print('[importFromStrava] athleteId: $_athleteId');
    if (_athleteId == null) {
      print('[importFromStrava] ERROR: Could not determine Strava athlete ID.');
      _importStatus = 'Could not determine Strava athlete ID.';
      notifyListeners();
      return;
    }

    print('[importFromStrava] Fetching activities from Strava...');
    final stravaActivities = await _stravaService.fetchActivities();
    print('[importFromStrava] Activities fetched: ${stravaActivities.length}');
    final filteredActivities = stravaActivities.where((a) {
      final type = (a['type'] ?? '').toString().toLowerCase();
      return type == 'run' || type == 'trailrun';
    }).toList();
    print('[importFromStrava] Filtered activities: ${filteredActivities.length}');

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
        // 'Country': country ?? '',
        'Avg Heart Rate': avgHeartRate ?? '',
        'Max Heart Rate': maxHeartRate ?? '',
      };
      newActivities.add(Activity(fields));
      _importProgress = i + 1;
      _importStatus = 'Syncing activities from Strava... (${_importProgress}/${_importTotal})';
      if (i % 100 == 0) print('[importFromStrava] Processed activity $i/${filteredActivities.length}');
      notifyListeners();
    }
    print('[importFromStrava] All activities processed.');

    _importStatus = 'Uploading to cloud...';
    notifyListeners();
    _isSyncingCloud = true;
    try {
      _activities = newActivities;
      print('[importFromStrava] Saving activities locally...');
      await _storageService.saveActivities(_athleteId!, _activities);
      print('[importFromStrava] Uploading activities to Supabase...');
      await _supabaseService.uploadActivities(_athleteId!, _activities);
      print('[importFromStrava] Upload complete.');
    } finally {
      _isSyncingCloud = false;
      notifyListeners();
    }

    _importStatus = 'Finalizing...';
    notifyListeners();

    debugPrintAllActivities();
    print('[importFromStrava] END');
    // Remove country statistics debug output
    _isImporting = false;
    _importProgress = 0;
    _importTotal = 0;
    _importStatus = '';
    notifyListeners();
  }

  /// Smart sync from Strava: afterOAuth = true means only fetch new activities using 'after' param.
  /// afterOAuth = false (manual sync) means full two-way sync (add new, delete missing).
  Future<void> smartSyncFromStrava({bool afterOAuth = false}) async {
    print('[smartSyncFromStrava] METHOD ENTERED with afterOAuth: $afterOAuth');
    await ensureAthleteId();
    if (_athleteId == null) {
      _importStatus = 'Could not determine Strava athlete ID.';
      notifyListeners();
      return;
    }
    _isImporting = true;
    _importProgress = 0;
    _importTotal = 0;
    _importStatus = 'Syncing with Strava...';
    notifyListeners();

    // 1. Load all activities from Supabase
    print('[smartSyncFromStrava] Step 1: Loading activities from Supabase for athlete $_athleteId');
    List<Activity> supabaseActivities = [];
    try {
      print('[smartSyncFromStrava] Step 1: About to call _supabaseService.fetchActivities($_athleteId)');
      supabaseActivities = await _supabaseService.fetchActivities(_athleteId!);
      print('[smartSyncFromStrava] Step 1: Received ${supabaseActivities.length} activities from Supabase');
    } catch (e, stackTrace) {
      print('[smartSyncFromStrava] Step 1: ERROR fetching from Supabase: $e');
      print('[smartSyncFromStrava] Step 1: Stack trace: $stackTrace');
      print('[smartSyncFromStrava] Step 1: Continuing with empty Supabase activities list');
      supabaseActivities = [];
    }
    final supabaseIds = supabaseActivities.map((a) => a.id).toSet();
    print('[smartSyncFromStrava] Step 1: Supabase IDs count: ${supabaseIds.length}');
    DateTime? latestDate;
    if (supabaseActivities.isNotEmpty) {
      latestDate = supabaseActivities
        .map((a) => DateTime.tryParse(a.fields['Date'] ?? ''))
        .whereType<DateTime>()
        .fold<DateTime?>(null, (prev, curr) => prev == null || curr.isAfter(prev) ? curr : prev);
      print('[smartSyncFromStrava] Step 1: Latest date from Supabase: $latestDate');
    } else {
      print('[smartSyncFromStrava] Step 1: No activities found in Supabase');
    }

    // 2. Fetch activities from Strava (with progress per page)
    List<Map<String, dynamic>> stravaRaw = [];
    int page = 1;
    const int perPage = 200;
    int? afterTimestamp = (afterOAuth && latestDate != null) ? (latestDate.millisecondsSinceEpoch ~/ 1000) : null;
    bool morePages = true;
    int totalFetched = 0;
    while (morePages) {
      String url = '${StravaService.activitiesUrl}?per_page=$perPage&page=$page';
      if (afterTimestamp != null) url += '&after=$afterTimestamp';
      _importStatus = 'Fetching page $page from Strava...';
      notifyListeners();
      try {
        final accessToken = await _stravaService.getAccessToken();
        final response = await http.get(
          Uri.parse(url),
          headers: {'Authorization': 'Bearer $accessToken'},
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is List && data.isNotEmpty) {
            stravaRaw.addAll(List<Map<String, dynamic>>.from(data));
            totalFetched += data.length;
            if (data.length < perPage) {
              morePages = false;
            } else {
              page++;
            }
          } else {
            morePages = false;
          }
        } else {
          print('[StravaService] Error fetching page $page: ${response.statusCode}');
          morePages = false;
        }
      } catch (e) {
        print('[StravaService] Exception fetching page $page: $e');
        morePages = false;
      }
    }
    print('[smartSyncFromStrava] Total activities fetched from Strava: $totalFetched');

    // 3. Filter to runs only
    final filteredActivities = stravaRaw.where((a) {
      final type = (a['type'] ?? '').toString().toLowerCase();
      return type == 'run' || type == 'trailrun';
    }).toList();
    print('[smartSyncFromStrava] Filtered to runs: ${filteredActivities.length}');

    // 4. Map to Activity objects with robust date parsing
    List<Activity> newActivities = [];
    int skipped = 0;
    for (int i = 0; i < filteredActivities.length; i++) {
      final a = filteredActivities[i];
      final startLat = (a['start_latlng'] is List && a['start_latlng'].isNotEmpty) ? double.tryParse(a['start_latlng'][0].toString()) ?? 0.0 : 0.0;
      final startLon = (a['start_latlng'] is List && a['start_latlng'].length > 1) ? double.tryParse(a['start_latlng'][1].toString()) ?? 0.0 : 0.0;
      final distanceMeters = (a['distance'] ?? 0).toString();
      final distanceKm = double.tryParse(distanceMeters) != null ? (double.parse(distanceMeters) / 1000).toString() : '0.0';
      final dateLocal = (a['start_date_local'] ?? a['start_date'] ?? '').toString();
      DateTime? parsedDate;
      try {
        parsedDate = DateTime.parse(dateLocal);
      } catch (e) {
        print('[smartSyncFromStrava] Skipped activity (invalid date: "$dateLocal"): id=${a['id']}, error: $e');
        skipped++;
        continue;
      }
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
      _importTotal = filteredActivities.length;
      if ((i + 1) % 100 == 0) print('[smartSyncFromStrava] Processed $i/${filteredActivities.length} activities');
      if ((i + 1) % 20 == 0) {
        _importStatus = 'Processing ${i + 1}/${filteredActivities.length} activities...';
        notifyListeners();
      }
    }
    print('[smartSyncFromStrava] Skipped $skipped activities due to invalid dates.');

    if (afterOAuth) {
      final newOnes = newActivities.where((a) => !supabaseIds.contains(a.id)).toList();
      if (newOnes.isNotEmpty) {
        _importStatus = 'Uploading ${newOnes.length} new activities to Supabase...';
        notifyListeners();
        await _supabaseService.uploadActivities(_athleteId!, newOnes);
      }
      _activities = [...supabaseActivities, ...newOnes];
    } else {
      final stravaIds = newActivities.map((a) => a.id).toSet();
      final toUpload = newActivities.where((a) => !supabaseIds.contains(a.id)).toList();
      if (toUpload.isNotEmpty) {
        _importStatus = 'Uploading ${toUpload.length} new activities to Supabase...';
        notifyListeners();
        await _supabaseService.uploadActivities(_athleteId!, toUpload);
      }
      final toDelete = supabaseActivities.where((a) => !stravaIds.contains(a.id)).toList();
      if (toDelete.isNotEmpty) {
        _importStatus = 'Deleting ${toDelete.length} activities from Supabase...';
        notifyListeners();
        for (final a in toDelete) {
          await _supabaseService.deleteActivity(_athleteId!, a.id!);
        }
      }
      _activities = [...newActivities];
    }
    await _storageService.saveActivities(_athleteId!, _activities);
    _isImporting = false;
    _importStatus = '';
    notifyListeners();
    print('[smartSyncFromStrava] Done. Fetched: $totalFetched, Filtered: ${filteredActivities.length}, Uploaded: ${newActivities.length - skipped}, Deleted: ${afterOAuth ? 0 : (supabaseActivities.length - _activities.length)}, Skipped: $skipped');
  }

  Future<void> loadRuns() async {
    print('[RunProvider] loadRuns called');
    await ensureAthleteId();
    if (_athleteId == null) {
      print('[RunProvider] No athlete ID, clearing activities');
      _activities = [];
      notifyListeners();
      return;
    }
    print('[RunProvider] Loading runs for athlete: $_athleteId');
    _isSyncingCloud = true;
    notifyListeners();
    try {
      // Fetch from Supabase
      print('[RunProvider] ABOUT TO CALL _supabaseService.fetchActivities($_athleteId)');
      print('[RunProvider] _supabaseService instance: $_supabaseService');
      final cloudActivities = await _supabaseService.fetchActivities(_athleteId!);
      print('[RunProvider] Received ${cloudActivities.length} activities from Supabase');
      
      // Optionally merge with local
      _activities = cloudActivities;
      print('[RunProvider] Set _activities to ${_activities.length} activities');
      
      // Debug: Check for 2024-11-14 specifically
      final targetDate = DateTime(2024, 11, 14);
      final activitiesOnTargetDate = _activities.where((activity) {
        try {
          final activityDate = DateTime.parse(activity.fields['Date'] ?? '');
          return activityDate.year == targetDate.year && 
                 activityDate.month == targetDate.month && 
                 activityDate.day == targetDate.day;
        } catch (e) {
          return false;
        }
      }).toList();
      
      if (activitiesOnTargetDate.isNotEmpty) {
        print('[RunProvider] FOUND 2024-11-14 activities: ${activitiesOnTargetDate.length}');
        for (final activity in activitiesOnTargetDate) {
          print('[RunProvider] 2024-11-14 activity: ${activity.fields['Title']} - ${activity.fields['Distance']} km');
        }
      } else {
        print('[RunProvider] NO 2024-11-14 activities found in ${_activities.length} total activities');
      }
      
      await _storageService.saveActivities(_athleteId!, _activities);
      print('[RunProvider] Saved activities to local storage');
    } catch (e, stackTrace) {
      print('[RunProvider] ERROR in loadRuns: $e');
      print('[RunProvider] Stack trace: $stackTrace');
    } finally {
      _isSyncingCloud = false;
      notifyListeners();
      print('[RunProvider] loadRuns completed');
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
    print('[DEBUG] _qualifiedRuns getter called');
    print('[DEBUG] Total runs available: ${runs.length}');
    
    // Group by local date (year, month, day) as in the activity's local time zone
    final byDate = <DateTime, double>{};
    for (final run in runs) {
      // Use the date as-is, assuming it is already in the activity's local time zone
      final localDay = DateTime(run.date.year, run.date.month, run.date.day);
      byDate[localDay] = (byDate[localDay] ?? 0) + run.distanceKm;
    }
    
    print('[DEBUG] Total unique dates: ${byDate.length}');
    
    // Debug: Check for specific date 2024-11-14
    final targetDate = DateTime(2024, 11, 14);
    if (byDate.containsKey(targetDate)) {
      print('[DEBUG] Found 2024-11-14 with distance: ${byDate[targetDate]} km');
    } else {
      print('[DEBUG] 2024-11-14 NOT FOUND in byDate. Available dates around that time:');
      final sortedDates = byDate.keys.toList()..sort();
      final nearbyDates = sortedDates.where((date) => 
        date.isAfter(DateTime(2024, 11, 10)) && date.isBefore(DateTime(2024, 11, 20))
      ).toList();
      for (final date in nearbyDates) {
        print('[DEBUG] ${date.toIso8601String().split('T')[0]}: ${byDate[date]} km');
      }
    }
    
    final qualified = byDate.entries.where((e) => e.value >= 1.61).toList();
    print('[DEBUG] Qualified runs (>= 1.61 km): ${qualified.length}');
    
    // Debug: Check if 2024-11-14 is in qualified runs
    final qualifiedTargetDate = qualified.where((e) => 
      e.key.year == 2024 && e.key.month == 11 && e.key.day == 14
    ).toList();
    if (qualifiedTargetDate.isNotEmpty) {
      print('[DEBUG] 2024-11-14 is QUALIFIED with distance: ${qualifiedTargetDate.first.value} km');
    } else {
      print('[DEBUG] 2024-11-14 is NOT QUALIFIED (distance < 1.61 km or not found)');
    }
    
    final result = qualified
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
    
    print('[DEBUG] Returning ${result.length} qualified runs');
    return result;
  }

  // --- New Streak and Stats Logic ---
  // Helper: Get sorted qualified runs (descending by date)
  List<Run> get _sortedQualifiedRuns => _qualifiedRuns;

  // Current streak (consecutive days up to most recent)
  int get currentStreak {
    print('[DEBUG] currentStreak getter called');
    final r = _sortedQualifiedRuns;
    print('[DEBUG] Sorted qualified runs: ${r.length}');
    if (r.isEmpty) return 0;
    
    print('[DEBUG] Most recent date: ${r.first.date.toIso8601String().split('T')[0]}');
    print('[DEBUG] Second most recent date: ${r.length > 1 ? r[1].date.toIso8601String().split('T')[0] : 'N/A'}');
    
    int streak = 1;
    for (int i = 1; i < r.length; i++) {
      final diff = r[i - 1].date.difference(r[i].date).inDays;
      print('[DEBUG] Date ${r[i-1].date.toIso8601String().split('T')[0]} vs ${r[i].date.toIso8601String().split('T')[0]}: diff = $diff days');
      if (diff == 1) {
        streak++;
        print('[DEBUG] Streak continues: $streak days');
      } else if (diff > 1) {
        print('[DEBUG] Streak broken at ${r[i].date.toIso8601String().split('T')[0]} (gap of $diff days)');
        break;
      }
    }
    print('[DEBUG] Final streak: $streak days');
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
    print('[RunProvider] ensureAthleteId called');
    if (_athleteId == null) {
      print('[RunProvider] No athlete ID stored, fetching from Strava service...');
      _athleteId = await _stravaService.getAthleteId();
      print('[RunProvider] Got athlete ID: $_athleteId');
    } else {
      print('[RunProvider] Using existing athlete ID: $_athleteId');
    }
    print('[RunProvider] ensureAthleteId completed with athleteId: $_athleteId');
    if (_athleteId == null) {
      print('[RunProvider] WARNING: athleteId is still null after ensureAthleteId!');
    }
  }
} 