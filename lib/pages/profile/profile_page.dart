// Lokasi: lib/pages/profile/profile_page.dart

import 'dart:convert';
import 'package:mobile_desa_kumantan/pages/login/login_page.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import 'edit_profile_page.dart';

// Model untuk menampung data user dari API
class UserProfile {
  final String namaLengkap;
  final String? tanggalLahir;
  final String email;
  final String? alamatLengkap;
  final String? nomorHp;
  final String nik;
  final String? fotoProfil;

  UserProfile({
    required this.namaLengkap,
    this.tanggalLahir,
    required this.email,
    this.alamatLengkap,
    this.nomorHp,
    required this.nik,
    this.fotoProfil,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      namaLengkap: json['nama_lengkap'] ?? 'Nama Tidak Ditemukan',
      tanggalLahir: json['tanggal_lahir'],
      email: json['email'] ?? '-',
      alamatLengkap: json['alamat_lengkap'] ?? 'Alamat belum diisi',
      nomorHp: json['nomor_hp'] ?? '-',
      nik: json['nik'] ?? '-',
      fotoProfil: json['foto_ktp'], // Sesuaikan dengan nama field dari API Anda
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Future<UserProfile>? _userProfileFuture;

  @override
  void initState() {
    super.initState();
    _userProfileFuture = _fetchUserProfile();
  }

  Future<UserProfile> _fetchUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      throw Exception('Token tidak ditemukan, silakan login ulang.');
    }

    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/profil'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return UserProfile.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Gagal memuat data profil.');
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token'); // Hapus token dari penyimpanan

    if (!mounted) return;
    // Kembali ke halaman login dan hapus semua halaman sebelumnya
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('Profil Saya', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<UserProfile>(
        future: _userProfileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            final user = snapshot.data!;
            return _buildProfileView(user);
          } else {
            return const Center(child: Text('Tidak ada data profil.'));
          }
        },
      ),
    );
  }

  Widget _buildProfileView(UserProfile user) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildProfileCard(user),
        const SizedBox(height: 20),
        _buildOptionCard(
          icon: Icons.lock_outline,
          title: 'Ubah Kata Sandi',
          onTap: () {},
        ),
        _buildOptionCard(
          icon: Icons.logout,
          title: 'Keluar Akun',
          onTap: _logout,
        ),
      ],
    );
  }

  Widget _buildProfileCard(UserProfile user) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: user.fotoProfil != null
                      ? NetworkImage('${AppConfig.baseUrl}/storage/${user.fotoProfil}')
                      : const NetworkImage('https://i.pravatar.cc/150'),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.namaLengkap,
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'NIK: ${user.nik}',
                        style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: Colors.green.shade700),
                  onPressed: () async {
                    // Navigasi ke halaman edit dan tunggu hasilnya
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditProfilePage(currentUser: user),
                      ),
                    );
                    // Jika halaman edit mengembalikan 'true', muat ulang data
                    if (result == true) {
                      setState(() {
                        _userProfileFuture = _fetchUserProfile();
                      });
                    }
                  },
                ),
              ],
            ),
            const Divider(height: 40),
            _buildInfoRow(Icons.email_outlined, 'Email', user.email),
            _buildInfoRow(Icons.phone_android_outlined, 'Nomor HP', user.nomorHp ?? '-'),
            _buildInfoRow(Icons.home_outlined, 'Alamat', user.alamatLengkap ?? 'Belum diisi', maxLines: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey.shade500, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.poppins(color: Colors.grey.shade600)),
                Text(value, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500), maxLines: maxLines, overflow: TextOverflow.ellipsis),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildOptionCard({required IconData icon, required String title, required VoidCallback onTap}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(icon, color: Colors.green.shade800),
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
