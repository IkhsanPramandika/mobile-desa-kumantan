// Lokasi: lib/pages/permohonan/riwayat_page.dart

import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import 'detail_permohonan_page.dart'; // Pastikan Anda sudah membuat file ini

// Model Riwayat (sudah diperbarui untuk menerima namaPemohon)
class Riwayat {
  final int id;
  final String jenisSurat;
  final String tanggal;
  final String status;
  final String namaPemohon;
  final String estimasiSelesai;

  Riwayat({
    required this.id,
    required this.jenisSurat,
    required this.tanggal,
    required this.status,
    required this.namaPemohon,
    required this.estimasiSelesai,
  });

  factory Riwayat.fromJson(Map<String, dynamic> json) {
    return Riwayat(
      id: json['id'] ?? 0,
      jenisSurat: json['jenis_surat'] ?? 'Permohonan Tidak Diketahui',
      tanggal: json['tanggal'] ?? '-',
      status: json['status'] ?? 'unknown',
      namaPemohon: json['nama_pemohon'] ?? 'Warga',
      estimasiSelesai: json['estimasi_selesai'] ?? '-',
    );
  }
}

class RiwayatPermohonanPage extends StatefulWidget {
  const RiwayatPermohonanPage({super.key});

  @override
  State<RiwayatPermohonanPage> createState() => _RiwayatPermohonanPageState();
}

class _RiwayatPermohonanPageState extends State<RiwayatPermohonanPage>
    with TickerProviderStateMixin {
  // State untuk data
  List<Riwayat> _semuaRiwayat = [];
  List<Riwayat> _riwayatTersaring = [];
  bool _isLoading = true;
  String? _error;

  // State untuk filter
  String? _filterJenisSurat;
  DateTimeRange? _filterTanggal;
  final List<String> _opsiJenisSurat = [
    'Permohonan KK Baru',
    'Perubahan Data KK',
    'Permohonan KK Hilang',
    'SK Ahli Waris',
    'SK Kelahiran',
    'SK Domisili',
    'SK Perkawinan',
    'SK Tidak Mampu',
    'SK Usaha',
  ];

  StreamSubscription? _fcmSubscription;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchRiwayat();
    _setupFcmListener();
  }

  @override
  void dispose() {
    _fcmSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _setupFcmListener() {
    _fcmSubscription =
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (mounted) {
        _fetchRiwayat();
      }
    });
  }

  Future<void> _fetchRiwayat() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null)
        throw Exception('Sesi tidak valid. Silakan login ulang.');

      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/riwayat-semua-permohonan'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token'
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> body = responseData['data'] ?? [];
        final List<Riwayat> riwayatList =
            body.map((dynamic item) => Riwayat.fromJson(item)).toList();

        setState(() {
          _semuaRiwayat = riwayatList;
          _applyFilters();
          _isLoading = false;
        });
      } else {
        throw Exception(
            'Gagal memuat riwayat (Status: ${response.statusCode})');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    List<Riwayat> filtered = List.from(_semuaRiwayat);

    if (_filterJenisSurat != null) {
      filtered =
          filtered.where((r) => r.jenisSurat == _filterJenisSurat).toList();
    }

    if (_filterTanggal != null) {
      filtered = filtered.where((r) {
        try {
          final itemDate =
              DateFormat('d MMMM yyyy, HH:mm', 'id_ID').parse(r.tanggal);
          final startDate = DateTime(_filterTanggal!.start.year,
              _filterTanggal!.start.month, _filterTanggal!.start.day);
          final endDate = DateTime(_filterTanggal!.end.year,
                  _filterTanggal!.end.month, _filterTanggal!.end.day)
              .add(const Duration(days: 1));
          return itemDate.isAfter(startDate) && itemDate.isBefore(endDate);
        } catch (e) {
          return false;
        }
      }).toList();
    }

    setState(() {
      _riwayatTersaring = filtered;
    });
  }

  void _showFilterDialog() {
    // Gunakan state sementara di dalam dialog agar perubahan tidak langsung diterapkan
    String? tempJenisSurat = _filterJenisSurat;
    DateTimeRange? tempTanggal = _filterTanggal;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        // StatefulBuilder diperlukan agar UI di dalam dialog bisa di-update
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Filter Riwayat',
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: tempJenisSurat,
                  decoration: const InputDecoration(
                      labelText: 'Jenis Surat', border: OutlineInputBorder()),
                  hint: const Text('Semua Jenis Surat'),
                  items: _opsiJenisSurat.map((String value) {
                    return DropdownMenuItem<String>(
                        value: value, child: Text(value));
                  }).toList(),
                  onChanged: (value) =>
                      setDialogState(() => tempJenisSurat = value),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(tempTanggal == null
                      ? 'Pilih Rentang Tanggal'
                      : '${DateFormat('d/M/y').format(tempTanggal!.start)} - ${DateFormat('d/M/y').format(tempTanggal!.end)}'),
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialDateRange: tempTanggal,
                    );
                    if (picked != null) {
                      setDialogState(() => tempTanggal = picked);
                    }
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        child: const Text('Reset'),
                        onPressed: () {
                          setDialogState(() {
                            tempJenisSurat = null;
                            tempTanggal = null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green),
                        child: const Text('Terapkan',
                            style: TextStyle(color: Colors.white)),
                        onPressed: () {
                          setState(() {
                            _filterJenisSurat = tempJenisSurat;
                            _filterTanggal = tempTanggal;
                            _applyFilters();
                          });
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Riwayat Permohonan',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.poppins(),
          tabs: const [
            Tab(text: 'DALAM PROSES'),
            Tab(text: 'SELESAI'),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      // Tampilan loading shimmer yang lebih baik
      return ListView.builder(
        itemCount: 8,
        itemBuilder: (context, index) => const _ShimmerCard(),
      );
    }
    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }

    final prosesList = _riwayatTersaring
        .where((r) => r.status == 'pending' || r.status == 'diproses')
        .toList();
    final selesaiList = _riwayatTersaring
        .where((r) => r.status == 'selesai' || r.status == 'ditolak')
        .toList();

    return TabBarView(
      controller: _tabController,
      children: [
        _RiwayatListView(
            riwayatList: prosesList,
            onRefresh: _fetchRiwayat,
            emptyMessage: 'Tidak ada permohonan yang sedang diproses.'),
        _RiwayatListView(
            riwayatList: selesaiList,
            onRefresh: _fetchRiwayat,
            emptyMessage: 'Belum ada riwayat permohonan yang selesai.'),
      ],
    );
  }
}

// Widget untuk daftar riwayat
class _RiwayatListView extends StatelessWidget {
  final List<Riwayat> riwayatList;
  final String emptyMessage;
  final Future<void> Function() onRefresh;

  const _RiwayatListView(
      {required this.riwayatList,
      required this.emptyMessage,
      required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: riwayatList.isEmpty
          ? Center(
              child: ListView(
                // Dibungkus agar bisa di-refresh saat kosong
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                  Icon(Icons.folder_off_outlined,
                      size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(emptyMessage,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(color: Colors.grey[500])),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: riwayatList.length,
              itemBuilder: (context, index) {
                final riwayat = riwayatList[index];
                return _RiwayatCard(riwayat: riwayat);
              },
            ),
    );
  }
}

// Widget untuk kartu riwayat
class _RiwayatCard extends StatelessWidget {
  final Riwayat riwayat;
  const _RiwayatCard({required this.riwayat});

  Widget _buildStatusChip(String status) {
    Color chipColor;
    String chipLabel;
    IconData? chipIcon;
    switch (status) {
      case 'pending':
        chipColor = Colors.orange.shade100;
        chipLabel = 'Diajukan';
        chipIcon = Icons.hourglass_top_rounded;
        break;
      case 'diproses':
        chipColor = Colors.blue.shade100;
        chipLabel = 'Diproses';
        chipIcon = Icons.sync;
        break;
      case 'selesai':
        chipColor = Colors.green.shade100;
        chipLabel = 'Selesai';
        chipIcon = Icons.check_circle;
        break;
      case 'ditolak':
        chipColor = Colors.red.shade100;
        chipLabel = 'Ditolak';
        chipIcon = Icons.cancel;
        break;
      default:
        chipColor = Colors.grey.shade200;
        chipLabel = 'Tidak Diketahui';
        chipIcon = Icons.help_outline;
    }
    return Chip(
      avatar: Icon(chipIcon,
          size: 16,
          color: chipColor.computeLuminance() > 0.5
              ? Colors.black87
              : Colors.black87),
      label: Text(chipLabel,
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: chipColor.computeLuminance() > 0.5
                  ? Colors.black87
                  : Colors.black87)),
      backgroundColor: chipColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Menentukan apakah statusnya masih dalam proses untuk menampilkan estimasi
    final bool isInProcess =
        riwayat.status == 'pending' || riwayat.status == 'diproses';

    return Card(
      elevation: 2,
      shadowColor: Colors.grey.withAlpha(128),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // Navigasi ke halaman detail
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetailPermohonanPage(
                  permohonanId: riwayat.id, jenisSurat: riwayat.jenisSurat),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bagian Judul dan Status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(riwayat.jenisSurat,
                            style: GoogleFonts.poppins(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Oleh: ${riwayat.namaPemohon}',
                            style: GoogleFonts.poppins(
                                fontSize: 13, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                  _buildStatusChip(riwayat.status),
                ],
              ),
              const Divider(height: 24),

              // Bagian Tanggal Pengajuan
              Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text('Diajukan: ${riwayat.tanggal}',
                      style: GoogleFonts.poppins(
                          color: Colors.grey.shade700, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 6),

              // [FITUR BARU] Menampilkan estimasi selesai HANYA jika status masih dalam proses
              if (isInProcess)
                Row(
                  children: [
                    Icon(Icons.timelapse,
                        size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'Estimasi Selesai: ${riwayat.estimasiSelesai}',
                      style: GoogleFonts.poppins(
                          color: Colors.grey.shade700, fontSize: 13),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// [BARU] Widget untuk tampilan loading shimmer
class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(128),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
