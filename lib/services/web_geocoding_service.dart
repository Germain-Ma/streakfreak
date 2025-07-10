import 'dart:convert';
import 'package:http/http.dart' as http;

class WebGeocodingService {
  Future<({double lat, double lon})?> lookup(String place) async {
    if (place.trim().isEmpty) return null;
    final query = place.trim();
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1'
    );
    final response = await http.get(url, headers: {
      'User-Agent': 'streakfreak-app/1.0 (your@email.com)'
    });
    if (response.statusCode == 200) {
      final results = jsonDecode(response.body);
      if (results is List && results.isNotEmpty) {
        final first = results[0];
        return (
          lat: double.parse(first['lat']),
          lon: double.parse(first['lon']),
        );
      }
    }
    return null;
  }

  Future<String?> countryFromLatLon(double lat, double lon) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&zoom=3&addressdetails=1'
    );
    final response = await http.get(url, headers: {
      'User-Agent': 'streakfreak-app/1.0 (your@email.com)'
    });
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map && data['address'] != null && data['address']['country'] != null) {
        return data['address']['country'] as String;
      }
    }
    return null;
  }
} 