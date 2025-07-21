// Lokasi: lib/pages/permohonan/riwayat_permohonan_page.dart

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
import 'form_permohonan_page.dart';

// Kelas helper untuk warna, agar konsisten
class AppColors {
  static final Color primaryColor = Colors.blue.shade800;
  static final Color lightGrey = Colors.grey.shade200;
  static final Color darkGrey = Colors.grey.shade800;
  static final Color mediumGrey = Colors.grey.shade600;
}

// Model untuk data riwayat permohonan
class Riwayat {
  final int id;
  final String jenisSurat;
  final String jenisSuratSlug;
  final String tanggal;
  final String status;
  final String namaPemohon;
  final String estimasiSelesai;
  final Map<String, dynamic> fullData;
  // [PERUBAHAN] Tambahkan field untuk catatan penolakan
  final String? catatanPenolakan;

  Riwayat({
    required this.id,
    required this.jenisSurat,
    required this.jenisSuratSlug,
    required this.tanggal,
    required this.status,
    required this.namaPemohon,
    required this.estimasiSelesai,
    required this.fullData,
    this.catatanPenolakan, // [PERUBAHAN] Jadikan opsional
  });

  factory Riwayat.fromJson(Map<String, dynamic> json) {
    return Riwayat(
      id: json['id'] ?? 0,
      jenisSurat: json['jenis_surat'] ?? 'Permohonan Tidak Diketahui',
      jenisSuratSlug: json['jenis_surat_slug'] ?? '',
      tanggal: json['tanggal'] ?? '-',
      status: json['status'] ?? 'unknown',
      namaPemohon: json['nama_pemohon'] ?? 'Warga',
      estimasiSelesai: json['estimasi_selesai'] ?? '-',
      fullData: json,
      // [PERUBAHAN] Ambil catatan penolakan dari JSON
      catatanPenolakan: json['catatan_penolakan'],
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
    // [PERUBAHAN] Tambahkan 1 tab baru untuk "Perlu Revisi", total menjadi 6
    _tabController = TabController(length: 6, vsync: this);
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
        // Muat ulang data jika ada notifikasi baru masuk saat halaman terbuka
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
        Uri.parse(
            '${AppConfig.apiBaseUrl}/masyarakat/riwayat-semua-permohonan'),
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
          _applyFilters(); // Terapkan filter yang mungkin sudah ada
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
                    prefixIcon: Icon(Icons.description_outlined,
                        color: AppColors.mediumGrey),
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
                      textStyle:
                          GoogleFonts.poppins(fontWeight: FontWeight.w600),
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
                        child: const Text('Reset'),
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
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold)),
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
          isScrollable: true,
          // [PERBAIKAN] Warna teks tab diubah menjadi putih
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.8),
          tabs: const [
            Tab(text: 'DRAFT'),
            Tab(text: 'PENDING'),
            // [PERUBAHAN] Tambahkan tab "PERLU REVISI"
            Tab(text: 'PERLU REVISI'),
            Tab(text: 'DIPROSES'),
            Tab(text: 'SELESAI'),
            Tab(text: 'DITOLAK'),
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
      return Center(
          child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text('Error: $_error', textAlign: TextAlign.center),
      ));
    }

    final draftList =
        _riwayatTersaring.where((r) => r.status == 'draft').toList();
    final pendingList =
        _riwayatTersaring.where((r) => r.status == 'pending').toList();
    // [PERUBAHAN] Buat list untuk status revisi
    final revisiList = _riwayatTersaring
        .where((r) => r.status == 'membutuhkan_revisi')
        .toList();
    final diprosesList = _riwayatTersaring
        .where((r) => r.status == 'diterima' || r.status == 'diproses')
        .toList();
    final selesaiList =
        _riwayatTersaring.where((r) => r.status == 'selesai').toList();
    final ditolakList =
        _riwayatTersaring.where((r) => r.status == 'ditolak').toList();

    return TabBarView(
      controller: _tabController,
      children: [
        _RiwayatListView(
            riwayatList: draftList,
            onRefresh: _fetchRiwayat,
            emptyMessage: 'Tidak ada draft permohonan yang tersimpan.'),
        _RiwayatListView(
            riwayatList: pendingList,
            onRefresh: _fetchRiwayat,
            emptyMessage: 'Tidak ada permohonan yang menunggu persetujuan.'),
        // [PERUBAHAN] Tambahkan view untuk tab revisi
        _RiwayatListView(
            riwayatList: revisiList,
            onRefresh: _fetchRiwayat,
            emptyMessage: 'Tidak ada permohonan yang perlu direvisi.'),
        _RiwayatListView(
            riwayatList: diprosesList,
            onRefresh: _fetchRiwayat,
            emptyMessage: 'Tidak ada permohonan yang sedang diproses.'),
        _RiwayatListView(
            riwayatList: selesaiList,
            onRefresh: _fetchRiwayat,
            emptyMessage: 'Belum ada riwayat permohonan yang selesai.'),
        _RiwayatListView(
            riwayatList: ditolakList,
            onRefresh: _fetchRiwayat,
            emptyMessage: 'Tidak ada permohonan yang ditolak.'),
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
                  padding: EdgeInsets.only(
                      top: MediaQuery.of(context).size.height * 0.2),
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
                return _RiwayatCard(riwayat: riwayat, onUpdate: onRefresh);
              },
            ),
    );
  }
}

class _RiwayatCard extends StatelessWidget {
  final Riwayat riwayat;
  final VoidCallback onUpdate;
  const _RiwayatCard({required this.riwayat, required this.onUpdate});

  void _navigateToForm(BuildContext context) async {
    if (riwayat.jenisSuratSlug.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Error: Jenis surat tidak valid untuk draft ini.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FormPermohonanPage(
          jenisSurat: riwayat.jenisSuratSlug,
          pageTitle: 'Lanjutkan Draft',
          initialData: riwayat.fullData,
          draftId: riwayat.id,
        ),
      ),
    );
    if (result == true) {
      onUpdate();
    }
  }

  // [PERUBAHAN] Fungsi navigasi untuk revisi
  void _navigateToRevisiForm(BuildContext context) async {
    if (riwayat.jenisSuratSlug.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Error: Jenis surat tidak valid untuk direvisi.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FormPermohonanPage(
          jenisSurat: riwayat.jenisSuratSlug,
          pageTitle: 'Revisi Permohonan',
          initialData: riwayat.fullData,
          // [PERUBAHAN] Kirim ID permohonan yang akan direvisi
          revisiId: riwayat.id,
          catatanPenolakan: riwayat.catatanPenolakan,
        ),
      ),
    );
    if (result == true) {
      onUpdate();
    }
  }

  void _deleteDraft(BuildContext context) async {
    if (riwayat.jenisSuratSlug.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Error: Gagal menghapus, jenis surat tidak valid.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Draft?'),
        content: const Text('Apakah Anda yakin ingin menghapus draft ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Hapus', style: TextStyle(color: Colors.red.shade700)),
          ),
        ],
      ),
    );

    if (confirmDelete != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final uri = Uri.parse(
          '${AppConfig.apiBaseUrl}/masyarakat/draft/${riwayat.jenisSuratSlug}/${riwayat.id}');

      final response = await http.delete(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token'
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Draft berhasil dihapus.'),
          backgroundColor: Colors.green,
        ));
        onUpdate();
      } else {
        throw Exception('Gagal menghapus draft');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: ${e.toString()}'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Widget _buildStatusChip(String status) {
    Color bgColor, fgColor;
    IconData icon;
    String label = status;

    switch (status) {
      case 'draft':
        bgColor = Colors.grey.shade200;
        fgColor = Colors.grey.shade800;
        icon = Icons.edit_note_rounded;
        label = 'Draft';
        break;
      case 'pending':
        bgColor = Colors.orange.shade50;
        fgColor = Colors.orange.shade800;
        icon = Icons.hourglass_top_rounded;
        label = 'Pending';
        break;
      // [PERUBAHAN] Tambahkan case untuk status revisi
      case 'membutuhkan_revisi':
        bgColor = Colors.yellow.shade100;
        fgColor = Colors.yellow.shade900;
        icon = Icons.edit_rounded;
        label = 'Perlu Revisi';
        break;
      case 'diterima':
      case 'diproses':
        bgColor = Colors.blue.shade50;
        fgColor = Colors.blue.shade800;
        icon = Icons.sync;
        label = 'Diproses';
        break;
      case 'selesai':
        bgColor = Colors.green.shade50;
        fgColor = Colors.green.shade800;
        icon = Icons.check_circle_rounded;
        label = 'Selesai';
        break;
      case 'ditolak':
        bgColor = Colors.red.shade50;
        fgColor = Colors.red.shade800;
        icon = Icons.cancel_rounded;
        label = 'Ditolak';
        break;
      default:
        bgColor = Colors.grey.shade200;
        fgColor = Colors.grey.shade800;
        icon = Icons.help_outline_rounded;
        label = 'Tidak Diketahui';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(20)),
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
    final bool isDraft = riwayat.status == 'draft';
    // [PERUBAHAN] Tambahkan flag untuk status revisi
    final bool perluRevisi = riwayat.status == 'membutuhkan_revisi';
    final bool isInProcess = riwayat.status == 'pending' ||
        riwayat.status == 'diproses' ||
        riwayat.status == 'diterima';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.lightGrey),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: isDraft || perluRevisi
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetailPermohonanPage(
                        permohonanId: riwayat.id,
                        jenisSuratSlug: riwayat.jenisSuratSlug),
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
              _buildInfoRow(
                  Icons.person_outline, 'Oleh: ${riwayat.namaPemohon}'),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.calendar_today_outlined,
                  'Diajukan: ${riwayat.tanggal}'),
              if (isInProcess && riwayat.estimasiSelesai != '-') ...[
                const SizedBox(height: 8),
                _buildInfoRow(Icons.timelapse_rounded,
                    'Estimasi Selesai: ${riwayat.estimasiSelesai}'),
              ],
              if (isDraft) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Hapus'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            side: BorderSide(color: Colors.red.shade200)),
                        onPressed: () => _deleteDraft(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Lanjutkan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _navigateToForm(context),
                      ),
                    )
                  ],
                )
              ],
              // [PERUBAHAN] Tampilkan tombol revisi jika statusnya 'membutuhkan_revisi'
              if (perluRevisi) ...[
                const Divider(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.edit_document),
                  label: const Text('Revisi Sekarang'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)
                    )
                  ),
                  onPressed: () => _navigateToRevisiForm(context),
                )
              ]
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
