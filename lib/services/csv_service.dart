import 'package:csv/csv.dart';
import 'package:file_selector/file_selector.dart';
import '../models/activity.dart';

class CsvService {
  Future<List<Activity>> pickAndParseCsv() async {
    final file = await openFile(acceptedTypeGroups: [
      XTypeGroup(label: 'CSV', extensions: ['csv'])
    ]);
    if (file == null) return [];

    String raw = await file.readAsString();
    if (raw.isNotEmpty && raw.codeUnitAt(0) == 0xFEFF) {
      raw = raw.substring(1);
    }
    // Normalize line endings
    raw = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // Use csv package for robust parsing
    final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false).convert(raw);
    if (rows.isEmpty) return [];

    final headers = rows.first.cast<String>();
    final activities = rows
        .skip(1)
        .where((cells) => cells.length == headers.length)
        .map((cells) => Activity(Map.fromIterables(headers, cells.map((c) => c.toString()))))
        .toList(growable: false);
    return activities;
  }
} 