import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

// PENTING: Sesuaikan path ini dengan struktur folder Anda
import 'pages/home/dashboard_page.dart';
import 'pages/login/login_page.dart';

class SplashLogicPage extends StatefulWidget {
  const SplashLogicPage({super.key});

  @override
  State<SplashLogicPage> createState() => _SplashLogicPageState();
}

class _SplashLogicPageState extends State<SplashLogicPage> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // Memberi jeda 2 detik agar logo sempat terlihat
    await Future.delayed(const Duration(seconds: 2));

    // Jika widget sudah tidak ada di tree, jangan lanjutkan
    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      // Cek lagi jika widget masih ada setelah proses async
      if (mounted) {
        if (token != null) {
          // Jika ada token, langsung ke Dashboard
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const DashboardPage()),
          );
        } else {
          // Jika tidak ada token, ke Halaman Login
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        }
      }
    } catch (e) {
      // Jika terjadi error (misal: SharedPreferences gagal), arahkan ke Login
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pastikan path ke logo Anda sudah benar
            Image.asset('assets/icon/logo_desa.png', height: 120),
            const SizedBox(height: 24),
            Text(
              'Layanan Digital Desa Kumantan',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}