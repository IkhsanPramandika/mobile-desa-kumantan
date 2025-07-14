import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import '../permohonan/form_permohonan_page.dart';
import '../profile/edit_profile_page.dart';

class LayananPage extends StatefulWidget {
  const LayananPage({super.key});

  @override
  State<LayananPage> createState() => _LayananPageState();
}

class _LayananPageState extends State<LayananPage> {
  bool _isCheckingProfile = false;

  bool _isFieldEmpty(dynamic value) {
    if (value == null) return true;
    if (value is String && value.trim().isEmpty) return true;
    return false;
  }

  Future<void> _handleAjukanPermohonan({
    required String jenisSurat,
    required String pageTitle,
  }) async {
    if (!mounted) return;
    setState(() {
      _isCheckingProfile = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) throw Exception("Sesi tidak valid.");

      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/masyarakat/profil'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final profileData = jsonDecode(response.body)['data'];
        
        final bool isProfileComplete = 
            !_isFieldEmpty(profileData['alamat_lengkap']) &&
            !_isFieldEmpty(profileData['tempat_lahir']) &&
            !_isFieldEmpty(profileData['tanggal_lahir']) &&
            !_isFieldEmpty(profileData['jenis_kelamin']) &&
            !_isFieldEmpty(profileData['agama']) &&
            !_isFieldEmpty(profileData['pekerjaan']);

        if (isProfileComplete) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FormPermohonanPage(
                jenisSurat: jenisSurat,
                pageTitle: pageTitle,
              ),
            ),
          );
        } else {
          _showLengkapiProfilDialog();
        }
      } else {
        throw Exception('Gagal memverifikasi profil. Status: ${response.statusCode}');
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingProfile = false;
        });
      }
    }
  }

  void _showLengkapiProfilDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.person_search_rounded, color: Colors.blue.shade700),
              const SizedBox(width: 10),
              const Text('Profil Belum Lengkap'),
            ],
          ),
          content: const Text(
            'Untuk melanjutkan, harap lengkapi data diri Anda terlebih dahulu agar pengajuan surat lebih mudah.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Nanti Saja'),
              onPressed: () {
                Navigator.of(ctx).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('Lengkapi Sekarang'),
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EditProfilePage()),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Layanan Surat'),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildLayananButton(
                title: 'Surat Keterangan Usaha',
                subtitle: 'Untuk keperluan pengajuan pinjaman, dll.',
                icon: Icons.store_mall_directory,
                onPressed: () {
                  _handleAjukanPermohonan(
                    jenisSurat: 'sk_usaha',
                    pageTitle: 'Permohonan SK Usaha',
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildLayananButton(
                title: 'Surat Keterangan Tidak Mampu',
                subtitle: 'Untuk pengajuan beasiswa, bantuan, dll.',
                icon: Icons.volunteer_activism,
                onPressed: () {
                  _handleAjukanPermohonan(
                    jenisSurat: 'sk_tidak_mampu',
                    pageTitle: 'Permohonan SKTM',
                  );
                },
              ),
            ],
          ),
          if (_isCheckingProfile)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('Memeriksa profil...', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLayananButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        leading: Icon(icon, size: 40, color: Colors.blue.shade700),
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onPressed,
      ),
    );
  }
}
