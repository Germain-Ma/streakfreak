import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GeocodingService {
  static const _cacheKey = 'placeCacheV1';

  Future<({double lat, double lon})?> lookup(String place) async {
    if (place.trim().isEmpty) return null;
    final query = place.trim();

    final prefs = await SharedPreferences.getInstance();
    final cache = prefs.getStringList(_cacheKey) ?? [];

    // cache format: "place|lat|lon"
    for (final entry in cache) {
      final parts = entry.split('|');
      if (parts.length == 3 && parts.first == place) {
        return (lat: double.parse(parts[1]), lon: double.parse(parts[2]));
      }
    }

    try {
      final locations = await locationFromAddress(query);
      if (locations.isEmpty) return null;
      final first = locations.first;
      cache.add('$place|${first.latitude}|${first.longitude}');
      await prefs.setStringList(_cacheKey, cache);
      return (lat: first.latitude, lon: first.longitude);
    } catch (_) {
      return null; // silently ignore
    }
  }
}
