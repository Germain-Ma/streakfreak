class Run {
  final DateTime date;
  final double distanceKm;
  final double lat;
  final double lon;
  const Run({required this.date, required this.distanceKm, required this.lat, required this.lon});

  factory Run.fromCsv(Map<String, String> row) {
    final date = DateTime.parse(row['Date']!.split(' ').first);
    final distanceKm = double.tryParse(row['Distance'] ?? '') ?? 0.0;
    return Run(date: date, distanceKm: distanceKm, lat: 0, lon: 0);
  }

  Map<String, dynamic> toJson() => {
        'd': date.toIso8601String(),
        'k': distanceKm,
        'la': lat,
        'lo': lon,
      };

  factory Run.fromJson(Map<String, dynamic> j) => Run(
        date: DateTime.parse(j['d']),
        distanceKm: (j['k'] as num).toDouble(),
        lat: (j['la'] as num).toDouble(),
        lon: (j['lo'] as num).toDouble(),
      );
} 