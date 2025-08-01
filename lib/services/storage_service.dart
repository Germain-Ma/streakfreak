// This StorageService uses shared_preferences for web compatibility. ObjectBox is not supported on Flutter web.
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/run.dart';
import '../models/activity.dart';

class StorageService {
  String _runsKey(String athleteId) => 'runs_json_ $athleteId';
  String _activitiesKey(String athleteId) => 'activities_json_ $athleteId';

  Future<void> saveRuns(String athleteId, List<Run> runs) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = runs.map((r) => r.toJson()).toList();
    await prefs.setString(_runsKey(athleteId), jsonEncode(jsonList));
  }

  Future<List<Run>> loadRuns(String athleteId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_runsKey(athleteId));
    if (jsonStr == null) return [];
    final List<dynamic> jsonList = jsonDecode(jsonStr);
    return jsonList.map((j) => Run.fromJson(j)).toList();
  }

  Future<void> clearRuns(String athleteId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_runsKey(athleteId));
  }

  Future<void> saveActivities(String athleteId, List<Activity> activities) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = activities.map((a) => a.fields).toList();
    await prefs.setString(_activitiesKey(athleteId), jsonEncode(jsonList));
  }

  Future<List<Activity>> loadActivities(String athleteId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_activitiesKey(athleteId));
    if (jsonStr == null) return [];
    final List<dynamic> jsonList = jsonDecode(jsonStr);
    return jsonList.map((j) => Activity(Map<String, String>.from(j))).toList();
  }

  Future<void> clearActivities(String athleteId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activitiesKey(athleteId));
  }
} 