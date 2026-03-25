import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/employee.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import 'employee_form_screen.dart';
import 'payslip_screen.dart';
import 'map_screen.dart';   // ← ADD THIS LINE

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
    } catch (_) { return dateStr; }
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employees'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          // Show how many records are waiting to sync
          if (SyncService.pendingCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                label: Text('${SyncService.pendingCount} pending',
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
                backgroundColor: Colors.orange,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEmployees,
          ),
        ],
      ),
      // ── Floating Add Button ──
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () async {
          // Go to form screen; reload list when back
          await Navigator.push(context, MaterialPageRoute(
            builder: (_) => const EmployeeFormScreen(),
          ));
          _loadEmployees();
        },
      ),
      // ── Body ──
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _employees.isEmpty
          ? const Center(child: Text('No employees yet. Tap + to add.'))
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(Colors.indigo.shade50),
                  columns: const [
                    DataColumn(label: Text('Name',    style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('DOB',     style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('DOJ',     style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('DOR',     style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('CTC',     style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Photo',   style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Payslip', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Map',     style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: _employees.map((emp) => DataRow(cells: [
                  DataCell(Text(emp.name)),
                  DataCell(Text(_fmt(emp.dob))),
                  DataCell(Text(_fmt(emp.doj))),
                  DataCell(Text(emp.dor)),
                  DataCell(Text('₹${emp.ctc.toStringAsFixed(0)}')),

                  // Photo
                  DataCell(IconButton(
                    icon: const Icon(Icons.photo, color: Colors.indigo),
                    onPressed: () {
                      if (emp.photoPath != null) {
                        showDialog(context: context, builder: (_) => AlertDialog(
                          content: Image.network(emp.photoPath!),
                        ));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No photo available')));
                      }
                    },
                  )),

                  // Payslip
                  DataCell(IconButton(
                    icon: const Icon(Icons.receipt, color: Colors.green),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PayslipScreen(employee: emp),
                      ),
                    ),
                  )),

                  // ✅ ADD MAP CELL HERE (LAST)
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.map, color: Colors.teal),
                      tooltip: 'Show on Map',
                      onPressed: () {
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
                      },
                    ),
                  ),

                ])).toList(),
                ),
              ),
            ),
    );
  }
}
