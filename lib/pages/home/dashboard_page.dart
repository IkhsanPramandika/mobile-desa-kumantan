import 'package:flutter/material.dart';

// Import semua halaman yang akan menjadi tujuan navigasi
import 'home_content_page.dart';
import '../permohonan/riwayat_permohonan_page.dart';
import '../profile/profile_page.dart';
import '../permohonan/pilih_permohonan_page.dart';
import '../berita/berita_list_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;

  // Daftar halaman INTI yang akan ditampilkan sesuai tab
  static const List<Widget> _pages = <Widget>[
    HomeContentPage(), // Index 0: Beranda
    RiwayatPermohonanPage(), // Index 1: Riwayat
    NewsListPage(), // Index 2: Berita
    ProfilePage(), // Index 3: Profil
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const PilihPermohonanPage()),
          );
        },
        backgroundColor: Colors.green,
        shape: const CircleBorder(),
        elevation: 2.0,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _buildNavItem(icon: Icons.home_filled, label: 'Beranda', index: 0),
            _buildNavItem(icon: Icons.history, label: 'Riwayat', index: 1),
            const SizedBox(width: 40), // Ruang untuk Floating Action Button
            _buildNavItem(
                icon: Icons.newspaper_outlined, label: 'Berita', index: 2),
            _buildNavItem(
                icon: Icons.person_outline, label: 'Profil', index: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
      {required IconData icon, required String label, required int index}) {
    final bool isSelected = _selectedIndex == index;
    final Color color =
        isSelected ? Theme.of(context).primaryColor : Colors.grey.shade600;

    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: SizedBox(
          height: kBottomNavigationBarHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
