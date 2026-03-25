import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/employee.dart';
 
class ApiService {
  // Change this to your Django server address
  // static const String BASE_URL = 'http://10.10.1.13:8000/api';
  // static const String BASE_URL = 'http://127.0.0.1:8000/api/';
  static const String BASE_URL = 'http://192.168.1.118:8000/api';
 
  // ── Fetch all employees from PostgreSQL ──
  static Future<List<Employee>> getEmployees() async {
    try {
      final res = await http.get(Uri.parse('$BASE_URL/employees/'));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((e) => Employee.fromJson(e)).toList();
      }
    } catch (e) {
      print('getEmployees error: $e');
    }
    return [];
  }
 
  // ── Upload one employee to PostgreSQL (with photo) ──
  static Future<bool> uploadEmployee(Employee emp) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$BASE_URL/employees/'),
      );
      // Text fields
      request.fields['name']      = emp.name;
      request.fields['dob']       = emp.dob;
      request.fields['doj']       = emp.doj;
      request.fields['ctc']       = emp.ctc.toString();
      request.fields['latitude']  = (emp.latitude ?? 0).toString();
      request.fields['longitude'] = (emp.longitude ?? 0).toString();
 
      // Attach photo if it exists
      if (emp.photoPath != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'photo', emp.photoPath!,
        ));
      }
 
      final response = await request.send();
      return response.statusCode == 201; // 201 = Created
    } catch (e) {
      print('uploadEmployee error: $e');
      return false;
    }
  }
}
