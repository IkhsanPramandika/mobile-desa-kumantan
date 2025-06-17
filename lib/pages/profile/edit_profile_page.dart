// Lokasi: lib/pages/profile/edit_profile_page.dart

import 'dart:convert';
import 'dart:io';
// >> PERBAIKAN: Menghapus import foundation.dart yang tidak terpakai <<
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import 'profile_page.dart';

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
    _alamatController = TextEditingController(text: widget.currentUser.alamatLengkap);
    _nomorHpController = TextEditingController(text: widget.currentUser.nomorHp);
  }
  
  Future<void> _pickImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null) {
      setState(() {
        _profileImageFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _updateProfile() async {
    setState(() { _isLoading = true; });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    // >> PERBAIKAN: Tambahkan 'mounted' check sebelum menggunakan BuildContext <<
    if (!mounted) return;

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sesi berakhir, silakan login ulang.')));
      return;
    }
    
    var request = http.MultipartRequest('POST', Uri.parse('${AppConfig.apiBaseUrl}/profil'));
    
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
        await http.MultipartFile.fromPath('foto_ktp', _profileImageFile!.path)
      );
    }
    
    try {
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final data = jsonDecode(responseBody);
      
      if (!mounted) return;
      
      if (response.statusCode == 200) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil berhasil diperbarui!'), backgroundColor: Colors.green));
         Navigator.of(context).pop(true);
      } else {
        String errorMessage = data['message'] ?? 'Gagal memperbarui profil.';
        if (data['errors'] != null) {
          errorMessage = (data['errors'] as Map).entries.first.value[0];
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: Colors.red));
      }

    } catch(e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Terjadi error koneksi.'), backgroundColor: Colors.red));
    } finally {
      if(mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ubah Data Diri', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _buildProfilePictureUploader(),
            const SizedBox(height: 24),
            _buildTextField(controller: _namaController, label: 'Nama Lengkap'),
            const SizedBox(height: 16),
            _buildTextField(controller: TextEditingController(text: widget.currentUser.nik), label: 'NIK', enabled: false),
            const SizedBox(height: 16),
            _buildTextField(controller: _emailController, label: 'Alamat Email', keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 16),
            _buildTextField(controller: _nomorHpController, label: 'Nomor HP', keyboardType: TextInputType.phone),
            const SizedBox(height: 16),
             _buildTextField(controller: _alamatController, label: 'Alamat Lengkap', maxLines: 3),
            const SizedBox(height: 32),
            _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
                  onPressed: _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('SIMPAN PERUBAHAN', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
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
                    ? NetworkImage('${AppConfig.baseUrl}/storage/${widget.currentUser.fotoProfil}')
                    : const NetworkImage('https://i.pravatar.cc/150')) as ImageProvider,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.green,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      enabled: enabled,
      style: TextStyle(color: enabled ? Colors.black87 : Colors.grey.shade700),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.shade200,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      ),
    );
  }
}
