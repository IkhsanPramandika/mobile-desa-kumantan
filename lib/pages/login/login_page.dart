import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

// Sesuaikan dengan path yang benar di proyek Anda
import '../../core/config/app_config.dart';
import '../home/dashboard_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _nikController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadUserCredentials();
  }

  @override
  void dispose() {
    _nikController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool rememberMe = prefs.getBool('remember_me') ?? false;

      if (rememberMe) {
        final String nik = prefs.getString('saved_nik') ?? '';
        final String password = prefs.getString('saved_password') ?? '';
        setState(() {
          _nikController.text = nik;
          _passwordController.text = password;
          _rememberMe = true;
        });
      }
    } catch (e) {
      // Abaikan jika error saat memuat SharedPreferences
    }
  }

  Future<void> _handleRememberMe() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', _rememberMe);

      if (_rememberMe) {
        await prefs.setString('saved_nik', _nikController.text);
        await prefs.setString('saved_password', _passwordController.text);
      } else {
        await prefs.remove('saved_nik');
        await prefs.remove('saved_password');
      }
    } catch (e) {
      // Gagal menyimpan preferensi
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    await _handleRememberMe();

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/login'),
        headers: {'Accept': 'application/json'},
        body: {
          'nik': _nikController.text,
          'password': _passwordController.text,
          'device_name': 'mobile_app_flutter',
        },
      );

      if (!mounted) return;

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final String? token = data['access_token'];
        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);

          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const DashboardPage()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Login sukses, tapi token tidak ditemukan.'),
            backgroundColor: Colors.orange,
          ));
        }
      } else {
        final errorMessage = data['message'] ?? 'Kredensial tidak valid.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Tidak dapat terhubung ke server. Periksa koneksi atau Alamat IP.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Bagian Header
                _buildHeader(),
                const SizedBox(height: 48),

                // Bagian Form
                _buildForm(),
                const SizedBox(height: 48),

                // Bagian Footer
                _buildFooter(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.network(
          'https://kominfosandi.kamparkab.go.id/wp-content/uploads/2019/12/logo_kampar-2.png',
          height: 80,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.shield_outlined,
            size: 80,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Selamat Datang Kembali',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Masuk untuk mengakses layanan Desa Kumantan',
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nikController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'NIK (Nomor Induk Kependudukan)',
              prefixIcon: const Icon(Icons.person_outline),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'NIK tidak boleh kosong';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: IconButton(
                icon: Icon(_isPasswordVisible
                    ? Icons.visibility_off
                    : Icons.visibility),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password tidak boleh kosong';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: _rememberMe,
                onChanged: (bool? value) {
                  setState(() {
                    _rememberMe = value ?? false;
                  });
                },
                activeColor: Colors.blue.shade800,
              ),
              const Text('Ingat Saya'),
              const Spacer(),
              TextButton(
                onPressed: () {/* TODO: Navigasi ke Lupa Password */},
                child: Text('Lupa Password?',
                    style: GoogleFonts.poppins(color: Colors.blue.shade800)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('MASUK',
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Belum memiliki akun? ',
            style: GoogleFonts.poppins(color: Colors.grey.shade700)),
        TextButton(
          onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const RegisterPage())),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text('Daftar Sekarang',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
        ),
      ],
    );
  }
}