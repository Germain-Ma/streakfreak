class Activity {
  final Map<String, String> fields;
  Activity(this.fields);
 
  String? operator [](String key) => fields[key];
  String? get id => fields['Strava ID'];

  Map<String, dynamic> toJson() => fields;

  factory Activity.fromJson(Map<String, dynamic> json) => Activity(Map<String, String>.from(json));
} 