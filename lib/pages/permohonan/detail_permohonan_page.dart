// Lokasi: lib/pages/permohonan/detail_permohonan_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart'; 

import '../../core/config/app_config.dart';

class DetailPermohonanPage extends StatefulWidget {
  final int permohonanId;
  final String jenisSurat;

  const DetailPermohonanPage({
    super.key,
    required this.permohonanId,
    required this.jenisSurat,
  });

  @override
  State<DetailPermohonanPage> createState() => _DetailPermohonanPageState();
}

class _DetailPermohonanPageState extends State<DetailPermohonanPage> {
  late Future<Map<String, dynamic>> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = _fetchDetail();
  }

  // Fungsi untuk mengubah nama jenis surat menjadi format slug URL
  String _getSlugFromJenisSurat(String jenisSurat) {
    return jenisSurat
        .toLowerCase()
        .replaceAll(' ', '-')
        .replaceAll(RegExp(r'[^a-z0-9-]'), ''); // Membersihkan karakter invalid
  }

  // Fungsi untuk mengambil data detail dari API Laravel
  Future<Map<String, dynamic>> _fetchDetail() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) throw Exception('Sesi tidak valid. Silakan login ulang.');

    final slug = _getSlugFromJenisSurat(widget.jenisSurat);
    final url = '${AppConfig.apiBaseUrl}/permohonan/$slug/${widget.permohonanId}';

    final response = await http.get(Uri.parse(url), headers: {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
  
      throw Exception('Gagal memuat detail permohonan.');
    }
  }

  // Fungsi untuk membuka URL file di browser eksternal
  Future<void> _launchFileUrl(String filePath) async {
    final fullUrl = Uri.parse('${AppConfig.baseUrl}/storage/$filePath');
    if (!await launchUrl(fullUrl, mode: LaunchMode.externalApplication)) {
      throw 'Tidak bisa membuka file: $fullUrl';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detail Permohonan', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      backgroundColor: Colors.grey[100],
      body: FutureBuilder<Map<String, dynamic>>(
        future: _detailFuture,
        builder: (context, snapshot) {
          // Tampilan saat data sedang dimuat
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // Tampilan jika terjadi error
          if (snapshot.hasError) {
            return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('Error: ${snapshot.error}', textAlign: TextAlign.center)));
          }
          // Tampilan jika tidak ada data
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Tidak ada data detail.'));
          }

          // Jika data berhasil dimuat
          final data = snapshot.data!;
          final pemohon = data['masyarakat'] as Map<String, dynamic>? ?? {};

          final lampiranFields = {
            'File Kartu Keluarga': data['file_kk'],
            'File KTP Pemohon': data['file_ktp'],
            'Surat Pengantar RT/RW': data['surat_pengantar_rt_rw'],
            'Dokumen Pendukung': data['surat_keterangan_pendukung'],
            // Tambahkan key file lain dari JSON Anda jika ada
          };
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusCard(data['status'], data['catatan_penolakan'], data['tanggal_selesai_proses']),
                const SizedBox(height: 20),
                
                _buildSectionTitle('Informasi Permohonan', Icons.description_outlined),
                _buildDetailCard(
                  children: [
                    _buildDetailRow('Jenis Surat', widget.jenisSurat),
                    _buildDetailRow('Tanggal Pengajuan', data['created_at'] != null ? DateFormat('d MMMM yyyy, HH:mm', 'id_ID').format(DateTime.parse(data['created_at'])) : '-'),
                    if (data['catatan_pemohon'] != null && data['catatan_pemohon'].isNotEmpty)
                      _buildDetailRow('Catatan Anda', data['catatan_pemohon']),
                  ],
                ),
                const SizedBox(height: 20),
                
                _buildSectionTitle('Informasi Pemohon', Icons.person_outline),
                _buildDetailCard(
                  children: [
                    _buildDetailRow('Nama Lengkap', pemohon['nama_lengkap'] ?? '-'),
                    _buildDetailRow('NIK', pemohon['nik'] ?? '-'),
                    _buildDetailRow('Nomor HP', pemohon['nomor_hp'] ?? '-'),
                    _buildDetailRow('Alamat', pemohon['alamat_lengkap'] ?? '-'),
                  ],
                ),
                const SizedBox(height: 20),

                _buildSectionTitle('Lampiran Anda', Icons.attach_file),
                _buildDetailCard(
                  children: lampiranFields.entries
                    .where((entry) => entry.value != null && entry.value.toString().isNotEmpty)
                    .map((entry) => _buildLampiranTile(entry.key, entry.value))
                    .toList(),
                ),
                const SizedBox(height: 24),

                // Tombol download akan muncul di sini jika syarat terpenuhi
                if (data['status'] == 'selesai' && data['file_hasil_akhir'] != null)
                  _buildDownloadButton(data['file_hasil_akhir']),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- WIDGET-WIDGET PEMBANTU UNTUK UI YANG LEBIH BAIK ---

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 8),
          Text(title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
        ],
      ),
    );
  }

  Widget _buildDetailCard({required List<Widget> children}) {
    // Jika tidak ada children, jangan tampilkan kartu
    if (children.isEmpty) return const SizedBox.shrink();
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200)
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.poppins(color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(value ?? '-', style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildLampiranTile(String label, String filePath) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.insert_drive_file_outlined, color: Colors.black54),
          title: Text(label, style: GoogleFonts.poppins()),
          trailing: const Icon(Icons.visibility_outlined, color: Colors.blue),
          onTap: () async {
            try {
              await _launchFileUrl(filePath);
            } catch (e) {
              if(mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString()))
                );
              }
            }
          },
        ),
        const Divider(height: 1),
      ],
    );
  }
  
  Widget _buildStatusCard(String? status, String? catatanPenolakan, String? tanggalSelesai) {
    String statusText;
    String statusSubtitle;
    Color cardColor;
    IconData statusIcon;

    switch (status) {
      case 'pending':
        statusText = 'Berhasil Diajukan';
        statusSubtitle = 'Permohonan Anda sedang menunggu verifikasi oleh petugas.';
        cardColor = Colors.blue.shade50;
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case 'diproses':
        statusText = 'Sedang Diproses';
        statusSubtitle = 'Permohonan Anda sedang dikerjakan oleh petugas.';
        cardColor = Colors.orange.shade50;
        statusIcon = Icons.sync;
        break;
      case 'selesai':
        statusText = 'Permohonan Selesai';
        statusSubtitle = 'Selesai pada: ${tanggalSelesai != null ? DateFormat('d MMMM yyyy', 'id_ID').format(DateTime.parse(tanggalSelesai)) : '-'}';
        cardColor = Colors.green.shade50;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'ditolak':
        statusText = 'Permohonan Ditolak';
        statusSubtitle = 'Ditolak pada: ${tanggalSelesai != null ? DateFormat('d MMMM yyyy', 'id_ID').format(DateTime.parse(tanggalSelesai)) : '-'}';
        cardColor = Colors.red.shade50;
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusText = 'Status Tidak Diketahui';
        statusSubtitle = 'Silakan hubungi petugas.';
        cardColor = Colors.grey.shade200;
        statusIcon = Icons.help_outline_rounded;
    }

    return Card(
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, size: 32, color: Colors.black.withAlpha(128)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(statusText, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(statusSubtitle, style: GoogleFonts.poppins(color: Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
            if (status == 'ditolak' && catatanPenolakan != null && catatanPenolakan.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(128),
                  borderRadius: BorderRadius.circular(8)
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Alasan Penolakan:", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(catatanPenolakan, style: GoogleFonts.poppins()),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadButton(String filePath) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.download_for_offline_outlined),
        label: const Text('Unduh Berkas Hasil Akhir'),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white, 
          backgroundColor: Colors.green,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () async {
          try {
            await _launchFileUrl(filePath);
          } catch (e) {
            if(mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Gagal membuka file: ${e.toString()}'))
              );
            }
          }
        },
      ),
    );
  }
}