import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong2.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

class PassengerDashboard extends StatefulWidget {
  @override
  _PassengerDashboardState createState() => _PassengerDashboardState();
}

class _PassengerDashboardState extends State<PassengerDashboard> {
  final String apiUrl = "http://192.168.1.20:8000/api/bus-locations";
  List<Marker> _busMarkers = [];
  Timer? _timer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBusLocations(); // Ambil data pertama kali
    // Refresh data setiap 10 detik
    _timer = Timer.periodic(Duration(seconds: 10), (timer) => _fetchBusLocations());
  }

  Future<void> _fetchBusLocations() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      var response = await Dio().get(
        apiUrl,
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      if (response.data['status'] == 'success') {
        List data = response.data['data'];
        
        setState(() {
          _busMarkers = data.map((bus) {
            double lat = double.parse(bus['latitude'].toString());
            double lng = double.parse(bus['longitude'].toString());
            String driverName = bus['user']['name'] ?? "Bus";

            return Marker(
              point: LatLng(lat, lng),
              width: 50,
              height: 50,
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(2),
                    color: Colors.white,
                    child: Text(driverName, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  Icon(Icons.directions_bus, color: Colors.blue, size: 30),
                ],
              ),
            );
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Gagal mengambil lokasi bus: $e");
    }
  }

  void _logout() async {
    _timer?.cancel();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginScreen()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Live Tracking Bus"),
        actions: [IconButton(icon: Icon(Icons.logout), onPressed: _logout)],
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator())
        : FlutterMap(
            options: MapOptions(
              initialCenter: _busMarkers.isNotEmpty 
                  ? _busMarkers.first.point 
                  : LatLng(-7.594, 112.717), // Koordinat default (contoh: Nganjuk/Jatim)
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              MarkerLayer(markers: _busMarkers),
            ],
          ),
    );
  }
}