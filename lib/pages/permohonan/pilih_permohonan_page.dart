// lib/presentation/permohonan/screens/pilih_permohonan_page.dart

import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';

// Import halaman form dinamis yang ada di folder yang sama
import 'form_permohonan_page.dart'; 

class PilihPermohonanPage extends StatelessWidget {
  const PilihPermohonanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pilih Jenis Surat Permohonan'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        children: [
          _buildMenuItem(
            context: context,
            icon: Icons.add_card,
            title: 'Permohonan KK Baru',
            jenisSurat: 'kk_baru',
          ),
          _buildMenuItem(
            context: context,
            icon: Icons.find_in_page_sharp,
            title: 'Permohonan KK Hilang',
            jenisSurat: 'kk_hilang',
          ),
          _buildMenuItem(
            context: context,
            icon: Icons.edit_document,
            title: 'Permohonan Perubahan Data KK',
            jenisSurat: 'kk_perubahan',
          ),
          _buildMenuItem(
            context: context,
            icon: Icons.people_alt,
            title: 'Surat Keterangan Ahli Waris',
            jenisSurat: 'sk_ahli_waris',
          ),
          _buildMenuItem(
            context: context,
            icon: Icons.money_off,
            title: 'Surat Keterangan Tidak Mampu',
            jenisSurat: 'sk_tidak_mampu',
          ),
          _buildMenuItem(
            context: context,
            icon: Icons.home_work,
            title: 'Surat Keterangan Domisili',
            jenisSurat: 'sk_domisili',
          ),
          _buildMenuItem(
            context: context,
            icon: Icons.child_friendly,
            title: 'Surat Keterangan Kelahiran',
            jenisSurat: 'sk_kelahiran',
          ),
          _buildMenuItem(
            context: context,
            icon: Icons.favorite,
            title: 'Surat Keterangan Perkawinan',
            jenisSurat: 'sk_perkawinan',
          ),
          _buildMenuItem(
            context: context,
            icon: Icons.store,
            title: 'Surat Keterangan Usaha',
            jenisSurat: 'sk_usaha',
          ),
        ],
      ),
    );
  }

  // Widget helper untuk membuat setiap item menu
  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String jenisSurat,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      elevation: 2,
      child: GFListTile(
        title: Text(
          title, 
          style: TextStyle(fontWeight: FontWeight.bold)
        ),
        avatar: GFAvatar(
          backgroundColor: Colors.green.withAlpha(38),
          child: Icon(icon, color: Colors.green.shade700),
        ),
        icon: Icon(Icons.chevron_right, color: Colors.grey.shade600),
        onTap: () {
          // Navigasi ke halaman form dinamis dengan membawa parameter 'jenisSurat'
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FormPermohonanPage(
                jenisSurat: jenisSurat,
              ),
            ),
          );
        },
      ),
    );
  }
}