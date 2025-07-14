import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;

  final _namaController = TextEditingController();
  final _nikController = TextEditingController();
  final _emailController = TextEditingController();
  final _nomorHpController = TextEditingController();
  final _tempatLahirController = TextEditingController();
  final _tanggalLahirController = TextEditingController();
  final _jenisKelaminController = TextEditingController();
  final _alamatController = TextEditingController();
  final _agamaController = TextEditingController();
  final _statusPerkawinanController = TextEditingController();
  final _pekerjaanController = TextEditingController();

  File? _profileImageFile;
  String? _currentProfileImageUrl;

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _nikController.dispose();
    _emailController.dispose();
    _nomorHpController.dispose();
    _tempatLahirController.dispose();
    _tanggalLahirController.dispose();
    _jenisKelaminController.dispose();
    _alamatController.dispose();
    _agamaController.dispose();
    _statusPerkawinanController.dispose();
    _pekerjaanController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfileData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) throw Exception("Token tidak ditemukan");

      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/masyarakat/profil'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json'
        },
      );

      if (mounted && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _namaController.text = data['nama_lengkap'] ?? '';
        _nikController.text = data['nik'] ?? '';
        _emailController.text = data['email'] ?? '';
        _nomorHpController.text = data['nomor_hp'] ?? '';
        _tempatLahirController.text = data['tempat_lahir'] ?? '';
        _tanggalLahirController.text = data['tanggal_lahir'] ?? '';
        _jenisKelaminController.text = data['jenis_kelamin'] ?? '';
        _alamatController.text = data['alamat_lengkap'] ?? '';
        _agamaController.text = data['agama'] ?? '';
        _statusPerkawinanController.text = data['status_perkawinan'] ?? '';
        _pekerjaanController.text = data['pekerjaan'] ?? '';
        _currentProfileImageUrl = data['foto_ktp'];
      } else {
        throw Exception("Gagal memuat data profil");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesi berakhir, silakan login ulang.')));
      setState(() => _isLoading = false);
      return;
    }

    var request = http.MultipartRequest(
        'POST', Uri.parse('${AppConfig.apiBaseUrl}/masyarakat/profil'));
    request.headers.addAll(
        {'Accept': 'application/json', 'Authorization': 'Bearer $token'});
    request.fields['_method'] = 'PUT';

    request.fields['nama_lengkap'] = _namaController.text;
    request.fields['email'] = _emailController.text;
    request.fields['nomor_hp'] = _nomorHpController.text;
    request.fields['tempat_lahir'] = _tempatLahirController.text;
    request.fields['tanggal_lahir'] = _tanggalLahirController.text;
    request.fields['jenis_kelamin'] = _jenisKelaminController.text;
    request.fields['alamat_lengkap'] = _alamatController.text;
    request.fields['agama'] = _agamaController.text;
    request.fields['status_perkawinan'] = _statusPerkawinanController.text;
    request.fields['pekerjaan'] = _pekerjaanController.text;

    if (_profileImageFile != null) {
      request.files.add(await http.MultipartFile.fromPath(
          'foto_ktp', _profileImageFile!.path));
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Terjadi error koneksi: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
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
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildProfilePictureUploader(),
                    const SizedBox(height: 24),
                    _buildSectionHeader("Informasi Pribadi"),
                    _buildTextField(
                        controller: _namaController,
                        label: 'Nama Lengkap',
                        icon: Icons.person_outline),
                    _buildTextField(
                        controller: _nikController,
                        label: 'NIK',
                        icon: Icons.badge_outlined,
                        enabled: false),
                    _buildTextField(
                        controller: _tempatLahirController,
                        label: 'Tempat Lahir',
                        icon: Icons.location_city_outlined),
                    _buildDatePickerField(
                        controller: _tanggalLahirController,
                        label: 'Tanggal Lahir'),
                    _buildDropdownField(
                        controller: _jenisKelaminController,
                        label: 'Jenis Kelamin',
                        icon: Icons.wc_outlined,
                        items: ['Laki-laki', 'Perempuan']),
                    _buildDropdownField(
                        controller: _agamaController,
                        label: 'Agama',
                        icon: Icons.mosque_outlined,
                        items: [
                          'Islam',
                          'Kristen Protestan',
                          'Katolik',
                          'Hindu',
                          'Buddha',
                          'Konghucu'
                        ]),
                    _buildTextField(
                        controller: _pekerjaanController,
                        label: 'Pekerjaan',
                        icon: Icons.work_outline),
                    _buildDropdownField(
                        controller: _statusPerkawinanController,
                        label: 'Status Perkawinan',
                        icon: Icons.family_restroom_outlined,
                        items: [
                          'Belum kawin',
                          'Kawin',
                          'Cerai Hidup',
                          'Cerai Mati'
                        ]),
                    const SizedBox(height: 24),
                    _buildSectionHeader("Kontak & Alamat"),
                    _buildTextField(
                        controller: _emailController,
                        label: 'Alamat Email',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress),
                    _buildTextField(
                        controller: _nomorHpController,
                        label: 'Nomor HP',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone),
                    _buildTextField(
                        controller: _alamatController,
                        label: 'Alamat Lengkap',
                        icon: Icons.home_outlined,
                        maxLines: 3),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _updateProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade800,
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
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(title,
          style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900)),
    );
  }

  Widget _buildProfilePictureUploader() {
    ImageProvider<Object> imageProvider;
    if (_profileImageFile != null) {
      imageProvider = FileImage(_profileImageFile!);
    } else if (_currentProfileImageUrl != null &&
        _currentProfileImageUrl!.isNotEmpty) {
      imageProvider =
          NetworkImage('${AppConfig.baseUrl}/storage/$_currentProfileImageUrl');
    } else {
      imageProvider = const NetworkImage(
          'https://placehold.co/150x150/EBF4FF/767676?text=Foto');
    }

    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundImage: imageProvider,
            onBackgroundImageError: (exception, stackTrace) {
              setState(() {
                imageProvider = const NetworkImage(
                    'https://placehold.co/150x150/EBF4FF/767676?text=Error');
              });
            },
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.blue.shade800,
              child: IconButton(
                icon:
                    const Icon(Icons.camera_alt, color: Colors.white, size: 20),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        enabled: enabled,
        style: GoogleFonts.poppins(
            color: enabled ? Colors.black87 : Colors.grey.shade600),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.grey.shade600),
          filled: true,
          fillColor: enabled ? Colors.white : Colors.grey.shade100,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue.shade800)),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return '$label tidak boleh kosong';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDatePickerField(
      {required TextEditingController controller, required String label}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(Icons.calendar_today, color: Colors.grey.shade600),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300)),
        ),
        onTap: () async {
          DateTime? pickedDate = await showDatePicker(
            context: context,
            initialDate: controller.text.isNotEmpty
                ? (DateFormat('yyyy-MM-dd').tryParse(controller.text) ??
                    DateTime.now())
                : DateTime.now(),
            firstDate: DateTime(1900),
            lastDate: DateTime.now(),
          );
          if (pickedDate != null) {
            controller.text = DateFormat('yyyy-MM-dd').format(pickedDate);
          }
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return '$label tidak boleh kosong';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDropdownField(
      {required TextEditingController controller,
      required String label,
      required IconData icon,
      required List<String> items}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: controller.text.isNotEmpty ? controller.text : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.grey.shade600),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300)),
        ),
        items: items.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        onChanged: (String? newValue) {
          setState(() {
            controller.text = newValue ?? '';
          });
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return '$label tidak boleh kosong';
          }
          return null;
        },
      ),
    );
  }
}
