import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';

class AppColors {
  static final Color primaryColor = Colors.blue.shade800;
  static final Color lightGrey = Colors.grey.shade200;
  static final Color darkGrey = Colors.grey.shade800;
  static final Color mediumGrey = Colors.grey.shade600;
}

class DetailPermohonanPage extends StatefulWidget {
  final int permohonanId;
  final String jenisSuratSlug;

  const DetailPermohonanPage({
    super.key,
    required this.permohonanId,
    required this.jenisSuratSlug,
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

  Future<Map<String, dynamic>> _fetchDetail() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) {
      throw Exception('Sesi tidak valid. Silakan login ulang.');
    }

    final url =
        '${AppConfig.apiBaseUrl}/masyarakat/permohonan/${widget.jenisSuratSlug}/${widget.permohonanId}';

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
        title: Text('Detail Permohonan',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.grey[100],
      body: FutureBuilder<Map<String, dynamic>>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child:
                    CircularProgressIndicator(color: AppColors.primaryColor));
          }
          if (snapshot.hasError) {
            return Center(
                child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('Error: ${snapshot.error}',
                        textAlign: TextAlign.center)));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Tidak ada data detail.'));
          }

          final data = snapshot.data!;
          final pemohon = data['masyarakat'] as Map<String, dynamic>? ?? {};

          final lampiranFields = {
            'File Kartu Keluarga': data['file_kk'],
            'File KK Lama (u/ Perubahan Data)': data['file_kk_lama'],
            'File KTP': data['file_ktp'],
            'Surat Pengantar RT/RW': data['surat_pengantar_rt_rw'],
            'Dokumen Pendukung Perubahan Data':
                data['surat_keterangan_pendukung'],
            'Surat Kehilangan Kepolisian':
                data['surat_keterangan_hilang_kepolisian'],
            'Buku Nikah / Akta Cerai': data['buku_nikah_akta_cerai'],
            'Surat Pindah Datang': data['surat_pindah_datang'],
            'Ijazah Terakhir': data['ijazah_terakhir'],
            'KTP Pemohon (Ahli Waris)':
                data['file_ktp_pemohon'], // Jadikan lebih spesifik
            'KK Pemohon (Ahli Waris)': data['file_kk_pemohon'],
            'KTP Ahli Waris': data['file_ktp_ahli_waris'],
            'KK Ahli Waris': data['file_kk_ahli_waris'],
            'Surat Kematian Pewaris': data['surat_keterangan_kematian'],
            'Surat Nikah Orang Tua': data['surat_nikah_orangtua'],
            'Surat Kelahiran dari Bidan/RS': data['surat_keterangan_kelahiran'],
            'KTP Yang Meninggal': data['file_ktp_yang_meninggal'],
            'KTP Pelapor': data['file_ktp_pelapor'],
            'KTP Mempelai': data['file_ktp_mempelai'],
            'Kartu Imunisasi Catin': data['kartu_imunisasi_catin'],
            'Sertifikat Elsimil': data['sertifikat_elsimil'],
            'Akta Perceraian': data['akta_penceraian'],
            'File Pendukung Lainnya': data['file_pendukung_lain'],
            'Lampiran': data['lampiran'],
          };

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusCard(data['status'], data['catatan_penolakan'],
                    data['tanggal_selesai_proses']),
                const SizedBox(height: 24),
                _buildSectionTitle(
                    'Informasi Permohonan', Icons.description_outlined),
                const SizedBox(height: 8),
                _buildDetailCard(
                  children: [
                    _buildDetailRow('Jenis Surat',
                        data['jenis_surat'] ?? 'Tidak diketahui'),
                    _buildDetailRow(
                        'Tanggal Pengajuan',
                        data['created_at'] != null
                            ? DateFormat('d MMMM yyyy, HH:mm', 'id_ID')
                                .format(DateTime.parse(data['created_at']))
                            : '-'),
                    if (data['catatan_pemohon'] != null &&
                        data['catatan_pemohon'].isNotEmpty)
                      _buildDetailRow('Catatan Anda', data['catatan_pemohon']),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('Informasi Pemohon', Icons.person_outline),
                const SizedBox(height: 8),
                _buildDetailCard(
                  children: [
                    _buildDetailRow(
                        'Nama Lengkap', pemohon['nama_lengkap'] ?? '-'),
                    _buildDetailRow('NIK', pemohon['nik'] ?? '-'),
                    _buildDetailRow('Nomor HP', pemohon['nomor_hp'] ?? '-'),
                    _buildDetailRow('Alamat', pemohon['alamat_lengkap'] ?? '-'),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('Lampiran Anda', Icons.attach_file_outlined),
                const SizedBox(height: 8),
                _buildLampiranCard(lampiranFields),
                const SizedBox(height: 32),
                if (data['status'] == 'selesai' &&
                    data['file_hasil_akhir'] != null)
                  _buildDownloadButton(data['file_hasil_akhir']),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryColor, size: 22),
        const SizedBox(width: 10),
        Text(title,
            style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.darkGrey)),
      ],
    );
  }

  Widget _buildDetailCard({required List<Widget> children}) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.lightGrey),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: List.generate(children.length, (index) {
            return Column(
              children: [
                children[index],
                if (index < children.length - 1)
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label,
                style: GoogleFonts.poppins(color: AppColors.mediumGrey)),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Text(
              value ?? '-',
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLampiranCard(Map<String, dynamic> lampiranFields) {
    final validLampiran = lampiranFields.entries
        .where(
            (entry) => entry.value != null && entry.value.toString().isNotEmpty)
        .toList();

    if (validLampiran.isEmpty) {
      return _buildDetailCard(children: [
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Center(
                child: Text("Tidak ada lampiran.",
                    style: GoogleFonts.poppins(color: AppColors.mediumGrey))))
      ]);
    }

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.lightGrey)),
      child: Column(
        children: validLampiran.asMap().entries.map((entry) {
          int idx = entry.key;
          var lampiran = entry.value;
          return Column(
            children: [
              _buildLampiranTile(lampiran.key, lampiran.value),
              if (idx < validLampiran.length - 1)
                const Divider(height: 1, indent: 16, endIndent: 16),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLampiranTile(String label, String filePath) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading:
          Icon(Icons.insert_drive_file_outlined, color: AppColors.primaryColor),
      title:
          Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
      trailing:
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: () async {
        try {
          await _launchFileUrl(filePath);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.toString())),
            );
          }
        }
      },
    );
  }

  Widget _buildStatusCard(
      String? status, String? catatanPenolakan, String? tanggalSelesai) {
    String statusText;
    String statusSubtitle;
    Color cardColor, iconColor;
    IconData statusIcon;

    switch (status) {
      case 'pending':
        statusText = 'Berhasil Diajukan';
        statusSubtitle = 'Menunggu verifikasi oleh petugas.';
        cardColor = Colors.blue.shade50;
        iconColor = Colors.blue.shade700;
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case 'diproses':
      case 'diterima':
        statusText = 'Sedang Diproses';
        statusSubtitle = 'Permohonan Anda sedang dikerjakan.';
        cardColor = Colors.orange.shade50;
        iconColor = Colors.orange.shade700;
        statusIcon = Icons.sync;
        break;
      case 'selesai':
        statusText = 'Permohonan Selesai';
        statusSubtitle =
            'Selesai pada ${tanggalSelesai != null ? DateFormat('d MMMM yyyy', 'id_ID').format(DateTime.parse(tanggalSelesai)) : '-'}';
        cardColor = Colors.green.shade50;
        iconColor = Colors.green.shade700;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'ditolak':
        statusText = 'Permohonan Ditolak';
        statusSubtitle =
            'Ditolak pada ${tanggalSelesai != null ? DateFormat('d MMMM yyyy', 'id_ID').format(DateTime.parse(tanggalSelesai)) : '-'}';
        cardColor = Colors.red.shade50;
        iconColor = Colors.red.shade700;
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusText = 'Status Tidak Diketahui';
        statusSubtitle = 'Silakan hubungi petugas.';
        cardColor = Colors.grey.shade200;
        iconColor = AppColors.mediumGrey;
        statusIcon = Icons.help_outline_rounded;
    }

    return Card(
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(statusIcon, size: 36, color: iconColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(statusText,
                          style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkGrey)),
                      const SizedBox(height: 4),
                      Text(statusSubtitle,
                          style: GoogleFonts.poppins(
                              color: AppColors.mediumGrey, height: 1.5)),
                    ],
                  ),
                ),
              ],
            ),
            if (status == 'ditolak' &&
                catatanPenolakan != null &&
                catatanPenolakan.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(top: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade100.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Alasan Penolakan:",
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade900)),
                    const SizedBox(height: 4),
                    Text(catatanPenolakan,
                        style: GoogleFonts.poppins(color: Colors.red.shade900)),
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
        icon: const Icon(Icons.download_for_offline_outlined,
            color: Colors.white),
        label: Text('Unduh Berkas Hasil Akhir',
            style:
                GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
        style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: AppColors.primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            shadowColor: AppColors.primaryColor.withOpacity(0.4)),
        onPressed: () async {
          try {
            await _launchFileUrl(filePath);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Gagal membuka file: ${e.toString()}')),
              );
            }
          }
        },
      ),
    );
  }
}
