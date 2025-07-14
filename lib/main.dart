import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

// Ganti dengan path yang benar ke service dan halaman Anda
import 'services/firebase_messaging_service.dart';
import 'splash_logic_page.dart';

// Handler ini akan dipanggil saat notifikasi dari Laravel diterima
// ketika aplikasi berjalan di background atau ditutup.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Dengan metode hybrid, kita tidak perlu lagi memanggil showLocalNotification di sini.
  // Sistem operasi Android akan menangani tampilan notifikasi.
  // Kita hanya perlu memastikan Firebase diinisialisasi.
  await Firebase.initializeApp();

  if (kDebugMode) {
    print("--- BACKGROUND HANDLER TRIGGERED (Hybrid Payload) ---");
    print("Pesan diterima oleh aplikasi, tampilan ditangani oleh OS.");
    print("Message data: ${message.data}");
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await FirebaseMessagingService().initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Layanan Desa Kumantan',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('id', 'ID'),
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 1,
        ),
      ),
      home: const SplashLogicPage(),
    );
  }
}
