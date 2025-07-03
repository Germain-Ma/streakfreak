import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/run.dart';

class StorageService {
  static const _key = 'runs_json';

  Future<void> saveRuns(List<Run> runs) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = runs.map((r) => r.toJson()).toList();
    await prefs.setString(_key, jsonEncode(jsonList));
  }

  Future<List<Run>> loadRuns() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null) return [];
    final List<dynamic> jsonList = jsonDecode(jsonStr);
    return jsonList.map((j) => Run.fromJson(j)).toList();
  }

  Future<void> clearRuns() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
} 