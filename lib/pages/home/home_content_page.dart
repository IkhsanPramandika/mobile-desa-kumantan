import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../permohonan/pilih_permohonan_page.dart';
import '../permohonan/riwayat_permohonan_page.dart';
import '../notifications/notification_page.dart';
import '../berita/berita_detail_page.dart';

class UserProfile {
  final String namaLengkap;
  final String? fotoUrl;

  UserProfile({required this.namaLengkap, this.fotoUrl});

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      namaLengkap: json['nama_lengkap'] ?? 'Warga Desa',
      fotoUrl: json['foto_url'],
    );
  }
}

class Berita {
  final String judul;
  final String tanggal;
  final String slug;

  Berita({required this.judul, required this.tanggal, required this.slug});

  factory Berita.fromJson(Map<String, dynamic> json) {
    return Berita(
      judul: json['judul'] ?? 'Tanpa Judul',
      slug: json['slug'] ?? '',
      tanggal: json['created_at'] != null ? DateFormat('d MMMM yyyy', 'id_ID').format(DateTime.parse(json['created_at'])) : '-',
    );
  }
}

class DashboardData {
  final UserProfile profil;
  final Riwayat? riwayatTerakhir;
  final List<Berita> beritaTerbaru;
  final List<NotificationItem> notifikasi;
  final int unreadCount;

  DashboardData({
    required this.profil,
    this.riwayatTerakhir,
    required this.beritaTerbaru,
    required this.notifikasi,
    required this.unreadCount,
  });
}

class HomeContentPage extends StatefulWidget {
  const HomeContentPage({super.key});

  @override
  State<HomeContentPage> createState() => _HomeContentPageState();
}

class _HomeContentPageState extends State<HomeContentPage> {
  late Future<DashboardData> _dashboardDataFuture;

  @override
  void initState() {
    super.initState();
    _dashboardDataFuture = _fetchAllData();
  }

  Future<DashboardData> _fetchAllData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) throw Exception('Sesi tidak valid. Silakan login ulang.');

    final results = await Future.wait([
      _fetchProfil(token),
      _fetchRiwayatTerakhir(token),
      _fetchBeritaTerbaru(),
      _fetchNotifikasi(token),
    ]);

    final notifikasiData = results[3] as Map<String, dynamic>;

    return DashboardData(
      profil: results[0] as UserProfile,
      riwayatTerakhir: results[1] as Riwayat?,
      beritaTerbaru: results[2] as List<Berita>,
      notifikasi: notifikasiData['list'],
      unreadCount: notifikasiData['unread_count'],
    );
  }

  Future<void> _launchMapsUrl() async {
    final Uri mapsUrl = Uri.parse('https://g.co/kgs/c2zQ2nQ');
    if (!await launchUrl(mapsUrl, mode: LaunchMode.externalApplication)) {
      throw 'Tidak dapat membuka $mapsUrl';
    }
  }

  Future<UserProfile> _fetchProfil(String token) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/masyarakat/profil'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return UserProfile.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Gagal memuat profil');
    }
  }

  Future<Riwayat?> _fetchRiwayatTerakhir(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/masyarakat/riwayat-semua-permohonan?page=1&limit=1'),
        headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'] as List;
        if (data.isNotEmpty) {
          return Riwayat.fromJson(data.first);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<Berita>> _fetchBeritaTerbaru() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/pengumuman?limit=3'),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'] as List;
        return data.map((item) => Berita.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> _fetchNotifikasi(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/notifikasi'),
        headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<NotificationItem> list = (data['data'] as List)
            .map((item) => NotificationItem.fromJson(item))
            .toList();
        final unreadCount = data['unread_count'] as int? ?? 0;
        return {'list': list, 'unread_count': unreadCount};
      }
      return {'list': <NotificationItem>[], 'unread_count': 0};
    } catch (e) {
      return {'list': <NotificationItem>[], 'unread_count': 0};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: FutureBuilder<DashboardData>(
        future: _dashboardDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Error: ${snapshot.error}', textAlign: TextAlign.center)));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Tidak ada data.'));
          }
          
          final data = snapshot.data!;

          return RefreshIndicator(
            onRefresh: () async {
              setState(() { _dashboardDataFuture = _fetchAllData(); });
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                _buildHeader(context, data.profil, data.unreadCount, data.notifikasi),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusTerakhir(data.riwayatTerakhir),
                      const SizedBox(height: 24),
                      _buildInfoLayanan(),
                      const SizedBox(height: 24),
                      _buildSectionTitle(title: 'Layanan Desa'),
                      const SizedBox(height: 12),
                      _buildAksesCepat(context),
                      const SizedBox(height: 24),
                      _buildSectionTitle(title: 'Info Terbaru'),
                      const SizedBox(height: 12),
                      _buildInfoTerbaru(context, data.beritaTerbaru),
                    ],
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, UserProfile profil, int unreadCount, List<NotificationItem> notifications) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 140,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.blue.shade800,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
          ),
        ),
        Positioned(
          top: 60,
          left: 16,
          right: 16,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.white,
                backgroundImage: (profil.fotoUrl != null && profil.fotoUrl!.isNotEmpty)
                  ? NetworkImage(profil.fotoUrl!)
                  : null,
                child: (profil.fotoUrl == null || profil.fotoUrl!.isEmpty)
                  ? const Icon(Icons.person, size: 35, color: Colors.blue)
                  : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_getGreeting(), style: GoogleFonts.poppins(color: Colors.white70)),
                    Text(
                      profil.namaLengkap,
                      style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications, color: Colors.white, size: 30),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NotificationPage(initialNotifications: notifications),
                        )
                      ).then((_) {
                        setState(() {
                          _dashboardDataFuture = _fetchAllData();
                        });
                      });
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Center(
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoLayanan() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title: 'Informasi Layanan'),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                _buildInfoRow(
                  icon: Icons.access_time_filled_rounded,
                  title: 'Jam Layanan',
                  subtitle: 'Senin - Jumat | 08:00 - 14:00 WIB',
                  color: Colors.orange.shade700,
                ),
                const Divider(height: 16, indent: 16, endIndent: 16),
                _buildInfoRow(
                  icon: Icons.location_on,
                  title: 'Alamat Kantor Desa',
                  subtitle: 'JL. Mahmud Marzuki, Desa Kumantan, Bangkinang',
                  color: Colors.blue.shade700,
                  onTap: _launchMapsUrl,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: GoogleFonts.poppins(color: Colors.grey.shade700)),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) {
      return 'Selamat Pagi,';
    } else if (hour < 15) {
      return 'Selamat Siang,';
    } else if (hour < 18) {
      return 'Selamat Sore,';
    } else {
      return 'Selamat Malam,';
    }
  }

  Widget _buildStatusTerakhir(Riwayat? riwayat) {
    if (riwayat == null) {
      return const SizedBox.shrink();
    }
    return Card(
      elevation: 0,
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade100)
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.blue, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Status Permohonan Terakhir:", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  Text(
                    '${riwayat.jenisSurat} Anda berstatus "${riwayat.status}".',
                    style: GoogleFonts.poppins(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle({required String title, String? actionText}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
        if (actionText != null)
          Text(actionText, style: GoogleFonts.poppins(color: Colors.green, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildAksesCepat(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.8,
      children: [
        _buildAksesCepatItem(
          context: context,
          icon: Icons.description_outlined,
          label: 'Buat Surat',
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const PilihPermohonanPage()));
          }
        ),
        _buildAksesCepatItem(
          context: context,
          icon: Icons.history,
          label: 'Riwayat Saya',
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const RiwayatPermohonanPage()));
          }
        ),
      ],
    );
  }

  Widget _buildAksesCepatItem({required BuildContext context, required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200)
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.green),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTerbaru(BuildContext context, List<Berita> berita) {
    if (berita.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Belum ada info terbaru dari desa.'),
        )
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: berita.asMap().entries.map((entry) {
          int idx = entry.key;
          Berita news = entry.value;
          return Column(
            children: [
              ListTile(
                title: Text(news.judul, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('Dipublikasikan pada ${news.tanggal}'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NewsDetailPage(slug: news.slug),
                    ),
                  );
                },
              ),
              if (idx < berita.length - 1) const Divider(height: 1, indent: 16, endIndent: 16),
            ],
          );
        }).toList(),
      ),
    );
  }
}