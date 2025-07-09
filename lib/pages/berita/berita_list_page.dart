import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_desa_kumantan/core/config/app_config.dart';
import 'package:mobile_desa_kumantan/pages/berita/berita_detail_page.dart';
import 'package:shimmer/shimmer.dart';

class AppColors {
  static final Color primaryColor = Colors.blue.shade800;
  static final Color lightGrey = Colors.grey.shade200;
  static final Color darkGrey = Colors.grey.shade800;
  static final Color mediumGrey = Colors.grey.shade600;
}

class NewsItem {
  final String judul;
  final String slug;
  final String ringkasan;
  final String? urlGambar;
  final String tanggal;

  NewsItem({
    required this.judul,
    required this.slug,
    required this.ringkasan,
    this.urlGambar,
    required this.tanggal,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      judul: json['judul'] ?? 'Tanpa Judul',
      slug: json['slug'] ?? '',
      ringkasan: json['ringkasan'] ?? '',
      urlGambar: json['url_gambar'],
      tanggal: json['tanggal'] ?? '-',
    );
  }
}

class NewsListPage extends StatefulWidget {
  const NewsListPage({super.key});

  @override
  State<NewsListPage> createState() => _NewsListPageState();
}

class _NewsListPageState extends State<NewsListPage> {
  late Future<List<NewsItem>> _newsFuture;

  @override
  void initState() {
    super.initState();
    _newsFuture = _fetchNews();
  }

  Future<List<NewsItem>> _fetchNews() async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/api/pengumuman'),
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> body = jsonDecode(response.body);
      final List<dynamic> data = body['data'];
      return data.map((item) => NewsItem.fromJson(item)).toList();
    } else {
      throw Exception('Gagal memuat berita.');
    }
  }

  Future<void> _refreshNews() async {
    setState(() {
      _newsFuture = _fetchNews();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Berita & Pengumuman',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _refreshNews,
        color: AppColors.primaryColor,
        child: FutureBuilder<List<NewsItem>>(
          future: _newsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingShimmer();
            }
            if (snapshot.hasError) {
              return _buildErrorState('Error: ${snapshot.error}');
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildErrorState('Tidak ada berita untuk ditampilkan.');
            }

            final newsList = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: newsList.length,
              itemBuilder: (context, index) {
                return _buildNewsCard(context, newsList[index]);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(height: 12),
              Container(height: 20, width: double.infinity, color: Colors.white),
              const SizedBox(height: 8),
              Container(height: 16, width: 200, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.newspaper_outlined, size: 80, color: Colors.grey[350]),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: AppColors.mediumGrey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewsCard(BuildContext context, NewsItem news) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NewsDetailPage(slug: news.slug),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                news.urlGambar ??
                    'https://placehold.co/600x400?text=Desa+Kumantan',
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Image.network(
                    'https://placehold.co/600x400?text=Gagal+Muat',
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              news.judul,
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              '${news.ringkasan} • ${news.tanggal}',
              style: GoogleFonts.poppins(fontSize: 14, color: AppColors.mediumGrey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}