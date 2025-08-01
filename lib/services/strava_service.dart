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
    // Use different redirect URIs for localhost vs web deployment
    if (kIsWeb && Uri.base.host == 'localhost') {
      return 'http://localhost:3000';
    }
    return redirectUri; // Use production redirect URI for deployed web app
  }

  Future<void> authenticate() async {
    final url = Uri.parse('$authUrl?client_id=$clientId&response_type=code&redirect_uri=${Uri.encodeComponent(_effectiveRedirectUri)}&approval_prompt=auto&scope=activity:read_all');
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
        'redirect_uri': _effectiveRedirectUri,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('strava_access_token', data['access_token']);
      await prefs.setString('strava_refresh_token', data['refresh_token']);
      await prefs.setInt('strava_token_expires_at', data['expires_at']);
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

  Future<String?> refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('strava_refresh_token');
    if (refreshToken == null) return null;

    final response = await http.post(
      Uri.parse(tokenUrl),
      body: {
        'client_id': clientId,
        'client_secret': clientSecret,
        'refresh_token': refreshToken,
        'grant_type': 'refresh_token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await prefs.setString('strava_access_token', data['access_token']);
      await prefs.setString('strava_refresh_token', data['refresh_token']);
      await prefs.setInt('strava_token_expires_at', data['expires_at']);
      return data['access_token'];
    }
    return null;
  }

  Future<String?> getValidAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('strava_access_token');
    final expiresAt = prefs.getInt('strava_token_expires_at');
    
    if (accessToken == null) return null;
    
    // Check if token is expired (with 5 minute buffer)
    if (expiresAt != null && DateTime.now().millisecondsSinceEpoch > (expiresAt * 1000) - 300000) {
      // Token is expired or will expire soon, try to refresh
      return await refreshToken();
    }
    
    return accessToken;
  }

  Future<String?> getAccessToken() async {
    return await getValidAccessToken();
  }

  Future<List<Map<String, dynamic>>> fetchActivities() async {
    final accessToken = await getValidAccessToken();
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
          allActivities.addAll(List<Map<String, dynamic>>.from(data));
          if (data.length < perPage) break; // Last page
          page++;
        } else {
          break; // No more data
        }
      } else if (response.statusCode == 401) {
        // Token expired, try to refresh
        final newToken = await refreshToken();
        if (newToken != null) {
          // Retry with new token
          continue;
        } else {
          break; // Could not refresh token
        }
      } else {
        break; // Other error, stop fetching
      }
    }
    return allActivities;
  }

  Future<String?> fetchAndStoreAthleteId() async {
    final accessToken = await getValidAccessToken();
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