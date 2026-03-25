import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/employee.dart';
import 'api_service.dart';
 
class SyncService {
  // In-memory list of employees waiting to be synced
  static final List<Employee> _pendingQueue = [];
 
  // Add an employee to the pending queue
  static void addToPending(Employee emp) {
    _pendingQueue.add(emp);
    print('Added to sync queue. Queue size: ${_pendingQueue.length}');
  }
 
  // Get count of pending records
  static int get pendingCount => _pendingQueue.length;
 
  // Start listening for internet connectivity
  static void startListening() {
    Connectivity().onConnectivityChanged.listen((result) async {
      if (result != ConnectivityResult.none) {
        print('Internet connected! Starting sync...');
        await syncAll();
      }
    });
  }
 
  // Try to sync all pending employees
  static Future<void> syncAll() async {
    if (_pendingQueue.isEmpty) return;
 
    // Copy list so we can modify original while iterating
    final toSync = List<Employee>.from(_pendingQueue);
 
    for (final emp in toSync) {
      final success = await ApiService.uploadEmployee(emp);
      if (success) {
        _pendingQueue.remove(emp);
        print('Synced: ${emp.name}');
      } else {
        print('Sync failed for: ${emp.name}');
      }
    }
  }
}
