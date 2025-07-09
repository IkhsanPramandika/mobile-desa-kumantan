import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_desa_kumantan/pages/login/login_page.dart';
import 'package:mobile_desa_kumantan/core/config/app_config.dart';
import 'edit_profile_page.dart';
import 'ganti_password.dart';
import 'package:mobile_desa_kumantan/pages/bantuan/halaman_bantuan.dart';

class AppColors {
  static final Color primaryColor = Colors.blue.shade800;
  static final Color lightGrey = Colors.grey.shade200;
  static final Color darkGrey = Colors.grey.shade800;
  static final Color mediumGrey = Colors.grey.shade600;
}

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
      fotoProfil: json['foto_ktp'],
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
      throw Exception('Sesi tidak valid. Silakan login ulang.');
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
    final token = prefs.getString('auth_token');

    if (!mounted || token == null) return;

    await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/logout'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    await prefs.remove('auth_token');

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _refreshProfile() async {
    setState(() {
      _userProfileFuture = _fetchUserProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Profil Saya',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        color: AppColors.primaryColor,
        child: FutureBuilder<UserProfile>(
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
      ),
    );
  }

  Widget _buildProfileView(UserProfile user) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildProfileCard(user),
        const SizedBox(height: 24),
        _buildSectionTitle("Pengaturan Akun"),
        const SizedBox(height: 12),
        _buildOptionGroup([
          _buildOptionTile(
            icon: Icons.edit_outlined,
            title: 'Ubah Data Diri',
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfilePage(currentUser: user),
                ),
              );
              if (result == true) {
                _refreshProfile();
              }
            },
          ),
          _buildOptionTile(
            icon: Icons.lock_outline_rounded,
            title: 'Ubah Kata Sandi',
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ChangePasswordPage()));
            },
          ),
        ]),
        const SizedBox(height: 24),
        _buildSectionTitle("Lainnya"),
        const SizedBox(height: 12),
        _buildOptionGroup([
          _buildOptionTile(
            icon: Icons.help_outline_rounded,
            title: 'Pusat Bantuan',
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => HelpCenterPage()));
            },
          ),
          _buildOptionTile(
            icon: Icons.logout_rounded,
            title: 'Keluar Akun',
            onTap: _logout,
            isLogout: true,
          ),
        ]),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.poppins(
        fontWeight: FontWeight.bold,
        fontSize: 13,
        color: AppColors.mediumGrey,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildProfileCard(UserProfile user) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.primaryColor.withOpacity(0.1),
            backgroundImage: user.fotoProfil != null
                ? NetworkImage('${AppConfig.baseUrl}/storage/${user.fotoProfil}')
                : const NetworkImage('https://i.pravatar.cc/150')
                    as ImageProvider,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.namaLengkap,
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('NIK: ${user.nik}',
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: AppColors.mediumGrey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionGroup(List<Widget> options) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.lightGrey)),
      child: ListView.separated(
        itemBuilder: (context, index) => options[index],
        separatorBuilder: (context, index) =>
            const Divider(height: 1, indent: 56),
        itemCount: options.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
      ),
    );
  }

  Widget _buildOptionTile(
      {required IconData icon,
      required String title,
      required VoidCallback onTap,
      bool isLogout = false}) {
    final color = isLogout ? Colors.red.shade600 : AppColors.darkGrey;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Icon(icon, color: color),
      title: Text(title,
          style:
              GoogleFonts.poppins(fontWeight: FontWeight.w500, color: color)),
      trailing:
          isLogout ? null : const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}