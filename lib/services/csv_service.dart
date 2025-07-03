import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import '../models/activity.dart';

class CsvService {
  Future<List<Activity>> pickAndParseCsv() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null || result.files.single.path == null) return [];
    final filePath = result.files.single.path!;
    final content = await File(filePath).readAsString();
    final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false).convert(content, eol: '\n');
    if (rows.isEmpty) return [];
    final header = rows.first.cast<String>();
    final dataRows = rows.skip(1);
    final activities = <Activity>[];
    for (final row in dataRows) {
      final map = <String, String>{};
      for (int i = 0; i < header.length && i < row.length; i++) {
        map[header[i]] = row[i].toString();
      }
      activities.add(Activity(map));
    }
    return activities;
  }
} 