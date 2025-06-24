// Lokasi: lib/pages/help_center/help_center_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// --- Model Data (Tidak perlu diubah, sudah bagus) ---
class Persyaratan {
  final String judul;
  final List<String> berkas;
  Persyaratan({required this.judul, required this.berkas});
}

class KategoriLayanan {
  final String namaKategori;
  final IconData ikon;
  final List<Persyaratan> daftarLayanan;
  KategoriLayanan({required this.namaKategori, required this.ikon, required this.daftarLayanan});
}

class HelpCenterPage extends StatelessWidget {
  HelpCenterPage({super.key});

  // Data persyaratan layanan
  final List<KategoriLayanan> daftarKategori = [
    KategoriLayanan(
      namaKategori: 'Layanan Kartu Keluarga',
      ikon: Icons.family_restroom_rounded,
      daftarLayanan: [
        Persyaratan(judul: 'Penerbitan KK Baru', berkas: ['Surat Pengantar RT/RW', 'Buku Nikah / Akta Cerai', 'Surat Keterangan Pindah Datang (bagi pendatang)', 'Ijazah Terakhir']),
        Persyaratan(judul: 'Perubahan Data KK', berkas: ['Kartu Keluarga (yang lama)', 'KTP-el', 'Surat Pengantar RT/RW', 'Dokumen Pendukung Perubahan Data (misal: ijazah)']),
        Persyaratan(judul: 'KK Hilang atau Rusak', berkas: ['Surat Pengantar RT/RW', 'KTP-el', 'Surat Keterangan Kehilangan dari Kepolisian', 'Kartu Keluarga yang Rusak (jika rusak)']),
      ],
    ),
    KategoriLayanan(
      namaKategori: 'Layanan Surat Keterangan',
      ikon: Icons.description_rounded,
      daftarLayanan: [
        Persyaratan(judul: 'Surat Keterangan Kelahiran', berkas: ['Kartu Keluarga', 'KTP-el Kedua Orang Tua', 'Surat Pengantar RT/RW', 'Buku Nikah Orang Tua', 'Surat Keterangan Kelahiran dari Bidan/RS']),
        Persyaratan(judul: 'Surat Keterangan Ahli Waris', berkas: ['KTP & Kartu Keluarga Pemohon', 'KTP & Kartu Keluarga Semua Ahli Waris', 'Surat Kematian', 'Surat Pengantar RT/RW']),
        Persyaratan(judul: 'Surat Keterangan Perkawinan', berkas: ['Kartu Keluarga Kedua Calon Mempelai', 'KTP-el Kedua Calon Mempelai', 'Surat Nikah Orang Tua', 'Kartu Imunisasi Calon Pengantin (Catin)', 'Sertifikat Elsimil', 'Akta Perceraian (jika berstatus cerai hidup)']),
        Persyaratan(judul: 'Surat Keterangan Usaha (SKU)', berkas: ['Kartu Keluarga', 'KTP-el Pemohon', 'Surat Pengantar RT/RW']),
        Persyaratan(judul: 'Surat Keterangan Domisili', berkas: ['Kartu Keluarga', 'KTP-el Pemohon', 'Surat Pengantar RT/RW']),
        Persyaratan(judul: 'Surat Keterangan Tidak Mampu (SKTM)', berkas: ['Kartu Keluarga', 'KTP-el Pemohon', 'Surat Pengantar RT/RW', 'Pastikan Anda terdaftar dalam DTKS']),
      ],
    ),
  ];

  Future<void> _launchWhatsApp() async {
    const String phoneNumber = '6289530985115'; 
    const String message = 'Halo Admin Desa Kumantan, saya butuh bantuan terkait aplikasi.';
    final Uri whatsappUrl = Uri.parse('https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}');
    if (!await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $whatsappUrl';
    }
  }

  Future<void> _launchMapsUrl() async {
    final Uri mapsUrl = Uri.parse('https://g.co/kgs/c2zQ2nQ');
    if (!await launchUrl(mapsUrl, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $mapsUrl';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pusat Bantuan', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      backgroundColor: Colors.grey[50],
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        children: [
          _buildSectionTitle(context, 'Alur Pengajuan Surat'),
          const SizedBox(height: 16),
          _buildStepCard(context, icon: Icons.folder_copy_outlined, title: '1. Siapkan Berkas', description: 'Siapkan semua dokumen dalam bentuk digital (foto/PDF).'),
          _buildStepCard(context, icon: Icons.edit_note_rounded, title: '2. Isi Pengajuan', description: 'Pilih jenis surat dan isi formulir di aplikasi.'),
          _buildStepCard(context, icon: Icons.upload_file_rounded, title: '3. Kirim Data', description: 'Unggah semua berkas dan kirim pengajuan Anda.'),
          _buildStepCard(context, icon: Icons.domain_verification_rounded, title: '4. Verifikasi Berkas', description: 'Petugas desa akan memeriksa kelengkapan data Anda.', isPetugas: true),
          _buildStepCard(context, icon: Icons.draw_rounded, title: '5. Disetujui & Ditandatangani', description: 'Surat disetujui dan ditandatangani secara elektronik.', isPetugas: true),
          _buildStepCard(context, icon: Icons.download_done_rounded, title: '6. Surat Siap Diunduh', description: 'Anda akan menerima notifikasi & bisa unduh surat.'),
          const SizedBox(height: 32),
          _buildKetentuanUploadCard(),
          const SizedBox(height: 32),
          _buildSectionTitle(context, 'Berkas yang Dibutuhkan'),
          const SizedBox(height: 16),
          ...daftarKategori.map((kategori) => _buildCategorySection(context, kategori)),
          const SizedBox(height: 32),
          _buildSectionTitle(context, 'Info & Kontak'),
          const SizedBox(height: 16),
          _buildContactCard(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(title, style: GoogleFonts.poppins(textStyle: Theme.of(context).textTheme.headlineSmall, fontWeight: FontWeight.bold, color: Colors.black87));
  }

  Widget _buildKetentuanUploadCard() {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.blue.shade100)),
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Ketentuan Unggah Dokumen", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue.shade800)),
            const SizedBox(height: 12),
            _buildInfoPoint(Icons.picture_as_pdf_rounded, "Format File: PDF, JPG, JPEG, PNG."),
            _buildInfoPoint(Icons.photo_size_select_small_rounded, "Ukuran Maksimal: 2 MB per file."),
            _buildInfoPoint(Icons.check_circle_rounded, "Pastikan file jelas dan tidak buram."),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPoint(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blue.shade700),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: GoogleFonts.poppins(color: Colors.black87, fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildCategorySection(BuildContext context, KategoriLayanan kategori) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16.0, bottom: 12.0),
          child: Row(
            children: [
              Icon(kategori.ikon, color: Colors.black54, size: 28),
              const SizedBox(width: 12),
              Text(kategori.namaKategori, style: GoogleFonts.poppins(textStyle: Theme.of(context).textTheme.titleLarge, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        ...kategori.daftarLayanan.map((layanan) => _buildExpansionCard(layanan)),
      ],
    );
  }

  Widget _buildStepCard(BuildContext context, {required IconData icon, required String title, required String description, bool isPetugas = false}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 32, color: isPetugas ? Colors.orange.shade700 : Theme.of(context).primaryColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(textStyle: Theme.of(context).textTheme.titleMedium, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(description, style: GoogleFonts.poppins(textStyle: Theme.of(context).textTheme.bodyMedium, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpansionCard(Persyaratan syarat) {
    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(syarat.judul, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.black87, fontSize: 15)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedAlignment: Alignment.topLeft,
        children: syarat.berkas.map((berkas) {
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.check_circle_outline, size: 20, color: Colors.green.shade600),
            title: Text(berkas, style: GoogleFonts.poppins()),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildContactCard() {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.schedule_rounded),
            title: Text('Jam Operasional', style: GoogleFonts.poppins()),
            subtitle: Text('Senin - Jumat, 08:00 - 14:00 WIB', style: GoogleFonts.poppins()),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.location_on_rounded),
            title: Text('Alamat Kantor Desa', style: GoogleFonts.poppins()),
            subtitle: Text('JL. Mahmud Marzuki, Desa Kumantan', style: GoogleFonts.poppins()),
            trailing: const Icon(Icons.open_in_new, size: 20),
            onTap: _launchMapsUrl,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Material(
            color: Colors.green.withAlpha(30),
            child: InkWell(
              onTap: _launchWhatsApp,
              child: ListTile(
                leading: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green),
                title: Text('Hubungi via WhatsApp', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                subtitle: Text('Petugas Desa Kumantan', style: GoogleFonts.poppins()),
                trailing: const Icon(Icons.open_in_new, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
