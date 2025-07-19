import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/activity.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://omiylwulfzrbnklmfcax.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9taXlsd3VsZnpyYm5rbG1mY2F4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIxNjM4MTksImV4cCI6MjA2NzczOTgxOX0.4pqJAWBqi2SG0gn8qn-by_Y4LPiv7m2UfrEKWygUVO0';
  static bool _initialized = false;

  static Future<void> init() async {
    if (!_initialized) {
      try {
        await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
        _initialized = true;
      } catch (e) {
        throw e;
      }
    }
  }

  static SupabaseClient get client => Supabase.instance.client;

  Future<void> uploadActivities(String athleteId, List<Activity> activities) async {
    try {
      await init();
      for (final activity in activities) {
        await client.from('activities').upsert({
          'strava_id': athleteId,
          'activity_id': activity.fields['Strava ID'],
          'data': activity.fields,
        });
      }
    } catch (e) {
      // Silently handle upload errors
    }
  }

  Future<List<Activity>> fetchActivities(String athleteId) async {
    try {
      await init();
      final response = await client
          .from('activities')
          .select('data')
          .eq('strava_id', athleteId);
      
      return response.map((row) => Activity(Map<String, String>.from(row['data']))).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> deleteActivity(String stravaId, String activityId) async {
    await init();
    try {
      await client.from('activities').delete().eq('strava_id', stravaId).eq('activity_id', activityId);
    } catch (e) {
      // Silently handle delete errors
    }
  }
} 