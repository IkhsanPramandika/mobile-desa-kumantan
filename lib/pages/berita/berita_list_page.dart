import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_desa_kumantan/core/config/app_config.dart'; //
import 'package:mobile_desa_kumantan/pages/berita/berita_detail_page.dart';
import 'package:shimmer/shimmer.dart';

// Class warna untuk konsistensi UI
class AppColors {
  static final Color primaryColor = Colors.blue.shade800; //
  static final Color lightGrey = Colors.grey.shade200; //
  static final Color darkGrey = Colors.grey.shade800; //
  static final Color mediumGrey = Colors.grey.shade600; //
}

// Model data untuk setiap item berita di list
class NewsItem {
  final String judul;
  final String slug; //
  final String ringkasan;
  final String? urlGambar;
  final String tanggal;

  NewsItem({ //
    required this.judul,
    required this.slug,
    required this.ringkasan,
    this.urlGambar,
    required this.tanggal,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) { //
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
  const NewsListPage({super.key}); //

  @override
  State<NewsListPage> createState() => _NewsListPageState(); //
}

class _NewsListPageState extends State<NewsListPage> {
  // State untuk manajemen pagination
  final List<NewsItem> _newsItems = [];
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchNews(); // Ambil data pertama kali
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_isLoading && _hasMore && _scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.9) {
      _fetchNews();
    }
  }

  Future<void> _fetchNews() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
      if (_currentPage == 1) {
        _error = null; // Reset error hanya saat refresh/fetch pertama
      }
    });

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/pengumuman?page=$_currentPage'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) { //
        final Map<String, dynamic> body = jsonDecode(response.body); //
        final List<dynamic> data = body['data']; //
        final List<NewsItem> fetchedItems = data.map((item) => NewsItem.fromJson(item)).toList(); //

        setState(() {
          _newsItems.addAll(fetchedItems);
          if (body['links']['next'] == null) {
            _hasMore = false;
          }
          _currentPage++;
        });
      } else {
        throw Exception('Gagal memuat berita. Status: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        if (_currentPage == 1) _hasMore = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshNews() async { //
    setState(() {
      _newsItems.clear();
      _currentPage = 1;
      _hasMore = true;
      _isLoading = false;
      _error = null;
    });
    await _fetchNews();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) { //
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
        onRefresh: _refreshNews, //
        color: AppColors.primaryColor,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _newsItems.isEmpty) {
      return _buildLoadingShimmer();
    }
    if (_error != null && _newsItems.isEmpty) {
      return _buildErrorState('Error: $_error'); //
    }
    if (_newsItems.isEmpty) {
      return _buildErrorState('Tidak ada berita untuk ditampilkan.'); //
    }

    return ListView.builder( //
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _newsItems.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _newsItems.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _buildNewsCard(context, _newsItems[index]);
      },
    );
  }

  Widget _buildNewsCard(BuildContext context, NewsItem news) { //
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
        margin: const EdgeInsets.only(bottom: 24), //
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                news.urlGambar ??
                    'https://placehold.co/600x400?text=Desa+Kumantan', //
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Image.network(
                    'https://placehold.co/600x400?text=Gagal+Muat', //
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 12), //
            Text(
              news.judul,
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6), //
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

  Widget _buildLoadingShimmer() { //
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, //
            children: [
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16), //
                ),
              ),
              const SizedBox(height: 12),
              Container(height: 20, width: double.infinity, color: Colors.white),
              const SizedBox(height: 8),
              Container(height: 16, width: 200, color: Colors.white), //
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) { //
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.newspaper_outlined, size: 80, color: Colors.grey[350]), //
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: AppColors.mediumGrey), //
              ),
            ],
          ),
        ),
      ),
    );
  }
}