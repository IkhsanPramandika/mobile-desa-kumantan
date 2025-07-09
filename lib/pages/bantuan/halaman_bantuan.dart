import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AppColors {
  static final Color primaryColor = Colors.blue.shade800;
  static final Color lightGrey = Colors.grey.shade200;
  static final Color darkGrey = Colors.grey.shade800;
  static final Color mediumGrey = Colors.grey.shade600;
}

class Persyaratan {
  final String judul;
  final List<String> berkas;
  Persyaratan({required this.judul, required this.berkas});
}

class KategoriLayanan {
  final String namaKategori;
  final IconData ikon;
  final List<Persyaratan> daftarLayanan;
  KategoriLayanan(
      {required this.namaKategori,
      required this.ikon,
      required this.daftarLayanan});
}

class HelpCenterPage extends StatelessWidget {
  HelpCenterPage({super.key});

  final List<KategoriLayanan> daftarKategori = [
    KategoriLayanan(
      namaKategori: 'Layanan Kartu Keluarga',
      ikon: Icons.family_restroom_rounded,
      daftarLayanan: [
        Persyaratan(
            judul: 'Penerbitan KK Baru',
            berkas: [
              'Surat Pengantar RT/RW',
              'Buku Nikah / Akta Cerai',
              'Surat Keterangan Pindah Datang (bagi pendatang)',
              'Ijazah Terakhir'
            ]),
        Persyaratan(
            judul: 'Perubahan Data KK',
            berkas: [
              'Kartu Keluarga (yang lama)',
              'KTP-el',
              'Surat Pengantar RT/RW',
              'Dokumen Pendukung Perubahan Data (misal: ijazah)'
            ]),
        Persyaratan(judul: 'KK Hilang atau Rusak', berkas: [
          'Surat Pengantar RT/RW',
          'KTP-el',
          'Surat Keterangan Kehilangan dari Kepolisian',
          'Kartu Keluarga yang Rusak (jika rusak)'
        ]),
      ],
    ),
    KategoriLayanan(
      namaKategori: 'Layanan Surat Keterangan',
      ikon: Icons.description_rounded,
      daftarLayanan: [
        Persyaratan(
            judul: 'Surat Keterangan Kelahiran',
            berkas: [
              'Kartu Keluarga',
              'KTP-el Kedua Orang Tua',
              'Surat Pengantar RT/RW',
              'Buku Nikah Orang Tua',
              'Surat Keterangan Kelahiran dari Bidan/RS'
            ]),
        Persyaratan(
            judul: 'Surat Keterangan Ahli Waris',
            berkas: [
              'KTP & Kartu Keluarga Pemohon',
              'KTP & Kartu Keluarga Semua Ahli Waris',
              'Surat Kematian',
              'Surat Pengantar RT/RW'
            ]),
        Persyaratan(
            judul: 'Surat Keterangan Perkawinan',
            berkas: [
              'Kartu Keluarga Kedua Calon Mempelai',
              'KTP-el Kedua Calon Mempelai',
              'Surat Nikah Orang Tua',
              'Kartu Imunisasi Calon Pengantin (Catin)',
              'Sertifikat Elsimil',
              'Akta Perceraian (jika berstatus cerai hidup)'
            ]),
        Persyaratan(
            judul: 'Surat Keterangan Usaha (SKU)',
            berkas: ['Kartu Keluarga', 'KTP-el Pemohon', 'Surat Pengantar RT/RW']),
        Persyaratan(
            judul: 'Surat Keterangan Domisili',
            berkas: ['Kartu Keluarga', 'KTP-el Pemohon', 'Surat Pengantar RT/RW']),
        Persyaratan(
            judul: 'Surat Keterangan Tidak Mampu (SKTM)',
            berkas: [
              'Kartu Keluarga',
              'KTP-el Pemohon',
              'Surat Pengantar RT/RW',
              'Pastikan Anda terdaftar dalam DTKS'
            ]),
      ],
    ),
  ];

  Future<void> _launchWhatsApp() async {
    const String phoneNumber = '6289530985115';
    const String message =
        'Halo Admin Desa Kumantan, saya butuh bantuan terkait aplikasi.';
    final Uri whatsappUrl = Uri.parse(
        'https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}');
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
        title: Text('Pusat Bantuan',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          _buildSectionTitle('Alur Pengajuan Surat'),
          const SizedBox(height: 16),
          _buildStepCard(
              icon: Icons.folder_copy_outlined,
              title: '1. Siapkan Berkas',
              description: 'Siapkan semua dokumen dalam bentuk digital (foto/PDF).'),
          _buildStepCard(
              icon: Icons.edit_note_rounded,
              title: '2. Isi Pengajuan',
              description: 'Pilih jenis surat dan isi formulir di aplikasi.'),
          _buildStepCard(
              icon: Icons.upload_file_rounded,
              title: '3. Kirim Data',
              description: 'Unggah semua berkas dan kirim pengajuan Anda.'),
          _buildStepCard(
              icon: Icons.domain_verification_rounded,
              title: '4. Verifikasi Berkas',
              description: 'Petugas desa akan memeriksa kelengkapan data Anda.',
              isPetugas: true),
          _buildStepCard(
              icon: Icons.draw_rounded,
              title: '5. Disetujui & Ditandatangani',
              description:
                  'Surat disetujui dan ditandatangani secara elektronik.',
              isPetugas: true),
          _buildStepCard(
              icon: Icons.download_done_rounded,
              title: '6. Surat Siap Diunduh',
              description: 'Anda akan menerima notifikasi & bisa unduh surat.'),
          const SizedBox(height: 32),
          _buildKetentuanUploadCard(),
          const SizedBox(height: 32),
          _buildSectionTitle('Berkas yang Dibutuhkan'),
          const SizedBox(height: 16),
          ...daftarKategori.map((kategori) => _buildCategorySection(kategori)),
          const SizedBox(height: 32),
          _buildSectionTitle('Info & Kontak'),
          const SizedBox(height: 16),
          _buildContactCard(),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 20),
            label: const Text('Hubungi Petugas via WhatsApp'),
            onPressed: _launchWhatsApp,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.darkGrey));
  }

  Widget _buildKetentuanUploadCard() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Ketentuan Unggah Dokumen",
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.primaryColor)),
          const SizedBox(height: 12),
          _buildInfoPoint(
              Icons.picture_as_pdf_rounded, "Format File: PDF, JPG, JPEG, PNG."),
          _buildInfoPoint(
              Icons.photo_size_select_small_rounded, "Ukuran Maksimal: 2 MB per file."),
          _buildInfoPoint(
              Icons.check_circle_rounded, "Pastikan file jelas dan tidak buram."),
        ],
      ),
    );
  }

  Widget _buildInfoPoint(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primaryColor),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text,
                  style:
                      GoogleFonts.poppins(color: Colors.black87, fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildCategorySection(KategoriLayanan kategori) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Row(
            children: [
              Icon(kategori.ikon, color: AppColors.primaryColor, size: 24),
              const SizedBox(width: 12),
              Text(kategori.namaKategori,
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkGrey)),
            ],
          ),
        ),
        ...kategori.daftarLayanan.map((layanan) => _buildExpansionCard(layanan)),
      ],
    );
  }

  Widget _buildStepCard(
      {required IconData icon,
      required String title,
      required String description,
      bool isPetugas = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.lightGrey)),
      child: Row(
        children: [
          Icon(icon,
              size: 32,
              color: isPetugas ? Colors.orange.shade700 : AppColors.primaryColor),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(description,
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: AppColors.mediumGrey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpansionCard(Persyaratan syarat) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(syarat.judul,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                fontSize: 15)),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        expandedAlignment: Alignment.topLeft,
        children: syarat.berkas.map((berkas) {
          return Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check, size: 20, color: Colors.green.shade600),
                const SizedBox(width: 12),
                Expanded(child: Text(berkas, style: GoogleFonts.poppins())),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildContactCard() {
    return Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          _buildContactRow(
            icon: Icons.schedule_rounded,
            title: 'Jam Operasional',
            subtitle: 'Senin - Jumat, 08:00 - 14:00 WIB',
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          _buildContactRow(
              icon: Icons.location_on_rounded,
              title: 'Alamat Kantor Desa',
              subtitle: 'JL. Mahmud Marzuki, Desa Kumantan',
              onTap: _launchMapsUrl),
        ],
      ),
    );
  }

  Widget _buildContactRow(
      {required IconData icon,
      required String title,
      required String subtitle,
      VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.mediumGrey),
      title: Text(title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: GoogleFonts.poppins()),
      trailing: onTap != null
          ? const Icon(Icons.arrow_forward_ios, size: 16)
          : null,
    );
  }
}