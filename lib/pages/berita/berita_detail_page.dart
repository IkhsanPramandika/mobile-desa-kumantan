// Lokasi: lib/pages/news/news_detail_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_desa_kumantan/core/config/app_config.dart';

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
    // API Resource Detail sekarang dibungkus dalam 'data'
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
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final news = snapshot.data!;
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 250.0,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    news.judul,
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  background: Image.network(
                    news.urlGambar ?? 'https://placehold.co/600x400?text=Desa+Kumantan',
                    fit: BoxFit.cover,
                    color: Colors.black.withAlpha(128),
                    colorBlendMode: BlendMode.darken,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        news.judul,
                        style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                           Icon(Icons.person_outline, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(news.penulis, style: GoogleFonts.poppins(color: Colors.grey.shade600)),
                          const SizedBox(width: 16),
                          Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(news.tanggal, style: GoogleFonts.poppins(color: Colors.grey.shade600)),
                        ],
                      ),
                      const Divider(height: 32),
                      Text(
                        // Catatan: Jika 'isi' Anda mengandung HTML, Anda perlu
                        // menggunakan package seperti flutter_html untuk merendernya.
                        // Untuk sekarang, kita tampilkan sebagai teks biasa.
                        news.isiLengkap.replaceAll(RegExp(r'<[^>]*>'), ''), // Menghapus tag HTML sederhana
                        style: GoogleFonts.sourceSerif4(fontSize: 16, height: 1.6),
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
}

