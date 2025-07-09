import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

// Sesuaikan path import ini dengan struktur folder Anda
import 'splash_logic_page.dart'; // <-- PERBAIKAN DI SINI

Future<void> main() async {
  // Pastikan Flutter binding sudah siap
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi data locale untuk Bahasa Indonesia
  await initializeDateFormatting('id_ID', null);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Layanan Desa Kumantan',
      debugShowCheckedModeBanner: false,
      // Menambahkan dukungan locale ke MaterialApp
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('id', 'ID'), // Mendukung Bahasa Indonesia
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 1,
        ),
      ),
      home: const SplashLogicPage(),
    );
  }
}