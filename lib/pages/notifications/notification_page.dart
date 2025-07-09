import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/app_config.dart';

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
  final List<NotificationItem> initialNotifications;
  
  const NotificationPage({
    super.key,
    required this.initialNotifications
  });

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  late List<NotificationItem> _notificationItems; 
  late Map<String, List<NotificationItem>> _groupedNotifications;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _notificationItems = widget.initialNotifications;
    _groupedNotifications = _groupNotificationsByDate(_notificationItems);
  }

  Future<void> _fetchNotifications() async {
    setState(() { _isLoading = true; });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) {
        throw Exception('Sesi tidak valid.');
      }

      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/notifikasi'), 
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> body = data['data'] ?? [];
        
        setState(() {
          _notificationItems = body.map((item) => NotificationItem.fromJson(item)).toList();
          _groupedNotifications = _groupNotificationsByDate(_notificationItems);
        });
      } else {
        throw Exception('Gagal memuat notifikasi.');
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
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
  
  Future<void> _markAsRead(NotificationItem item) async {
    if (item.isRead) return;
    
    setState(() {
      item.isRead = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    http.put(
      Uri.parse('${AppConfig.apiBaseUrl}/notifikasi/baca/${item.id}'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
  }

  Future<void> _markAllAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return;
    
    await http.put(
      Uri.parse('${AppConfig.apiBaseUrl}/notifikasi/baca-semua'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    await _fetchNotifications();
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
          if (_notificationItems.any((item) => !item.isRead))
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all, size: 20),
              label: const Text('Tandai semua dibaca'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue.shade700,
                padding: const EdgeInsets.symmetric(horizontal: 16)
              ),
            )
        ],
      ),
      backgroundColor: const Color(0xFFF5F8FA),
      body: RefreshIndicator(
        onRefresh: _fetchNotifications,
        child: _isLoading && _notificationItems.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _notificationItems.isEmpty
              ? _buildEmptyState()
              : _buildNotificationList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          Icon(Icons.notifications_active_outlined, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Tidak Ada Notifikasi', 
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[600])
          ),
          const SizedBox(height: 8),
          Text(
            'Semua pemberitahuan penting dari desa\nakan muncul di sini.', 
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.grey[500])
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList() {
    final groupKeys = _groupedNotifications.keys.toList();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: groupKeys.length,
      itemBuilder: (context, index) {
        final String groupTitle = groupKeys[index];
        final List<NotificationItem> items = _groupedNotifications[groupTitle]!;
        return _buildNotificationGroup(groupTitle, items);
      },
    );
  }

  Widget _buildNotificationGroup(String title, List<NotificationItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title.toUpperCase(), 
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, 
              color: Colors.grey.shade600,
              fontSize: 12,
              letterSpacing: 0.8
            )
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: ListView.separated(
            itemCount: items.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildNotificationTile(item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationTile(NotificationItem item) {
    final isUnread = !item.isRead;
    return Material(
      color: isUnread ? Colors.blue.withOpacity(0.05) : Colors.transparent,
      child: InkWell(
        onTap: () => _markAsRead(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: _getIconBackgroundColor(item),
                child: Icon(_getIconForItem(item), color: _getIconColor(item), size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title, 
                      style: GoogleFonts.poppins(
                        fontWeight: isUnread ? FontWeight.bold : FontWeight.w600, 
                        fontSize: 15,
                        color: isUnread ? Colors.black87 : Colors.black54
                      )
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body, 
                      style: GoogleFonts.poppins(color: Colors.grey.shade700, fontSize: 14)
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat('HH:mm', 'id_ID').format(item.date), 
                      style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 12)
                    ),
                  ],
                ),
              ),
              if (isUnread) ...[
                const SizedBox(width: 12),
                Container(
                  width: 10, height: 10,
                  decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForItem(NotificationItem item) {
    String titleLower = item.title.toLowerCase();
    if (titleLower.contains('selesai')) return Icons.check_circle_outline;
    if (titleLower.contains('ditolak')) return Icons.highlight_off_outlined;
    if (titleLower.contains('diproses') || titleLower.contains('diverifikasi')) return Icons.hourglass_top_outlined;
    if (titleLower.contains('surat') || titleLower.contains('permohonan') || titleLower.contains('kk') || titleLower.contains('sk')) {
      return Icons.description_outlined;
    }
    return Icons.campaign_outlined;
  }
  
  Color _getIconColor(NotificationItem item) {
    String titleLower = item.title.toLowerCase();
      if (titleLower.contains('selesai')) return Colors.green.shade800;
    if (titleLower.contains('ditolak')) return Colors.red.shade800;
    if (titleLower.contains('diproses') || titleLower.contains('diverifikasi')) return Colors.blue.shade800;
    return Colors.orange.shade800;
  }
  
  Color _getIconBackgroundColor(NotificationItem item) {
    return _getIconColor(item).withOpacity(0.1);
  }
}