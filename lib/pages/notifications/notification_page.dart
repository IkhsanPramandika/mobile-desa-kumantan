// Lokasi: lib/pages/notifications/notification_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/app_config.dart';

// Model untuk data notifikasi dari API
class NotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime date;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.date,
    this.isRead = false,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? {};
    return NotificationItem(
      id: json['id'] ?? '',
      title: data['title'] ?? 'Tanpa Judul',
      body: data['message'] ?? 'Tidak ada isi.',
      date: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      isRead: json['read_at'] != null,
    );
  }
}

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  late Future<Map<String, List<NotificationItem>>> _groupedNotificationsFuture;

  @override
  void initState() {
    super.initState();
    _groupedNotificationsFuture = _fetchAndGroupNotifications();
  }

  Future<Map<String, List<NotificationItem>>> _fetchAndGroupNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      throw Exception('Sesi tidak valid. Silakan login ulang.');
    }

    // Menggunakan endpoint GET /notifikasi
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/api/notifikasi'), 
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(response.body);
      final List<NotificationItem> items = body.map((item) => NotificationItem.fromJson(item)).toList();
      return _groupNotificationsByDate(items);
    } else {
      throw Exception('Gagal memuat notifikasi.');
    }
  }

  Map<String, List<NotificationItem>> _groupNotificationsByDate(List<NotificationItem> notifications) {
    final Map<String, List<NotificationItem>> grouped = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var item in notifications) {
      final itemDate = DateTime(item.date.year, item.date.month, item.date.day);
      String groupKey;
      if (itemDate == today) {
        groupKey = 'Hari Ini';
      } else if (itemDate == yesterday) {
        groupKey = 'Kemarin';
      } else {
        groupKey = DateFormat('d MMMM yyyy', 'id_ID').format(item.date);
      }
      (grouped[groupKey] ??= []).add(item);
    }
    return grouped;
  }

  // Implementasi lengkap dengan API call
  Future<void> _markAsRead(NotificationItem item) async {
    if (item.isRead) return;
    
    // Optimistic UI update
    setState(() {
      item.isRead = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    // Kirim request ke server di latar belakang
    await http.put(
      Uri.parse('${AppConfig.baseUrl}/api/notifikasi/baca/${item.id}'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
  }

  // Implementasi lengkap dengan API call
  Future<void> _markAllAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return;
    
    await http.put(
      Uri.parse('${AppConfig.baseUrl}/api/notifikasi/baca-semua'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    // Muat ulang data setelah berhasil
    _refresh();
  }
  
  // Fungsi untuk memuat ulang notifikasi (untuk pull-to-refresh)
  Future<void> _refresh() async {
    setState(() {
      _groupedNotificationsFuture = _fetchAndGroupNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifikasi', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          // PERBAIKAN UI: Menggunakan TextButton.icon
          TextButton.icon(
            onPressed: _markAllAsRead,
            icon: const Icon(Icons.done_all, size: 20),
            label: const Text('Tandai semua dibaca'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.green.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 16)
            ),
          )
        ],
      ),
      backgroundColor: Colors.grey[100],
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<Map<String, List<NotificationItem>>>(
          future: _groupedNotificationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error: ${snapshot.error}', textAlign: TextAlign.center,),
              ));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: ListView( // Dibungkus agar bisa di-refresh
                  children: [
                     SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                     Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey[300]),
                     const SizedBox(height: 16),
                     Text('Tidak ada notifikasi baru', style: GoogleFonts.poppins(color: Colors.grey[500])),
                  ],
                ),
              );
            }

            final groupedNotifications = snapshot.data!;
            final groupKeys = groupedNotifications.keys.toList();

            return ListView.builder(
              itemCount: groupKeys.length,
              itemBuilder: (context, index) {
                final String groupTitle = groupKeys[index];
                final List<NotificationItem> items = groupedNotifications[groupTitle]!;
                return _buildNotificationGroup(groupTitle, items);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildNotificationGroup(String title, List<NotificationItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
        ),
        ListView.separated(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          separatorBuilder: (context, index) => const Divider(height: 1, indent: 72, endIndent: 16),
          itemBuilder: (context, index) {
            final item = items[index];
            return _buildNotificationTile(item);
          },
        ),
      ],
    );
  }

  Widget _buildNotificationTile(NotificationItem item) {
    final isUnread = !item.isRead;
    return Material(
      color: isUnread ? Colors.green.withAlpha(20) : Colors.white,
      child: InkWell(
        onTap: () => _markAsRead(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: _getIconBackgroundColor(item),
                    child: Icon(_getIconForItem(item), color: _getIconColor(item)),
                  ),
                  if (isUnread)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(item.body, style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat('HH:mm', 'id_ID').format(item.date), 
                      style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 12)
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // PERBAIKAN: Fungsi ini sekarang memeriksa judul notifikasi untuk menentukan ikon
  IconData _getIconForItem(NotificationItem item) {
    String titleLower = item.title.toLowerCase();
    if (titleLower.contains('selesai')) return Icons.check_circle_outline;
    if (titleLower.contains('ditolak')) return Icons.highlight_off_outlined;
    if (titleLower.contains('diproses')) return Icons.hourglass_top_outlined;
    if (titleLower.contains('surat') || titleLower.contains('permohonan') || titleLower.contains('kk') || titleLower.contains('sk')) {
      return Icons.description_outlined;
    }
    return Icons.campaign_outlined; // Default untuk pengumuman
  }

  Color _getIconColor(NotificationItem item) {
    String titleLower = item.title.toLowerCase();
     if (titleLower.contains('selesai')) return Colors.green.shade800;
    if (titleLower.contains('ditolak')) return Colors.red.shade800;
    if (titleLower.contains('diproses')) return Colors.blue.shade800;
    return Colors.orange.shade800;
  }
  
  Color _getIconBackgroundColor(NotificationItem item) {
    return _getIconColor(item).withAlpha(40);
  }
}
