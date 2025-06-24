import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:http/http.dart' as http;

// Import Halaman Tujuan
import 'package:mobile_desa_kumantan/pages/profile/profile_page.dart';
import 'package:mobile_desa_kumantan/pages/notifications/notification_page.dart';
import 'package:mobile_desa_kumantan/pages/berita/berita_list_page.dart';
import 'package:mobile_desa_kumantan/pages/berita/berita_detail_page.dart'; // Import halaman detail

// Import Konfigurasi
import 'package:mobile_desa_kumantan/core/config/app_config.dart';

// Model untuk menampung data berita dari API
class NewsSliderItem {
  final String judul;
  final String slug;
  final String? urlGambar;

  NewsSliderItem({required this.judul, required this.slug, this.urlGambar});

  factory NewsSliderItem.fromJson(Map<String, dynamic> json) {
    return NewsSliderItem(
      judul: json['judul'] ?? 'Tanpa Judul',
      slug: json['slug'] ?? '',
      urlGambar: json['url_gambar'],
    );
  }
}

class HomeContentPage extends StatefulWidget {
  const HomeContentPage({super.key});

  @override
  State<HomeContentPage> createState() => _HomeContentPageState();
}

class _HomeContentPageState extends State<HomeContentPage> {
  // Data dummy untuk nama, nantinya bisa diambil dari SharedPreferences atau API profil
  final String userName = "Ikhsan Pramandika";
  late Future<List<NewsSliderItem>> _latestNewsFuture;

  @override
  void initState() {
    super.initState();
    // Memanggil API saat halaman pertama kali dibuka
    _latestNewsFuture = _fetchLatestNews();
  }

  // Fungsi untuk mengambil berita dari API Laravel
  Future<List<NewsSliderItem>> _fetchLatestNews() async {
    final response = await http.get(
      // Mengambil 3 berita teratas dari endpoint pengumuman
      Uri.parse('${AppConfig.baseUrl}/api/pengumuman?limit=3'),
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> body = jsonDecode(response.body);
      // Laravel pagination membungkus data dalam key 'data'
      final List<dynamic> data = body['data'] ?? [];
      return data.map((item) => NewsSliderItem.fromJson(item)).toList();
    } else {
      // Jika gagal, lemparkan error untuk ditampilkan oleh FutureBuilder
      throw Exception('Gagal memuat berita terbaru.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          _buildLatestNewsSection(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (context) => const ProfilePage())),
      child: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: const BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 30,
              backgroundImage:
                  NetworkImage('https://i.pravatar.cc/150?u=ikhsan'),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Selamat Datang,',
                      style: GoogleFonts.poppins(
                          color: Colors.white70, fontSize: 16)),
                  Text(userName,
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.notifications_outlined,
                  color: Colors.white, size: 28),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const NotificationPage()));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLatestNewsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Berita & Pengumuman',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const NewsListPage()));
                },
                child: const Text('Lihat Semua'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Menggunakan FutureBuilder untuk menampilkan data dari API
          FutureBuilder<List<NewsSliderItem>>(
            future: _latestNewsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return SizedBox(
                  height: 200,
                  child: Center(
                      child: Text('Gagal memuat berita: ${snapshot.error}')),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SizedBox(
                  height: 200,
                  child: Center(child: Text('Tidak ada berita terbaru.')),
                );
              }

              final newsList = snapshot.data!;
              return CarouselSlider.builder(
                itemCount: newsList.length,
                itemBuilder: (context, index, realIndex) {
                  return _buildNewsCard(context, newsList[index]);
                },
                options: CarouselOptions(
                  height: 200.0,
                  autoPlay: true,
                  enlargeCenterPage: true,
                  viewportFraction: 0.9,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNewsCard(BuildContext context, NewsSliderItem news) {
    return Container(
      width: MediaQuery.of(context).size.width,
      margin: const EdgeInsets.symmetric(horizontal: 5.0),
      child: InkWell(
        onTap: () {
          // Navigasi ke halaman detail berita dengan membawa slug
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => NewsDetailPage(slug: news.slug)));
        },
        borderRadius: BorderRadius.circular(15),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                news.urlGambar ??
                    'https://placehold.co/600x400?text=Desa+Kumantan',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.broken_image, color: Colors.grey)),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withAlpha(178), Colors.transparent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: Text(
                  news.judul,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
