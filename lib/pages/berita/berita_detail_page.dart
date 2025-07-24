import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_desa_kumantan/core/config/app_config.dart';
import 'package:shimmer/shimmer.dart';

// Class warna untuk konsistensi UI
class AppColors {
  static final Color primaryColor = Colors.blue.shade800;
  static final Color lightGrey = Colors.grey.shade200;
  static final Color darkGrey = Colors.grey.shade800; // [cite: 15]
  static final Color mediumGrey = Colors.grey.shade600; // [cite: 15]
}

// Model data untuk detail berita
class NewsDetail {
  final String judul;
  final String isiLengkap; // [cite: 16]
  final String? urlGambar;
  final String tanggal;
  final String penulis;

  NewsDetail({
    // [cite: 17]
    required this.judul,
    required this.isiLengkap,
    this.urlGambar,
    required this.tanggal,
    required this.penulis,
  });

  factory NewsDetail.fromJson(Map<String, dynamic> json) {
    // [cite: 18]
    final data = json['data'] ?? {}; // [cite: 18]
    return NewsDetail(
      // [cite: 19]
      judul: data['judul'] ?? 'Tanpa Judul',
      isiLengkap: data['isi_lengkap'] ?? 'Konten tidak tersedia.',
      urlGambar: data['url_gambar'],
      tanggal: data['tanggal'] ?? '-',
      penulis: data['penulis'] ?? 'Admin Desa',
    );
  }
}

class NewsDetailPage extends StatefulWidget {
  final String slug;
  const NewsDetailPage({super.key, required this.slug});

  @override
  State<NewsDetailPage> createState() => _NewsDetailPageState(); // [cite: 21]
}

class _NewsDetailPageState extends State<NewsDetailPage> {
  late Future<NewsDetail> _newsDetailFuture;

  @override
  void initState() {
    super.initState();
    _newsDetailFuture = _fetchNewsDetail(); // [cite: 22]
  }

  Future<NewsDetail> _fetchNewsDetail() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/pengumuman/${widget.slug}'),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        // [cite: 23]
        return NewsDetail.fromJson(jsonDecode(response.body)); // [cite: 23]
      } else {
        throw Exception(
            'Gagal memuat detail berita (Status: ${response.statusCode})'); // [cite: 24]
      }
    } catch (e) {
      throw Exception(
          'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    }
  }

  @override
  Widget build(BuildContext context) {
    // [cite: 25]
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<NewsDetail>(
        future: _newsDetailFuture,
        builder: (context, snapshot) {
          // [cite: 35]
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingShimmer();
          }
          if (snapshot.hasError) {
            return _buildErrorState('Error: ${snapshot.error}'); // [cite: 26]
          }

          final news = snapshot.data!;
          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(news),
              SliverToBoxAdapter(
                // [cite: 34]
                child: Padding(
                  padding: const EdgeInsets.all(20.0), // [cite: 27]
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // [cite: 28]
                        news.judul,
                        style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      _buildMetaInfo(news),
                      const Divider(height: 40),
                      Html(
                        // [cite: 30]
                        data: news.isiLengkap,
                        style: {
                          "body": Style(
                            // [cite: 31]
                            fontSize: FontSize(17),
                            lineHeight: LineHeight.number(1.7),
                            fontFamily: GoogleFonts.sourceSerif4().fontFamily,
                            color: AppColors.darkGrey,
                          ),
                          "p": Style(
                            // [cite: 32]
                            margin: Margins.only(bottom: 16),
                          ),
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSliverAppBar(NewsDetail news) {
    // [cite: 36]
    return SliverAppBar(
      expandedHeight: 270.0,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.primaryColor,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 50, vertical: 12),
        centerTitle: false,
        title: Text(
          news.judul,
          style: GoogleFonts.poppins(
              fontSize: 16, fontWeight: FontWeight.w600), // [cite: 37]
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              news.urlGambar ??
                  'https://placehold.co/600x400?text=Desa+Kumantan',
              fit: BoxFit.cover, // [cite: 38]
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter, // [cite: 39]
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.2),
                    Colors.black.withOpacity(0.7),
                  ],
                  stops: const [0.5, 0.8, 1.0], // [cite: 40]
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaInfo(NewsDetail news) {
    // [cite: 41]
    return Row(
      children: [
        Icon(Icons.person_outline, size: 16, color: AppColors.mediumGrey),
        const SizedBox(width: 6),
        Text(news.penulis,
            style: GoogleFonts.poppins(color: AppColors.mediumGrey)),
        const SizedBox(width: 16),
        Icon(Icons.calendar_today_outlined,
            size: 16, color: AppColors.mediumGrey),
        const SizedBox(width: 6),
        Text(news.tanggal,
            style: GoogleFonts.poppins(color: AppColors.mediumGrey)),
      ],
    );
  }

  Widget _buildLoadingShimmer() {
    // [cite: 42]
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 300, // [cite: 43]
              width: double.infinity,
              color: Colors.white,
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment
                    .start, // [crossAxisAlignment: CrossAxisAlignment.start, ]
                children: [
                  Container(
                      height: 28, width: double.infinity, color: Colors.white),
                  const SizedBox(height: 10),
                  Container(height: 28, width: 200, color: Colors.white),
                  const SizedBox(height: 20), // [cite: 45]
                  Container(height: 16, width: 250, color: Colors.white),
                  const Divider(height: 40),
                  Container(
                      height: 18, width: double.infinity, color: Colors.white),
                  const SizedBox(height: 12),
                  Container(
                      height: 18,
                      width: double.infinity,
                      color: Colors.white), // [cite: 46]
                  const SizedBox(height: 12),
                  Container(height: 18, width: 150, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  color: AppColors.mediumGrey, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
