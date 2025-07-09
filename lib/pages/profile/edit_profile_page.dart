import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import 'profile_page.dart';

class AppColors {
  static final Color primaryColor = Colors.blue.shade800;
  static final Color lightGrey = Colors.grey.shade200;
  static final Color darkGrey = Colors.grey.shade800;
  static final Color mediumGrey = Colors.grey.shade600;
}

class EditProfilePage extends StatefulWidget {
  final UserProfile currentUser;
  const EditProfilePage({super.key, required this.currentUser});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _namaController;
  late TextEditingController _emailController;
  late TextEditingController _alamatController;
  late TextEditingController _nomorHpController;

  bool _isLoading = false;
  File? _profileImageFile;

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(text: widget.currentUser.namaLengkap);
    _emailController = TextEditingController(text: widget.currentUser.email);
    _alamatController =
        TextEditingController(text: widget.currentUser.alamatLengkap);
    _nomorHpController = TextEditingController(text: widget.currentUser.nomorHp);
  }

  Future<void> _pickImage() async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null) {
      setState(() {
        _profileImageFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _updateProfile() async {
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (!mounted) return;

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesi berakhir, silakan login ulang.')));
      return;
    }

    var request =
        http.MultipartRequest('POST', Uri.parse('${AppConfig.apiBaseUrl}/profil'));

    request.headers.addAll({
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });

    request.fields['_method'] = 'PUT';
    request.fields['nama_lengkap'] = _namaController.text;
    request.fields['email'] = _emailController.text;
    request.fields['nomor_hp'] = _nomorHpController.text;
    request.fields['alamat_lengkap'] = _alamatController.text;

    if (_profileImageFile != null) {
      request.files.add(
          await http.MultipartFile.fromPath('foto_ktp', _profileImageFile!.path));
    }

    try {
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final data = jsonDecode(responseBody);

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Profil berhasil diperbarui!'),
            backgroundColor: Colors.green));
        Navigator.of(context).pop(true);
      } else {
        String errorMessage = data['message'] ?? 'Gagal memperbarui profil.';
        if (data['errors'] != null) {
          errorMessage = (data['errors'] as Map).entries.first.value[0];
        }
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Terjadi error koneksi.'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ubah Data Diri',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _buildProfilePictureUploader(),
            const SizedBox(height: 32),
            _buildTextField(controller: _namaController, label: 'Nama Lengkap', icon: Icons.person_outline),
            const SizedBox(height: 16),
            _buildTextField(
                controller: TextEditingController(text: widget.currentUser.nik),
                label: 'NIK',
                enabled: false,
                icon: Icons.badge_outlined),
            const SizedBox(height: 16),
            _buildTextField(
                controller: _emailController,
                label: 'Alamat Email',
                keyboardType: TextInputType.emailAddress,
                icon: Icons.email_outlined),
            const SizedBox(height: 16),
            _buildTextField(
                controller: _nomorHpController,
                label: 'Nomor HP',
                keyboardType: TextInputType.phone,
                icon: Icons.phone_outlined),
            const SizedBox(height: 16),
            _buildTextField(
                controller: _alamatController,
                label: 'Alamat Lengkap',
                maxLines: 3,
                icon: Icons.home_outlined),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _updateProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('SIMPAN PERUBAHAN',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 16)),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePictureUploader() {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundImage: _profileImageFile != null
                ? FileImage(_profileImageFile!)
                : (widget.currentUser.fotoProfil != null
                        ? NetworkImage(
                            '${AppConfig.baseUrl}/storage/${widget.currentUser.fotoProfil}')
                        : const NetworkImage('https://i.pravatar.cc/150'))
                    as ImageProvider,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primaryColor,
              child: IconButton(
                icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                onPressed: _pickImage,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
      {required TextEditingController controller,
      required String label,
      required IconData icon,
      int maxLines = 1,
      TextInputType keyboardType = TextInputType.text,
      bool enabled = true}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      enabled: enabled,
      style: GoogleFonts.poppins(color: enabled ? Colors.black87 : AppColors.mediumGrey),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.mediumGrey),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.shade100,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.lightGrey)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.lightGrey)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primaryColor)),
      ),
    );
  }
}