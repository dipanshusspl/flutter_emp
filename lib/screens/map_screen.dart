import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
 
class MapScreen extends StatefulWidget {
  final String employeeName;
  final double destLat;   // lat where photo was taken
  final double destLng;   // lng where photo was taken
 
  const MapScreen({
    super.key,
    required this.employeeName,
    required this.destLat,
    required this.destLng,
  });
 
  @override
  State<MapScreen> createState() => _MapScreenState();
}
 
class _MapScreenState extends State<MapScreen> {
  LatLng? _myLocation;          // your current GPS position
  List<LatLng> _routePoints = []; // polyline coordinates for route
  double? _distanceKm;
  int?    _durationMin;
  bool    _loading = true;
  String? _error;
 
  // Map controller to move camera
  final MapController _mapController = MapController();
 
  @override
  void initState() {
    super.initState();
    _init();
  }
 
  Future<void> _init() async {
    setState(() { _loading = true; _error = null; });
 
    // 1. Get current location
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        setState(() {
          _error = 'Location permission denied. Enable it in phone settings.';
          _loading = false;
        });
        return;
      }
 
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 15));
 
      _myLocation = LatLng(pos.latitude, pos.longitude);
    } catch (e) {
      setState(() {
        _error = 'Could not get your location. Make sure GPS is ON.';
        _loading = false;
      });
      return;
    }
 
    // 2. Fetch route from OSRM (free routing engine)
    await _fetchRoute();
 
    setState(() => _loading = false);
  }
 
  // ── OSRM: Free routing, no API key needed ──
  Future<void> _fetchRoute() async {
    if (_myLocation == null) return;
 
    final origin = _myLocation!;
    final dest   = LatLng(widget.destLat, widget.destLng);
 
    // OSRM public API endpoint
    // Format: /route/v1/driving/LNG,LAT;LNG,LAT
    final url = 'http://router.project-osrm.org/route/v1/driving/${origin.longitude},${origin.latitude};${dest.longitude},${dest.latitude}?overview=full&geometries=geojson';
 
    try {
      final res  = await http.get(Uri.parse(url))
        .timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
 
      if (data['code'] == 'Ok') {
        final route    = data['routes'][0];
        final coords   = route['geometry']['coordinates'] as List;
        final distance = route['distance'] as num; // meters
        final duration = route['duration'] as num; // seconds
 
        // coords is [lng, lat] pairs — convert to LatLng
        _routePoints = coords.map<LatLng>((c) {
          return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
        }).toList();
 
        _distanceKm  = distance / 1000;
        _durationMin = (duration / 60).round();
      } else {
        // OSRM returned error — just show straight line
        _routePoints = [origin, dest];
      }
    } catch (e) {
      // No internet or OSRM unreachable — show straight line
      _routePoints = [_myLocation!, LatLng(widget.destLat, widget.destLng)];
    }
  }
 
  // Calculate the center point between two locations for camera
  LatLng _centerPoint() {
    if (_myLocation == null) return LatLng(widget.destLat, widget.destLng);
    return LatLng(
      (_myLocation!.latitude  + widget.destLat) / 2,
      (_myLocation!.longitude + widget.destLng) / 2,
    );
  }
 
  // Calculate zoom level so both markers fit on screen
  double _calcZoom() {
    if (_myLocation == null) return 13;
    final latDiff = (_myLocation!.latitude  - widget.destLat).abs();
    final lngDiff = (_myLocation!.longitude - widget.destLng).abs();
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
    if (maxDiff < 0.01)  return 14;
    if (maxDiff < 0.05)  return 12;
    if (maxDiff < 0.2)   return 10;
    if (maxDiff < 1.0)   return 8;
    return 6;
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Map — ${widget.employeeName}'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          // Refresh button to reload route
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _init,
            tooltip: 'Reload',
          )
        ],
      ),
 
      body: _loading
        // ── Loading spinner ──
        ? const Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Getting your location & route...'),
            ]),
          )
 
        // ── Error message ──
        : _error != null
          ? Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.location_off, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: _init, child: const Text('Try Again')),
              ]),
            ))
 
        // ── Map ──
        : Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _centerPoint(),
                  initialZoom: _calcZoom(),
                ),
                children: [
 
                  // 1. Map tiles (OpenStreetMap)
                  TileLayer(
                    urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.employee_app',
                  ),
 
                  // 2. Route line
                  if (_routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          strokeWidth: 5.0,
                          color: Colors.indigo,
                        ),
                      ],
                    ),
 
                  // 3. Markers (pins)
                  MarkerLayer(
                    markers: [
 
                      // Your current location — BLUE pin
                      if (_myLocation != null)
                        Marker(
                          point: _myLocation!,
                          width: 80,
                          height: 80,
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('You',
                                  style: TextStyle(color: Colors.white,
                                    fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                              const Icon(Icons.location_pin,
                                color: Colors.blue, size: 36),
                            ],
                          ),
                        ),
 
                      // Employee photo location — RED pin
                      Marker(
                        point: LatLng(widget.destLat, widget.destLng),
                        width: 100,
                        height: 80,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(widget.employeeName,
                                style: const TextStyle(color: Colors.white,
                                  fontSize: 10, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.location_pin,
                              color: Colors.red, size: 36),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
 
              // ── Info card at bottom (distance + time) ──
              if (_distanceKm != null)
                Positioned(
                  bottom: 24,
                  left: 16,
                  right: 16,
                  child: Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          // Distance
                          Column(children: [
                            const Icon(Icons.straighten, color: Colors.indigo),
                            const SizedBox(height: 4),
                            Text(
                              '${_distanceKm!.toStringAsFixed(1)} km',
                              style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const Text('Distance',
                              style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ]),
 
                          // Divider
                          Container(width: 1, height: 40, color: Colors.grey.shade300),
 
                          // Time
                          Column(children: [
                            const Icon(Icons.access_time, color: Colors.indigo),
                            const SizedBox(height: 4),
                            Text(
                              '$_durationMin min',
                              style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const Text('Est. Drive Time',
                              style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ]),
 
                          // Divider
                          Container(width: 1, height: 40, color: Colors.grey.shade300),
 
                          // Route type
                          const Column(children: [
                            Icon(Icons.directions_car, color: Colors.indigo),
                            SizedBox(height: 4),
                            Text('Driving',
                              style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('Route Mode',
                              style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ]),
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
