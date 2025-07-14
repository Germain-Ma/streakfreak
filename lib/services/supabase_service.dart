import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/activity.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://omiylwulfzrbnklmfcax.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9taXlsd3VsZnpyYm5rbG1mY2F4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIxNjM4MTksImV4cCI6MjA2NzczOTgxOX0.4pqJAWBqi2SG0gn8qn-by_Y4LPiv7m2UfrEKWygUVO0';
  static bool _initialized = false;

  static Future<void> init() async {
    if (!_initialized) {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      _initialized = true;
    }
  }

  static SupabaseClient get client => Supabase.instance.client;

  Future<void> uploadActivities(String stravaId, List<Activity> activities, {bool uploadIndividually = false}) async {
    await init();
    if (uploadIndividually) {
      for (final activity in activities) {
        try {
          await client.from('activities').upsert([{
            'strava_id': stravaId,
            'activity_id': activity.id,
            'data': activity.toJson(),
          }], onConflict: 'strava_id,activity_id');
        } catch (e) {
          print('[Supabase upload error for activity ${activity.id}]: $e');
        }
      }
    } else {
      try {
        await client.from('activities').upsert(
          activities.where((a) => a.id != null).map((a) => {
            'strava_id': stravaId,
            'activity_id': a.id,
            'data': a.toJson(),
          }).toList(),
          onConflict: 'strava_id,activity_id',
        );
      } catch (e) {
        print('[Supabase upload error]: $e');
      }
    }
  }

  Future<List<Activity>> fetchActivities(String stravaId) async {
    await init();
    try {
      final data = await client
          .from('activities')
          .select('data')
          .eq('strava_id', stravaId)
          .limit(3000); // Ensure all activities are fetched
      if (data == null || data is! List) return [];
      print('[SupabaseService] Fetched ${data.length} activities from Supabase');
      return data.map<Activity>((row) => Activity.fromJson(row['data'])).toList();
    } catch (e) {
      print('[Supabase fetch error]: $e');
      throw Exception('Supabase fetch error: $e');
    }
  }
} 