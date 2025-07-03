class Run {
  final DateTime date;
  final double distanceKm;
  final double lat;
  final double lon;
  const Run({required this.date, required this.distanceKm, required this.lat, required this.lon});

  Run.fromCsv(Map<String, String> row)
      : this(
          date: DateTime.parse(row['Activity Date']!.split(' ').first),
          distanceKm: double.parse(row['Distance']!) / 1000,
          lat: double.tryParse(row['Start Latitude'] ?? '') ?? 0,
          lon: double.tryParse(row['Start Longitude'] ?? '') ?? 0,
        );

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