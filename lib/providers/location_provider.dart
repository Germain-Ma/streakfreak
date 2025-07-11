import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'run_provider.dart';

class LocationProvider extends ChangeNotifier {
  RunProvider? _runProvider;
  final Set<LatLng> _points = {};

  LocationProvider(this._runProvider) {
    print('[LocationProvider] constructor called, _runProvider: $_runProvider');
  }

  void updateRunProvider(RunProvider? runProvider) {
    _runProvider = runProvider;
  }

  Set<LatLng> get points => _points;

  Future<void> refresh() async {
    print('[LocationProvider.refresh] called, _runProvider: $_runProvider');
    _points.clear();
    if (_runProvider == null) {
      print('[LocationProvider.refresh] _runProvider is null!');
      notifyListeners();
      return;
    }

    print('[LocationProvider.refresh] Starting GPS extraction...');
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
    print('[LocationProvider.refresh] GPS extraction done. With GPS: $withGps, Without GPS: $withoutGps, Unique points: ${_points.length}');

    print('[LocationProvider.refresh] Notifying listeners...');
    notifyListeners();
    print('[LocationProvider.refresh] Done.');
  }
}
