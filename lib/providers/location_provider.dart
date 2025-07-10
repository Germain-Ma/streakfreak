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
    if (_runProvider == null) {
      print('No RunProvider set in LocationProvider');
      notifyListeners();
      return;
    }

    print('Processing ${_runProvider!.runs.length} runs for GPS extraction...');
    int withGps = 0;
    int withoutGps = 0;

    for (final run in _runProvider!.runs) {
      if ((run.lat != 0.0 || run.lon != 0.0)) {
        withGps++;
        final point = LatLng(run.lat, run.lon);
        _points.add(point);
      } else {
        withoutGps++;
      }
    }

    print('GPS summary:');
    print('  - Runs with GPS: $withGps');
    print('  - Runs without GPS: $withoutGps');
    print('  - Unique map points added: ${_points.length}');

    notifyListeners();
  }
}
