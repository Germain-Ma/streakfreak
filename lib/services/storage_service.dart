import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/run.dart';
import '../models/activity.dart';

class StorageService {
  static const _keyRuns = 'runs_json';
  static const _keyActivities = 'activities_json';

  Future<void> saveRuns(List<Run> runs) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = runs.map((r) => r.toJson()).toList();
    await prefs.setString(_keyRuns, jsonEncode(jsonList));
  }

  Future<List<Run>> loadRuns() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyRuns);
    if (jsonStr == null) return [];
    final List<dynamic> jsonList = jsonDecode(jsonStr);
    return jsonList.map((j) => Run.fromJson(j)).toList();
  }

  Future<void> clearRuns() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRuns);
  }

  Future<void> saveActivities(List<Activity> activities) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = activities.map((a) => a.fields).toList();
    await prefs.setString(_keyActivities, jsonEncode(jsonList));
  }

  Future<List<Activity>> loadActivities() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyActivities);
    if (jsonStr == null) return [];
    final List<dynamic> jsonList = jsonDecode(jsonStr);
    return jsonList.map((j) => Activity(Map<String, String>.from(j))).toList();
  }

  Future<void> clearActivities() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyActivities);
  }
} 