import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/location_provider.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final points = context.watch<LocationProvider>().points;

    return FlutterMap(
      options: MapOptions(
        center: const LatLng(20, 0),   // global view
        zoom: 1.7,
        interactiveFlags: InteractiveFlag.drag | InteractiveFlag.pinchZoom,
      ),
      children: [
        // Monochrome tile layer (CartoDB Positron grayscale)
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/light_nolabels/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
        ),
        MarkerLayer(
          markers: points
              .map<Marker>((p) => Marker(
                    width: 1.32,
                    height: 1.32,
                    point: p,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black,
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}
