import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'run_provider.dart';

class LocationProvider extends ChangeNotifier {
  RunProvider? _runProvider;
  final Set<LatLng> _points = {};

  LocationProvider(this._runProvider) {
    // Removed print/debug statements for performance
  }

  void updateRunProvider(RunProvider? runProvider) {
    _runProvider = runProvider;
  }

  Set<LatLng> get points => _points;

  Future<void> refresh() async {
    _points.clear();
    if (_runProvider == null) {
      notifyListeners();
      return;
    }
    for (final run in _runProvider!.runs) {
      if ((run.lat != 0.0 || run.lon != 0.0)) {
        final point = LatLng(run.lat, run.lon);
        _points.add(point);
      }
    }
    notifyListeners();
  }
}
