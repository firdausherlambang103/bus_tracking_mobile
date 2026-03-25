import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Pastikan Anda sudah membuat kedua file ini di folder lib/screens/
import 'driver_dashboard.dart';
import 'passenger_dashboard.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  // Sesuaikan IP ini dengan hasil 'ipconfig' di CMD laptop Anda
  final String apiUrl = "http://192.168.1.20:8000/api/login";

  Future<void> login() async {
    // Menutup keyboard otomatis saat tombol ditekan
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      // Mengirim data login ke Laravel menggunakan Dio
      var response = await Dio().post(
        apiUrl,
        data: {
          'email': _emailController.text,
          'password': _passwordController.text,
        },
        // Opsi tambahan agar Laravel mengirim JSON, bukan HTML
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          followRedirects: false,
          validateStatus: (status) => status! < 500, // Terima response selama bukan error server 500
        ),
      );

      // Cek apakah response sukses (status 200)
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        String token = response.data['data']['token'];
        String role = response.data['data']['user']['role'];

        // Simpan token dan role ke memori internal HP (Shared Preferences)
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        await prefs.setString('role', role);

        // Arahkan ke halaman sesuai Role
        if (role == 'driver') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => DriverDashboard()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => PassengerDashboard()),
          );
        }
      } else {
        // Jika status code bukan 200 (misal 401: Unauthorized)
        String msg = response.data['message'] ?? "Email atau Password salah";
        _showSnackBar(msg, Colors.orange);
      }
    } on DioException catch (e) {
      String errorMessage = "Gagal terhubung ke server";

      // Jika ada respon dari server tapi formatnya salah (seperti HTML tadi)
      if (e.response != null) {
        if (e.response?.data is Map) {
          errorMessage = e.response?.data['message'] ?? errorMessage;
        } else {
          print("Raw Error: ${e.response?.data}");
          errorMessage = "Server mengirim format salah (HTML). Cek URL & API Laravel.";
        }
      } else {
        // Jika tidak ada respon sama sekali (Server mati / IP salah)
        errorMessage = "Tidak ada respon dari server. Cek koneksi WiFi & IP Laptop.";
      }

      _showSnackBar(errorMessage, Colors.red);
    } catch (e) {
      _showSnackBar("Error Internal: $e", Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Fungsi praktis untuk memunculkan pesan di bawah layar
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.directions_bus_rounded, size: 80, color: Colors.blueAccent),
              SizedBox(height: 10),
              Text(
                "Bus Tracking System",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 40),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: "Email",
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: "Password",
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                obscureText: true,
              ),
              SizedBox(height: 30),
              _isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: login,
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        backgroundColor: Colors.blueAccent,
                      ),
                      child: Text("LOGIN", style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}