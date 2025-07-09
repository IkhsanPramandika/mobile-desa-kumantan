import 'dart:convert';
import 'dart:io'; // Diperlukan untuk handle File
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart'; // Import paket image_picker

import '../../core/config/app_config.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nikController = TextEditingController();
  final _namaLengkapController = TextEditingController();
  final _nomorHpController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();

  File? _ktpImageFile; // Variabel untuk menyimpan file KTP yang dipilih

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    _nikController.dispose();
    _namaLengkapController.dispose();
    _nomorHpController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    super.dispose();
  }

  // Fungsi untuk memilih gambar KTP
  Future<void> _pickKtpImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _ktpImageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    // Validasi tambahan untuk file KTP
    if (_ktpImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mohon unggah foto KTP Anda.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Menggunakan MultipartRequest untuk mengirim data form dan file
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.apiBaseUrl}/register'),
      );
      request.headers['Accept'] = 'application/json';

      // Menambahkan field teks
      request.fields['nik'] = _nikController.text;
      request.fields['nama_lengkap'] = _namaLengkapController.text;
      request.fields['nomor_hp'] = _nomorHpController.text;
      request.fields['email'] = _emailController.text;
      request.fields['password'] = _passwordController.text;
      request.fields['password_confirmation'] = _passwordConfirmationController.text;

      // Menambahkan file KTP
      request.files.add(
        await http.MultipartFile.fromPath(
          'foto_ktp', // Nama field ini harus sesuai dengan yang diharapkan di backend Laravel
          _ktpImageFile!.path,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (!mounted) return;
      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Registrasi Berhasil'),
            content: Text(data['message'] ?? 'Akun Anda telah dibuat dan sedang menunggu verifikasi.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        String errorMessage = data['message'] ?? 'Gagal melakukan registrasi.';
        if (data['errors'] != null) {
          errorMessage = (data['errors'] as Map).entries.first.value[0];
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak dapat terhubung ke server. Periksa koneksi.'),
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                _buildForm(),
                const SizedBox(height: 32),
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
        Text(
          'Buat Akun Baru',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Isi data diri Anda untuk memulai layanan',
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
          _buildTextField(
            controller: _nikController,
            label: 'NIK (16 Digit)',
            icon: Icons.person_outline,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _namaLengkapController,
            label: 'Nama Lengkap (Sesuai KTP)',
            icon: Icons.badge_outlined,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _nomorHpController,
            label: 'Nomor HP Aktif',
            icon: Icons.phone_android_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _emailController,
            label: 'Alamat Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          _buildPasswordField(
            controller: _passwordController,
            label: 'Password',
            isVisible: _isPasswordVisible,
            onToggleVisibility: () {
              setState(() => _isPasswordVisible = !_isPasswordVisible);
            },
          ),
          const SizedBox(height: 16),
          _buildPasswordField(
            controller: _passwordConfirmationController,
            label: 'Konfirmasi Password',
            isVisible: _isConfirmPasswordVisible,
            onToggleVisibility: () {
              setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible);
            },
            isConfirmation: true,
          ),
          const SizedBox(height: 24),
          _buildKtpPicker(),
          const SizedBox(height: 32),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
                  onPressed: _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('DAFTAR SEKARANG', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
        ],
      ),
    );
  }
  
  Widget _buildKtpPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Unggah Foto KTP',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: _pickKtpImage,
            borderRadius: BorderRadius.circular(12),
            child: _ktpImageFile == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined, color: Colors.grey.shade500, size: 40),
                      const SizedBox(height: 8),
                      Text('Ketuk untuk memilih gambar', style: GoogleFonts.poppins(color: Colors.grey.shade600)),
                    ],
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.file(_ktpImageFile!, fit: BoxFit.cover),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Sudah memiliki akun? ', style: GoogleFonts.poppins(color: Colors.grey.shade700)),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text('Masuk di sini', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '$label tidak boleh kosong';
        }
        if (label.contains('NIK') && value.length != 16) {
          return 'NIK harus terdiri dari 16 digit';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isVisible,
    required VoidCallback onToggleVisibility,
    bool isConfirmation = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !isVisible,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        suffixIcon: IconButton(
          icon: Icon(isVisible ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggleVisibility,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '$label tidak boleh kosong';
        }
        if (!isConfirmation && value.length < 8) {
          return 'Password minimal 8 karakter';
        }
        if (isConfirmation && value != _passwordController.text) {
          return 'Konfirmasi password tidak cocok';
        }
        return null;
      },
    );
  }
}