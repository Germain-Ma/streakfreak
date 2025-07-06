import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/geocoding_service.dart';
import '../services/web_geocoding_service.dart';
import 'run_provider.dart';

class LocationProvider extends ChangeNotifier {
  final GeocodingService _geo = GeocodingService();
  final WebGeocodingService _webGeo = WebGeocodingService();
  RunProvider? _runProvider;
  final Set<LatLng> _points = {};

  LocationProvider(this._runProvider);

  void updateRunProvider(RunProvider? runProvider) {
    _runProvider = runProvider;
  }

  Set<LatLng> get points => _points;

  Future<void> refresh() async {
    print('LocationProvider.refresh() called');
    _points.clear();
    final uniquePlaces = <String>{};
    if (_runProvider == null) {
      print('No RunProvider set in LocationProvider');
      notifyListeners();
      return;
    }
    
    print('Processing ${_runProvider!.runs.length} runs for location extraction...');
    int extractedCount = 0;
    int geocodedCount = 0;
    
    for (final run in _runProvider!.runs) {
      final place = run.location;
      if (place.isNotEmpty) {
        extractedCount++;
        print('✓ Extracted location: "$place" from title: "${run.title}"');
        
        if (uniquePlaces.add(place)) {
          print('  → New unique location, geocoding...');
          final coords = kIsWeb
              ? await _webGeo.lookup(place)
              : await _geo.lookup(place);
          if (coords != null) {
            geocodedCount++;
            _points.add(LatLng(coords.lat, coords.lon));
            print('  ✓ Geocoded successfully: $coords');
          } else {
            print('  ✗ Geocoding failed for "$place"');
          }
        } else {
          print('  → Duplicate location, skipping geocoding');
        }
      } else {
        print('✗ No location extracted from: "${run.title}"');
      }
    }
    
    print('Location extraction summary:');
    print('  - Total runs processed: ${_runProvider!.runs.length}');
    print('  - Locations extracted: $extractedCount');
    print('  - Unique locations: ${uniquePlaces.length}');
    print('  - Successfully geocoded: $geocodedCount');
    print('  - Map points added: ${_points.length}');
    
    notifyListeners();
  }
}
