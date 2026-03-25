import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/employee.dart';
import '../services/api_service.dart';

class AllEmployeesMapScreen extends StatefulWidget {
  const AllEmployeesMapScreen({super.key});

  @override
  State<AllEmployeesMapScreen> createState() => _AllEmployeesMapScreenState();
}

class _AllEmployeesMapScreenState extends State<AllEmployeesMapScreen> {
  GoogleMapController? _mapController;
  List<Employee> _employees = [];
  Set<Marker> _markers = {};
  bool _loading = true;
  LatLng? _myLocation;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    // 1. Get current location
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 15));
      _myLocation = LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      // location failed — map still shows employee points
    }

    // 2. Fetch employees from API
    final list = await ApiService.getEmployees();

    // 3. Only employees who have lat/lng stored
    _employees = list.where((e) =>
      e.latitude != null && e.longitude != null
    ).toList();

    // 4. Build markers
    await _buildMarkers();

    setState(() => _loading = false);
  }

  Future<void> _buildMarkers() async {
    final Set<Marker> markers = {};

    for (final emp in _employees) {
      // DOJ year decides colour
      // RED   = joined after  2000 (year > 2000)
      // GREEN = joined before 2000 (year <= 2000)
      final dojYear = DateTime.parse(emp.doj).year;
      final isAfter2000 = dojYear > 2000;

      final BitmapDescriptor icon = isAfter2000
          ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)
          : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);

      final marker = Marker(
        markerId: MarkerId(emp.id.toString()),
        position: LatLng(emp.latitude!, emp.longitude!),
        icon: icon,
        // When marker is tapped → show modal popup
        onTap: () => _showEmployeeModal(emp),
      );

      markers.add(marker);
    }

    setState(() => _markers = markers);
  }

  // ── Modal popup when a marker is tapped ──
  void _showEmployeeModal(Employee emp) {
    final fmt = DateFormat('dd MMM yyyy');
    final dob = fmt.format(DateTime.parse(emp.dob));
    final doj = fmt.format(DateTime.parse(emp.doj));
    final dojYear = DateTime.parse(emp.doj).year;
    final isAfter2000 = dojYear > 2000;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Header row: name + colour badge ──
            Row(
              children: [
                Expanded(
                  child: Text(
                    emp.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isAfter2000 ? Colors.red : Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isAfter2000 ? 'Joined after 2000' : 'Joined before 2000',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // ── DOB ──
            Row(children: [
              const Icon(Icons.cake, color: Colors.indigo, size: 20),
              const SizedBox(width: 8),
              Text('Date of Birth: ',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              Text(dob, style: const TextStyle(fontSize: 15)),
            ]),

            const SizedBox(height: 10),

            // ── DOJ ──
            Row(children: [
              const Icon(Icons.work, color: Colors.indigo, size: 20),
              const SizedBox(width: 8),
              Text('Date of Joining: ',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              Text(doj, style: const TextStyle(fontSize: 15)),
            ]),

            const SizedBox(height: 10),

            // ── Coordinates ──
            Row(children: [
              const Icon(Icons.location_on, color: Colors.grey, size: 20),
              const SizedBox(width: 8),
              Text(
                '${emp.latitude!.toStringAsFixed(5)}, '
                '${emp.longitude!.toStringAsFixed(5)}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ]),

            const SizedBox(height: 20),

            // ── Google Maps navigate button ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.navigation),
                label: const Text(
                  'Navigate in Google Maps',
                  style: TextStyle(fontSize: 15),
                ),
                onPressed: () => _openGoogleMaps(emp),
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Open Google Maps with turn-by-turn navigation ──
  Future<void> _openGoogleMaps(Employee emp) async {
    String url;

    if (_myLocation != null) {
      // With origin (your location) → destination (employee location)
      url = 'https://www.google.com/maps/dir/?api=1'
          '&origin=${_myLocation!.latitude},${_myLocation!.longitude}'
          '&destination=${emp.latitude},${emp.longitude}'
          '&travelmode=driving';
    } else {
      // No origin — just open destination
      url = 'https://www.google.com/maps/dir/?api=1'
          '&destination=${emp.latitude},${emp.longitude}'
          '&travelmode=driving';
    }

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

  // ── Camera bounds: fit all markers on screen ──
  void _fitAllMarkers() {
    if (_employees.isEmpty || _mapController == null) return;

    double minLat = _employees.first.latitude!;
    double maxLat = _employees.first.latitude!;
    double minLng = _employees.first.longitude!;
    double maxLng = _employees.first.longitude!;

    for (final emp in _employees) {
      if (emp.latitude! < minLat) minLat = emp.latitude!;
      if (emp.latitude! > maxLat) maxLat = emp.latitude!;
      if (emp.longitude! < minLng) minLng = emp.longitude!;
      if (emp.longitude! > maxLng) maxLng = emp.longitude!;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.05, minLng - 0.05),
          northeast: LatLng(maxLat + 0.05, maxLng + 0.05),
        ),
        80, // padding in pixels
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Employee Locations'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          // Fit all markers button
          IconButton(
            icon: const Icon(Icons.zoom_out_map),
            tooltip: 'Fit all markers',
            onPressed: _fitAllMarkers,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
            onPressed: _loadData,
          ),
        ],
      ),

      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading employee locations...'),
                ],
              ),
            )
          : Stack(
              children: [
                // ── Google Map ──
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    // Start at your location if available, else India center
                    target: _myLocation ?? const LatLng(20.5937, 78.9629),
                    zoom: _myLocation != null ? 12 : 5,
                  ),
                  markers: _markers,
                  myLocationEnabled: true,      // blue dot for your location
                  myLocationButtonEnabled: true, // button to go back to your location
                  zoomControlsEnabled: true,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    // Auto-fit all markers when map is ready
                    Future.delayed(
                      const Duration(milliseconds: 500),
                      _fitAllMarkers,
                    );
                  },
                ),

                // ── Legend at top-left ──
                Positioned(
                  top: 12,
                  left: 12,
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Legend',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 6),
                          Row(children: [
                            const Icon(Icons.location_pin,
                                color: Colors.red, size: 18),
                            const SizedBox(width: 4),
                            const Text('Joined after 2000',
                                style: TextStyle(fontSize: 11)),
                          ]),
                          const SizedBox(height: 4),
                          Row(children: [
                            const Icon(Icons.location_pin,
                                color: Colors.green, size: 18),
                            const SizedBox(width: 4),
                            const Text('Joined before 2000',
                                style: TextStyle(fontSize: 11)),
                          ]),
                          const SizedBox(height: 6),
                          Text(
                            '${_employees.length} employees',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}