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

    // Set bounds to the world
    final bounds = LatLngBounds(LatLng(-85, -180), LatLng(85, 180));

    return Container(
      color: const Color(0xFF181A20),
      child: FlutterMap(
      options: MapOptions(
          center: const LatLng(20, 0),
        zoom: 1.7,
          minZoom: 1.7,
          maxZoom: 18.0,
        interactiveFlags: InteractiveFlag.drag | InteractiveFlag.pinchZoom,
          bounds: bounds,
          maxBounds: bounds,
          boundsOptions: const FitBoundsOptions(padding: EdgeInsets.zero, maxZoom: 18.0),
      ),
      children: [
          // Dark tile layer (CartoDB Dark Matter)
        TileLayer(
            urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
            backgroundColor: const Color(0xFF181A20),
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
                          color: Colors.orange,
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
      ),
    );
  }
}
