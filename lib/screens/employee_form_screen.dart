import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
import '../models/employee.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
 
class EmployeeFormScreen extends StatefulWidget {
  const EmployeeFormScreen({super.key});
 
  @override
  State<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}
 
class _EmployeeFormScreenState extends State<EmployeeFormScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtr   = TextEditingController();
  final _ctcCtr    = TextEditingController();
 
  DateTime? _dob;
  DateTime? _doj;
  File?     _photo;
  double?   _lat;
  double?   _lng;
  bool      _saving = false;
 
  // ── Pick Date ──
  Future<void> _pickDate(bool isDob) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() { isDob ? _dob = picked : _doj = picked; });
    }
  }
 
  // ── Take Photo + Get Location ──
  Future<void> _takePhoto() async {
    // 1. Request location permission
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
 
    // 2. Get GPS coordinates
    try {
      final pos = await Geolocator.getCurrentPosition()
        .timeout(const Duration(seconds: 10));
      _lat = pos.latitude;
      _lng = pos.longitude;
    } catch (e) {
      print('Location error: $e');
    }
 
    // 3. Open camera
    final picker = ImagePicker();
    final img = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,  // compress to save space
    );
    if (img != null) {
      setState(() => _photo = File(img.path));
    }
  }
 
  // ── Save Employee ──
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dob == null || _doj == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select DOB and DOJ')));
      return;
    }
 
    setState(() => _saving = true);
 
    final fmt = DateFormat('yyyy-MM-dd');
    final employee = Employee(
      name     : _nameCtr.text.trim(),
      dob      : fmt.format(_dob!),
      doj      : fmt.format(_doj!),
      ctc      : double.parse(_ctcCtr.text.trim()),
      photoPath: _photo?.path,
      latitude : _lat,
      longitude: _lng,
    );
 
    // Check internet
    final conn = await Connectivity().checkConnectivity();
    final isOnline = conn != ConnectivityResult.none;
 
    if (isOnline) {
      final ok = await ApiService.uploadEmployee(employee);
      if (ok) {
        _showMsg('Saved to database!', Colors.green);
      } else {
        // Upload failed — add to queue for later
        SyncService.addToPending(employee);
        _showMsg('Upload failed. Will sync later.', Colors.orange);
      }
    } else {
      // No internet — add to queue
      SyncService.addToPending(employee);
      _showMsg('Offline. Will sync when internet available.', Colors.orange);
    }
 
    setState(() => _saving = false);
    if (mounted) Navigator.pop(context);
  }
 
  void _showMsg(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color));
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Employee'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
 
              // ── Name ──
              TextFormField(
                controller: _nameCtr,
                decoration: const InputDecoration(
                  labelText: 'Employee Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
 
              // ── DOB ──
              ListTile(
                tileColor: Colors.grey.shade100,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade400),
                ),
                leading: const Icon(Icons.cake, color: Colors.indigo),
                title: Text(_dob == null
                  ? 'Select Date of Birth'
                  : 'DOB: ${DateFormat('dd-MM-yyyy').format(_dob!)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _pickDate(true),
              ),
              const SizedBox(height: 16),
 
              // ── DOJ ──
              ListTile(
                tileColor: Colors.grey.shade100,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade400),
                ),
                leading: const Icon(Icons.work, color: Colors.indigo),
                title: Text(_doj == null
                  ? 'Select Date of Joining'
                  : 'DOJ: ${DateFormat('dd-MM-yyyy').format(_doj!)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _pickDate(false),
              ),
              const SizedBox(height: 16),
 
              // ── CTC ──
              TextFormField(
                controller: _ctcCtr,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'CTC (Annual)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (double.tryParse(v) == null) return 'Enter valid number';
                  return null;
                },
              ),
              const SizedBox(height: 20),
 
              // ── Take Photo Button ──
              Row(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                    onPressed: _takePhoto,
                  ),
                  const SizedBox(width: 12),
                  if (_photo != null)
                    const Icon(Icons.check_circle, color: Colors.green, size: 28),
                  if (_lat != null)
                    Flexible(child: Text(
                      'GPS: ${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    )),
                ],
              ),
 
              // Show photo preview
              if (_photo != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(_photo!, height: 150, fit: BoxFit.cover),
                ),
              ],
 
              const SizedBox(height: 28),
 
              // ── Save Button ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('SAVE EMPLOYEE', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
