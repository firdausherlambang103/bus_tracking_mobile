import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

class DriverDashboard extends StatefulWidget {
  @override
  _DriverDashboardState createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  bool _isTracking = false;
  Position? _currentPosition;
  Timer? _timer;
  final String apiUrl = "http://192.168.1.20:8000/api/update-location";

  // Fungsi untuk mengecek dan meminta izin GPS
  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('GPS HP Anda mati. Silakan aktifkan.');
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Izin lokasi ditolak.');
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('Izin lokasi ditolak permanen. Ubah di pengaturan HP.');
      return false;
    }
    return true;
  }

  // Fungsi mengambil lokasi dan kirim ke Laravel
  Future<void> _updateLocationToServer() async {
    try {
      // 1. Ambil posisi GPS terbaru
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      setState(() {
        _currentPosition = position;
      });

      // 2. Ambil token yang tersimpan saat login
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      // 3. Kirim ke API Laravel
      var response = await Dio().post(
        apiUrl,
        data: {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      print("Lokasi terkirim: ${position.latitude}, ${position.longitude}");
    } catch (e) {
      print("Gagal mengirim lokasi: $e");
    }
  }

  // Fungsi menyalakan/mematikan tracking
  void _toggleTracking() async {
    if (_isTracking) {
      _timer?.cancel();
      setState(() => _isTracking = false);
      _showSnackBar('Pelacakan dihentikan.');
    } else {
      bool hasPermission = await _handleLocationPermission();
      if (!hasPermission) return;

      setState(() => _isTracking = true);
      _showSnackBar('Pelacakan dimulai!');

      // Jalankan kirim lokasi pertama kali
      _updateLocationToServer();

      // Set timer untuk kirim ulang setiap 10 detik
      _timer = Timer.periodic(Duration(seconds: 10), (timer) {
        _updateLocationToServer();
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _logout() async {
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
        title: Text("Dashboard Supir"),
        actions: [IconButton(icon: Icon(Icons.logout), onPressed: _logout)],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_bus,
              size: 100,
              color: _isTracking ? Colors.green : Colors.grey,
            ),
            SizedBox(height: 20),
            Text(
              _isTracking ? "STATUS: AKTIF MELACAK" : "STATUS: OFF",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, 
              color: _isTracking ? Colors.green : Colors.red),
            ),
            if (_currentPosition != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text("Lokasi Anda: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}"),
              ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: _toggleTracking,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isTracking ? Colors.red : Colors.blue,
                minimumSize: Size(200, 60),
              ),
              child: Text(
                _isTracking ? "STOP TRACKING" : "START TRACKING",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}