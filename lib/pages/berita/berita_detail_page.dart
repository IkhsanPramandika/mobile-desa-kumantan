import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_desa_kumantan/core/config/app_config.dart';
import 'package:shimmer/shimmer.dart';

class AppColors {
  static final Color primaryColor = Colors.blue.shade800;
  static final Color lightGrey = Colors.grey.shade200;
  static final Color darkGrey = Colors.grey.shade800;
  static final Color mediumGrey = Colors.grey.shade600;
}

class NewsDetail {
  final String judul;
  final String isiLengkap;
  final String? urlGambar;
  final String tanggal;
  final String penulis;

  NewsDetail({
    required this.judul,
    required this.isiLengkap,
    this.urlGambar,
    required this.tanggal,
    required this.penulis,
  });

  factory NewsDetail.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? {};
    return NewsDetail(
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
  State<NewsDetailPage> createState() => _NewsDetailPageState();
}

class _NewsDetailPageState extends State<NewsDetailPage> {
  late Future<NewsDetail> _newsDetailFuture;

  @override
  void initState() {
    super.initState();
    _newsDetailFuture = _fetchNewsDetail();
  }

  Future<NewsDetail> _fetchNewsDetail() async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/api/pengumuman/${widget.slug}'),
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      return NewsDetail.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Gagal memuat detail berita.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<NewsDetail>(
        future: _newsDetailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingShimmer();
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final news = snapshot.data!;
          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(news),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        news.judul,
                        style: GoogleFonts.poppins(
                            fontSize: 24, fontWeight: FontWeight.bold, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      _buildMetaInfo(news),
                      const Divider(height: 40),
                      Html(
                        data: news.isiLengkap,
                        style: {
                          "body": Style(
                            fontSize: FontSize(17),
                            lineHeight: LineHeight.number(1.7),
                            fontFamily: GoogleFonts.sourceSerif4().fontFamily,
                            color: AppColors.darkGrey,
                          ),
                          "p": Style(
                            margin: Margins.only(bottom: 16)
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
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              news.urlGambar ?? 'https://placehold.co/600x400?text=Desa+Kumantan',
              fit: BoxFit.cover,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.2),
                    Colors.black.withOpacity(0.7),
                  ],
                  stops: const [0.5, 0.8, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaInfo(NewsDetail news) {
    return Row(
      children: [
        Icon(Icons.person_outline, size: 16, color: AppColors.mediumGrey),
        const SizedBox(width: 6),
        Text(news.penulis, style: GoogleFonts.poppins(color: AppColors.mediumGrey)),
        const SizedBox(width: 16),
        Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.mediumGrey),
        const SizedBox(width: 6),
        Text(news.tanggal, style: GoogleFonts.poppins(color: AppColors.mediumGrey)),
      ],
    );
  }

  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 300,
              width: double.infinity,
              color: Colors.white,
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 28, width: double.infinity, color: Colors.white),
                  const SizedBox(height: 10),
                  Container(height: 28, width: 200, color: Colors.white),
                  const SizedBox(height: 20),
                  Container(height: 16, width: 250, color: Colors.white),
                  const Divider(height: 40),
                  Container(height: 18, width: double.infinity, color: Colors.white),
                  const SizedBox(height: 12),
                  Container(height: 18, width: double.infinity, color: Colors.white),
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
}