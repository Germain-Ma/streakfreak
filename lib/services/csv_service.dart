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
    // print('First 100 bytes: ' + raw.codeUnits.take(100).toList().toString());
    if (raw.isNotEmpty && raw.codeUnitAt(0) == 0xFEFF) {
      print('BOM detected, removing...');
      raw = raw.substring(1);
    }
    // Normalize line endings
    raw = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    // print('First 500 chars of raw CSV:\n' + raw.substring(0, raw.length > 500 ? 500 : raw.length));

    // Use csv package for robust parsing
    final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false).convert(raw);
    print('csv rows length: \\${rows.length}');
    if (rows.isEmpty) return [];

    final headers = rows.first.cast<String>();
    print('Parsed headers: ' + headers.toString());
    if (rows.length > 1) print('First data row: ' + rows[1].toString());
    // Only print the first 3 and last 2 rows for debug
    int n = rows.length;
    for (int idx = 0; idx < n; idx++) {
      if (idx < 3 || idx >= n - 2) {
        print('Row $idx: ' + rows[idx].toString() + ' (${rows[idx].length} columns)');
      } else if (idx == 3) {
        print('...');
      }
    }
    final activities = rows
        .skip(1)
        .where((cells) => cells.length == headers.length)
        .map((cells) => Activity(Map.fromIterables(headers, cells.map((c) => c.toString()))))
        .toList(growable: false);
    print('Parsed activities: ' + activities.length.toString());
    return activities;
  }
} 