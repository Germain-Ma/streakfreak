import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'run_provider.dart';

class LocationProvider with ChangeNotifier {
  List<LatLng> _points = [];
  RunProvider? _runProvider;

  LocationProvider(this._runProvider);

  List<LatLng> get points => _points;

  void updateRunProvider(RunProvider runProvider) {
    _runProvider = runProvider;
  }

  Future<void> refresh() async {
    if (_runProvider == null) {
      return;
    }

    final runs = _runProvider!.runs;
    final points = <LatLng>[];
    int withGps = 0;
    int withoutGps = 0;

    for (final run in runs) {
      if (run.lat != 0.0 || run.lon != 0.0) {
        points.add(LatLng(run.lat, run.lon));
        withGps++;
      } else {
        withoutGps++;
      }
    }

    _points = points;
    notifyListeners();
  }
}
