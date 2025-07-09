import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'form_permohonan_page.dart';

class PilihPermohonanPage extends StatelessWidget {
  const PilihPermohonanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pilih Jenis Permohonan', style: GoogleFonts.poppins()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      backgroundColor: const Color(0xFFF5F8FA),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildCategoryHeader(
            icon: Icons.family_restroom_rounded,
            title: 'Urusan Kartu Keluarga (KK)',
            color: Colors.orange.shade800,
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            context: context,
            icon: Icons.add_card_outlined,
            title: 'Permohonan KK Baru',
            subtitle: 'Membuat Kartu Keluarga untuk pertama kali.',
            jenisSurat: 'kk_baru',
          ),
          _buildMenuItem(
            context: context,
            icon: Icons.find_in_page_outlined,
            title: 'Permohonan KK Hilang',
            subtitle: 'Mengurus penerbitan ulang KK yang hilang.',
            jenisSurat: 'kk_hilang',
          ),
          _buildMenuItem(
            context: context,
            icon: Icons.edit_document,
            title: 'Permohonan Perubahan Data KK',
            subtitle: 'Memperbarui data pada Kartu Keluarga.',
            jenisSurat: 'kk_perubahan',
          ),
          const SizedBox(height: 24),
          _buildCategoryHeader(
            icon: Icons.description_rounded,
            title: 'Urusan Surat Keterangan (SK)',
            color: Colors.blue.shade800,
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            context: context,
            icon: Icons.people_alt_outlined,
            title: 'SK Ahli Waris',
            subtitle: 'Surat untuk keperluan pembagian warisan.',
            jenisSurat: 'sk_ahli_waris',
          ),
          _buildMenuItem(
            context: context,
            icon: Icons.money_off_csred_outlined,
            title: 'SK Tidak Mampu',
            subtitle: 'Untuk pengajuan keringanan atau bantuan.',
            jenisSurat: 'sk_tidak_mampu',
          ),
          _buildMenuItem(
            context: context,
            icon: Icons.home_work_outlined,
            title: 'SK Domisili',
            subtitle: 'Menyatakan keterangan tempat tinggal.',
            jenisSurat: 'sk_domisili',
          ),
          _buildMenuItem(
            context: context,
            icon: Icons.child_friendly_outlined,
            title: 'SK Kelahiran',
            subtitle: 'Sebagai pengantar untuk mengurus Akta Kelahiran.',
            jenisSurat: 'sk_kelahiran',
          ),
          _buildMenuItem(
            context: context,
            icon: Icons.favorite_border_outlined,
            title: 'SK Pengantar Nikah',
            subtitle: 'Sebagai pengantar untuk KUA atau lainnya.',
            jenisSurat: 'sk_perkawinan',
          ),
          _buildMenuItem(
            context: context,
            icon: Icons.store_outlined,
            title: 'SK Usaha',
            subtitle: 'Menyatakan keterangan kepemilikan usaha.',
            jenisSurat: 'sk_usaha',
          ),
        ],
      ),
    );
  }
  
  Widget _buildCategoryHeader({required IconData icon, required String title, required Color color}) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required String jenisSurat,
  }) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: Colors.blue.withOpacity(0.1),
          child: Icon(icon, color: Colors.blue.shade800),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(color: Colors.grey.shade600),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FormPermohonanPage(
                jenisSurat: jenisSurat,
                pageTitle: title, // Mengirim judul ke halaman form
              ),
            ),
          );
        },
      ),
    );
  }
}

// Jangan lupa perbarui constructor di FormPermohonanPage untuk menerima pageTitle
// Contoh di `form_permohonan_page.dart`:
//
// final String jenisSurat;
// final String pageTitle;
// const FormPermohonanPage({super.key, required this.jenisSurat, required this.pageTitle});