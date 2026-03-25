class Employee {
  final int?   id;        // auto from DB
  final String name;
  final String dob;       // stored as 'YYYY-MM-DD'
  final String doj;       // stored as 'YYYY-MM-DD'
  final double ctc;
  final String? photoPath; // local path on device
  final double? latitude;
  final double? longitude;
  final bool   isSynced;  // false = not yet sent to server
 
  Employee({
    this.id,
    required this.name,
    required this.dob,
    required this.doj,
    required this.ctc,
    this.photoPath,
    this.latitude,
    this.longitude,
    this.isSynced = false,
  });
 
  // Convert Employee object → Map (to send as JSON to API)
  Map<String, dynamic> toJson() {
    return {
      'name'     : name,
      'dob'      : dob,
      'doj'      : doj,
      'ctc'      : ctc,
      'latitude' : latitude,
      'longitude': longitude,
    };
  }
 
  // Convert API JSON response → Employee object
  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id       : json['id'],
      name     : json['name'],
      dob      : json['dob'],
      doj      : json['doj'],
      ctc      : double.parse(json['ctc'].toString()),
      latitude : json['latitude'] != null
                   ? double.parse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null
                   ? double.parse(json['longitude'].toString()) : null,
      isSynced : true,
    );
  }
 
  // Calculate Date of Retirement (DOB + 60 years) — never stored
  String get dor {
    final d = DateTime.parse(dob);
    return '${d.day.toString().padLeft(2,'0')}-${d.month.toString().padLeft(2,'0')}-${d.year + 60}';
  }
}
