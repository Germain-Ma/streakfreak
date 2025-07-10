class Activity {
  final Map<String, String> fields;
  Activity(this.fields);
 
  String? operator [](String key) => fields[key];
} 