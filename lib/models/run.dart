class Run {
  final DateTime date;
  final double distanceKm;
  final double lat;
  final double lon;
  final String title;
  const Run({required this.date, required this.distanceKm, required this.lat, required this.lon, required this.title});

  factory Run.fromCsv(Map<String, String> row) {
    try {
      // Parse ISO8601 date (Strava uses UTC, e.g. '2023-07-08T10:00:00Z')
      final date = DateTime.parse(row['Date']!); // Always use UTC for streak logic
      final distanceKm = double.tryParse(row['Distance'] ?? '') ?? 0.0;
      final title = row['Title'] ?? '';
      final lat = double.tryParse(row['Start Latitude'] ?? '') ?? 0.0;
      final lon = double.tryParse(row['Start Longitude'] ?? '') ?? 0.0;
      return Run(date: date, distanceKm: distanceKm, lat: lat, lon: lon, title: title);
    } catch (e) {
      print('Failed to parse Run from row: $row, error: $e');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => {
        'd': date.toIso8601String(),
        'k': distanceKm,
        'la': lat,
        'lo': lon,
        't': title,
      };

  factory Run.fromJson(Map<String, dynamic> j) => Run(
        date: DateTime.parse(j['d']),
        distanceKm: (j['k'] as num).toDouble(),
        lat: (j['la'] as num).toDouble(),
        lon: (j['lo'] as num).toDouble(),
        title: j['t'] ?? '',
      );

  /// Location is now based on GPS coordinates, not title
  String get location {
    if (lat != 0.0 || lon != 0.0) {
      return ' 0{lat.toStringAsFixed(5)},${lon.toStringAsFixed(5)}';
    }
    return '';
  }
  
  /// Smart location extraction using multiple heuristics
  String _extractLocationSmart(String title) {
    // Common running keywords to filter out
    const runningKeywords = {
      'running', 'run', 'treadmill', 'base', 'recovery', 'tempo', 
      'anaerobic', 'threshold', 'sprint', 'long', 'easy', 'hard',
      'interval', 'fartlek', 'hill', 'trail', 'road', 'track'
    };
    
    // Common location indicators
    const locationIndicators = [' - ', ' in ', ' at ', ' near ', ' around '];
    
    // Strategy 1: Split by location indicators
    for (final indicator in locationIndicators) {
      final parts = title.split(indicator);
      if (parts.length > 1) {
        final potentialLocation = parts[0].trim();
        if (_isLikelyLocation(potentialLocation)) {
          return potentialLocation;
        }
      }
    }
    
    // Strategy 2: Look for patterns like "Location Running" or "Location - Type"
    final words = title.split(' ');
    if (words.length >= 2) {
      // Check if first word(s) look like a location
      final potentialLocation = words.take(words.length - 1).join(' ').trim();
      final lastWord = words.last.toLowerCase();
      
      if (runningKeywords.contains(lastWord) && _isLikelyLocation(potentialLocation)) {
        return potentialLocation;
      }
    }
    
    // Strategy 3: Remove common running keywords from the end
    final lowerTitle = title.toLowerCase();
    for (final keyword in runningKeywords) {
      if (lowerTitle.endsWith(' $keyword')) {
        final withoutKeyword = title.substring(0, title.length - keyword.length - 1).trim();
        if (_isLikelyLocation(withoutKeyword)) {
          return withoutKeyword;
        }
      }
    }
    
    // Strategy 4: Look for location patterns in the middle
    for (final keyword in runningKeywords) {
      final keywordIndex = lowerTitle.indexOf(' $keyword ');
      if (keywordIndex > 0) {
        final beforeKeyword = title.substring(0, keywordIndex).trim();
        if (_isLikelyLocation(beforeKeyword)) {
          return beforeKeyword;
        }
      }
    }
    
    return '';
  }
  
  /// Check if a string is likely to be a location name
  bool _isLikelyLocation(String text) {
    if (text.isEmpty || text.length < 2) return false;
    
    // Must contain at least one letter
    if (!text.contains(RegExp(r'[a-zA-Z]'))) return false;
    
    // Shouldn't be too long (most location names are reasonable length)
    if (text.length > 50) return false;
    
    // Shouldn't be just numbers or common non-location words
    const nonLocationWords = {
      'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
      'of', 'with', 'by', 'from', 'up', 'down', 'out', 'off', 'over', 'under'
    };
    
    final words = text.toLowerCase().split(' ');
    if (words.length == 1 && nonLocationWords.contains(words[0])) return false;
    
    // Should contain at least one word that looks like a location
    bool hasLocationWord = false;
    for (final word in words) {
      if (word.length >= 2 && !nonLocationWords.contains(word)) {
        hasLocationWord = true;
        break;
      }
    }
    
    return hasLocationWord;
  }
} 