import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/config/app_config.dart';
import 'detail_permohonan_page.dart';

class AppColors {
  static final Color primaryColor = Colors.blue.shade800;
  static final Color lightGrey = Colors.grey.shade200;
  static final Color darkGrey = Colors.grey.shade800;
  static final Color mediumGrey = Colors.grey.shade600;
}

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
  List<Riwayat> _semuaRiwayat = [];
  List<Riwayat> _riwayatTersaring = [];
  bool _isLoading = true;
  String? _error;
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

      if (token == null) {
        throw Exception('Sesi tidak valid. Silakan login ulang.');
      }

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
    String? tempJenisSurat = _filterJenisSurat;
    DateTimeRange? tempTanggal = _filterTanggal;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
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
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  value: tempJenisSurat,
                  decoration: InputDecoration(
                    labelText: 'Jenis Surat',
                    hintText: 'Pilih jenis surat',
                    prefixIcon:
                        Icon(Icons.description_outlined, color: AppColors.mediumGrey),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                  items: _opsiJenisSurat.map((String value) {
                    return DropdownMenuItem<String>(
                        value: value, child: Text(value));
                  }).toList(),
                  onChanged: (value) =>
                      setDialogState(() => tempJenisSurat = value),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(tempTanggal == null
                      ? 'Pilih Rentang Tanggal'
                      : '${DateFormat('d MMM y', 'id_ID').format(tempTanggal!.start)} - ${DateFormat('d MMM y', 'id_ID').format(tempTanggal!.end)}'),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: AppColors.lightGrey)),
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDateRange: tempTanggal,
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(
                                primary: AppColors.primaryColor,
                                onPrimary: Colors.white,
                              ),
                            ),
                            child: child!,
                          );
                        });
                    if (picked != null) {
                      setDialogState(() => tempTanggal = picked);
                    }
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        child: const Text('Reset'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          foregroundColor: AppColors.mediumGrey,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
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
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Terapkan',
                            style:
                                GoogleFonts.poppins(fontWeight: FontWeight.bold)),
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
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: _showFilterDialog,
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.yellowAccent,
          indicatorWeight: 3.5,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.poppins(),
          tabs: const [
            Tab(text: 'DALAM PROSES'),
            Tab(text: 'SELESAI'),
          ],
        ),
      ),
      backgroundColor: Colors.grey[100],
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
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
      color: AppColors.primaryColor,
      child: riwayatList.isEmpty
          ? Center(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding:
                      EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined,
                          size: 80, color: Colors.grey[350]),
                      const SizedBox(height: 16),
                      Text(emptyMessage,
                          textAlign: TextAlign.center,
                          style:
                              GoogleFonts.poppins(color: AppColors.mediumGrey)),
                    ],
                  ),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: riwayatList.length,
              itemBuilder: (context, index) {
                final riwayat = riwayatList[index];
                return _RiwayatCard(riwayat: riwayat);
              },
            ),
    );
  }
}

class _RiwayatCard extends StatelessWidget {
  final Riwayat riwayat;
  const _RiwayatCard({required this.riwayat});

  Widget _buildStatusChip(String status) {
    Color bgColor, fgColor;
    IconData icon;

    switch (status) {
      case 'pending':
        bgColor = Colors.orange.shade50;
        fgColor = Colors.orange.shade800;
        icon = Icons.hourglass_top_rounded;
        break;
      case 'diproses':
        bgColor = Colors.blue.shade50;
        fgColor = Colors.blue.shade800;
        icon = Icons.sync;
        break;
      case 'selesai':
        bgColor = Colors.green.shade50;
        fgColor = Colors.green.shade800;
        icon = Icons.check_circle_rounded;
        break;
      case 'ditolak':
        bgColor = Colors.red.shade50;
        fgColor = Colors.red.shade800;
        icon = Icons.cancel_rounded;
        break;
      default:
        bgColor = Colors.grey.shade200;
        fgColor = Colors.grey.shade800;
        icon = Icons.help_outline_rounded;
    }

    final label = status[0].toUpperCase() + status.substring(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration:
          BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fgColor),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, fontSize: 12, color: fgColor)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.mediumGrey),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: GoogleFonts.poppins(
                    color: AppColors.mediumGrey, fontSize: 13))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isInProcess =
        riwayat.status == 'pending' || riwayat.status == 'diproses';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.lightGrey),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetailPermohonanPage(
                  permohonanId: riwayat.id, jenisSurat: riwayat.jenisSurat),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(riwayat.jenisSurat,
                        style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkGrey)),
                  ),
                  const SizedBox(width: 12),
                  _buildStatusChip(riwayat.status),
                ],
              ),
              const SizedBox(height: 12),
              _buildInfoRow(Icons.person_outline, 'Oleh: ${riwayat.namaPemohon}'),
              const SizedBox(height: 8),
              _buildInfoRow(
                  Icons.calendar_today_outlined, 'Diajukan: ${riwayat.tanggal}'),
              if (isInProcess && riwayat.estimasiSelesai != '-') ...[
                const SizedBox(height: 8),
                _buildInfoRow(Icons.timelapse_rounded,
                    'Estimasi Selesai: ${riwayat.estimasiSelesai}'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(width: 180, height: 20, color: Colors.white),
                Container(
                    width: 80,
                    height: 24,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20))),
              ],
            ),
            const SizedBox(height: 16),
            Container(width: 150, height: 14, color: Colors.white),
            const SizedBox(height: 8),
            Container(width: 200, height: 14, color: Colors.white),
          ],
        ),
      ),
    );
  }
}