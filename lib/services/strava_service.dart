import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StravaService {
  static const String clientId = '167512'; // Replace with your Strava Client ID
  static const String clientSecret = '6780c73a79c2380e2d3acb315a94c62ad6876cd3'; // Updated to your real Strava Client Secret
  static const String redirectUri = 'https://germain-ma.github.io/streakfreak'; // No trailing slash
  static const String authUrl = 'https://www.strava.com/oauth/authorize';
  static const String tokenUrl = 'https://www.strava.com/oauth/token';
  static const String activitiesUrl = 'https://www.strava.com/api/v3/athlete/activities';
  static const String athleteUrl = 'https://www.strava.com/api/v3/athlete';

  Future<void> authenticate() async {
    final url = Uri.parse('$authUrl?client_id=$clientId&response_type=code&redirect_uri=$redirectUri&approval_prompt=auto&scope=activity:read_all');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<String?> exchangeCodeForToken(String code) async {
    final response = await http.post(
      Uri.parse(tokenUrl),
      body: {
        'client_id': clientId,
        'client_secret': clientSecret,
        'code': code,
        'grant_type': 'authorization_code',
        'redirect_uri': redirectUri,
      },
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('strava_access_token', data['access_token']);
      await prefs.setString('strava_refresh_token', data['refresh_token']);
      // Fetch and store athlete ID after successful token exchange
      await fetchAndStoreAthleteId();
      return data['access_token'];
    } else {
      try {
        final error = jsonDecode(response.body);
        return 'Error: ${error['message'] ?? response.body}';
      } catch (_) {
        return 'Error: ${response.body}';
      }
    }
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('strava_access_token');
  }

  Future<List<Map<String, dynamic>>> fetchActivities({Set<String>? knownIds}) async {
    final accessToken = await getAccessToken();
    if (accessToken == null) return [];
    List<Map<String, dynamic>> allActivities = [];
    int page = 1;
    const int perPage = 200;
    while (true) {
      final url = '$activitiesUrl?per_page=$perPage&page=$page';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          final pageActivities = List<Map<String, dynamic>>.from(data);
          allActivities.addAll(pageActivities);
          // If all activity IDs on this page are already known, stop immediately (even after first page)
          if (knownIds != null && pageActivities.every((a) => knownIds.contains((a['id'] ?? '').toString()))) {
            break;
          }
          if (data.length < perPage) break; // Last page
          page++;
        } else {
          break; // No more data
        }
      } else {
        // ignore: avoid_print
        print('[StravaService] Activities fetch error: ${response.statusCode} ${response.body}');
        break; // Error, stop fetching
      }
      // Only fetch the first page unless new activities are found
      if (page == 2 && (knownIds == null || allActivities.every((a) => knownIds.contains((a['id'] ?? '').toString())))) {
        break;
      }
    }
    return allActivities;
  }

  Future<String?> fetchAndStoreAthleteId() async {
    final accessToken = await getAccessToken();
    if (accessToken == null) return null;
    final response = await http.get(
      Uri.parse(athleteUrl),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final athleteId = data['id']?.toString();
      if (athleteId != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('strava_athlete_id', athleteId);
        return athleteId;
      }
    }
    return null;
  }

  Future<String?> getAthleteId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('strava_athlete_id');
  }
} 