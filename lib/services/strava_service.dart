import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class StravaService {
  static const String clientId = '167512'; // Replace with your Strava Client ID
  static const String clientSecret = '6780c73a79c2380e2d3acb315a94c62ad6876cd3'; // Updated to your real Strava Client Secret
  static const String redirectUri = 'https://germain-ma.github.io/streakfreak'; // No trailing slash
  static const String authUrl = 'https://www.strava.com/oauth/authorize';
  static const String tokenUrl = 'https://www.strava.com/oauth/token';
  static const String activitiesUrl = 'https://www.strava.com/api/v3/athlete/activities';
  static const String athleteUrl = 'https://www.strava.com/api/v3/athlete';

  String get _effectiveRedirectUri {
    // For localhost development, use the same redirect URI as production
    // This allows the OAuth flow to work in the browser without needing a local server
    return redirectUri; // Always use production redirect URI
  }

  Future<void> authenticate() async {
    final url = Uri.parse('$authUrl?client_id=$clientId&response_type=code&redirect_uri=${Uri.encodeComponent(_effectiveRedirectUri)}&approval_prompt=auto&scope=activity:read_all');
    print('[StravaService] Authenticating with URL: $url');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<String?> exchangeCodeForToken(String code) async {
    print('[StravaService] Exchanging code for token with code: $code');
    print('[StravaService] Using redirect URI: $_effectiveRedirectUri');
    final response = await http.post(
      Uri.parse(tokenUrl),
      body: {
        'client_id': clientId,
        'client_secret': clientSecret,
        'code': code,
        'grant_type': 'authorization_code',
        'redirect_uri': _effectiveRedirectUri,
      },
    );
    print('[StravaService] Token exchange response status: ${response.statusCode}');
    print('[StravaService] Token exchange response body: ${response.body}');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('strava_access_token', data['access_token']);
      await prefs.setString('strava_refresh_token', data['refresh_token']);
      // Fetch and store athlete ID after successful token exchange
      await fetchAndStoreAthleteId();
      return data['access_token'];
    } else {
      print('Strava token exchange failed: ${response.statusCode}');
      print('Response body: ${response.body}');
      // Optionally, return the error message for UI display
      try {
        final error = jsonDecode(response.body);
        return 'Error: ${error['message'] ?? response.body}';
      } catch (_) {
        return 'Error: ${response.body}';
      }
    }
  }

  Future<String?> getAccessToken() async {
    print('[StravaService] getAccessToken called');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('strava_access_token');
    print('[StravaService] getAccessToken returned: ${token != null ? (token.length > 10 ? "${token.substring(0, 10)}..." : token) : "null"}');
    return token;
  }

  Future<List<Map<String, dynamic>>> fetchActivities({DateTime? after}) async {
    final accessToken = await getAccessToken();
    print('[StravaService] Fetching activities with accessToken: $accessToken');
    if (accessToken == null) return [];
    List<Map<String, dynamic>> allActivities = [];
    int page = 1;
    const int perPage = 200;
    int? afterTimestamp = after != null ? (after.millisecondsSinceEpoch ~/ 1000) : null;
    while (true) {
      String url = '$activitiesUrl?per_page=$perPage&page=$page';
      if (afterTimestamp != null) {
        url += '&after=$afterTimestamp';
      }
      print('[StravaService] Fetching activities from: $url');
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      print('[StravaService] Activities fetch response status: ${response.statusCode}');
      print('[StravaService] Activities fetch response body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          allActivities.addAll(List<Map<String, dynamic>>.from(data));
          if (data.length < perPage) break; // Last page
          page++;
        } else {
          break; // No more data
        }
      } else {
        break; // Error, stop fetching
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