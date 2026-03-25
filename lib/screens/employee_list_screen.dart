import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/employee.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import 'employee_form_screen.dart';
import 'payslip_screen.dart';
import 'map_screen.dart';
import 'all_employees_map_screen.dart'; // ← NEW

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  List<Employee> _employees = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => _loading = true);
    final list = await ApiService.getEmployees();
    setState(() {
      _employees = list;
      _loading = false;
    });
  }

  String _fmt(String dateStr) {
    try {
      return DateFormat('dd-MM-yyyy').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }

  void _openMap(Employee emp) {
    if (emp.latitude == null || emp.longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No location data for this employee.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapScreen(
          employeeName: emp.name,
          destLat: emp.latitude!,
          destLng: emp.longitude!,
        ),
      ),
    );
  }

  Future<void> _openGoogleMapsDirectly(Employee emp) async {
    if (emp.latitude == null || emp.longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No location data for this employee.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final url = 'https://www.google.com/maps/dir/?api=1'
        '&destination=${emp.latitude},${emp.longitude}'
        '&travelmode=driving';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open Google Maps.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employees'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          // Pending sync badge
          if (SyncService.pendingCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Chip(
                label: Text(
                  '${SyncService.pendingCount} pending',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                backgroundColor: Colors.orange,
              ),
            ),

          // ── ALL EMPLOYEES MAP BUTTON in navbar ──
          IconButton(
            icon: const Icon(Icons.map),
            tooltip: 'View all on map',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AllEmployeesMapScreen(),
                ),
              );
            },
          ),

          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEmployees,
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EmployeeFormScreen()),
          );
          _loadEmployees();
        },
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _employees.isEmpty
              ? const Center(child: Text('No employees yet. Tap + to add.'))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(
                          Colors.indigo.shade50),
                      columns: const [
                        DataColumn(
                            label: Text('Name',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('DOB',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('DOJ',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('DOR',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('CTC',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('Photo',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('Payslip',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('Map',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('Google Maps',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold))),
                      ],
                      rows: _employees
                          .map((emp) => DataRow(cells: [
                                DataCell(Text(emp.name)),
                                DataCell(Text(_fmt(emp.dob))),
                                DataCell(Text(_fmt(emp.doj))),
                                DataCell(Text(emp.dor)),
                                DataCell(Text(
                                    '₹${emp.ctc.toStringAsFixed(0)}')),

                                // Photo
                                DataCell(IconButton(
                                  icon: const Icon(Icons.photo,
                                      color: Colors.indigo),
                                  onPressed: () {
                                    if (emp.photoPath != null) {
                                      showDialog(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          content: Image.network(
                                              emp.photoPath!),
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'No photo available')));
                                    }
                                  },
                                )),

                                // Payslip
                                DataCell(IconButton(
                                  icon: const Icon(Icons.receipt,
                                      color: Colors.green),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            PayslipScreen(employee: emp)),
                                  ),
                                )),

                                // OpenStreetMap per-employee
                                DataCell(IconButton(
                                  icon: const Icon(Icons.map,
                                      color: Colors.teal),
                                  tooltip: 'View on map',
                                  onPressed: () => _openMap(emp),
                                )),

                                // Google Maps per-employee
                                DataCell(IconButton(
                                  icon: const Icon(Icons.navigation,
                                      color: Colors.blue),
                                  tooltip: 'Navigate in Google Maps',
                                  onPressed: () =>
                                      _openGoogleMapsDirectly(emp),
                                )),
                              ]))
                          .toList(),
                    ),
                  ),
                ),
    );
  }
}