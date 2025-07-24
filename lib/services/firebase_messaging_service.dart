import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// [PERBAIKAN] Import GlobalKey dan halaman tujuan navigasi
import '../../main.dart'; // Asumsi GlobalKey ada di main.dart
import '../pages/permohonan/riwayat_permohonan_page.dart';
import '../core/config/app_config.dart';

// Inisialisasi plugin notifikasi lokal
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Handler untuk saat notifikasi di-tap ketika aplikasi ditutup
@pragma('vm:entry-point')
void onDidReceiveBackgroundNotificationResponse(NotificationResponse notificationResponse) {
  if (kDebugMode) {
    print('NOTIFICATION TAPPED (app was terminated): ${notificationResponse.payload}');
  }
  // Logika navigasi bisa ditambahkan di sini jika diperlukan,
  // namun lebih mudah ditangani saat aplikasi start.
}

class FirebaseMessagingService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    await _firebaseMessaging.requestPermission();

    // [PERBAIKAN] Membuat channel notifikasi Android dengan prioritas tinggi
    // Ini adalah langkah krusial agar notifikasi bisa muncul sebagai pop-up (heads-up).
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // ID ini HARUS SAMA dengan di Laravel & AndroidManifest
      'Notifikasi Prioritas Tinggi', // Nama yang terlihat di pengaturan HP
      description: 'Channel ini digunakan untuk notifikasi penting dari aplikasi.',
      importance: Importance.max, // Set ke prioritas tertinggi
      playSound: true,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Konfigurasi agar notifikasi tetap muncul saat aplikasi di foreground
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // [PERBAIKAN] Inisialisasi flutter_local_notifications untuk menangani tap
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('launch_background'); // Pastikan Anda punya file ini di android/app/src/main/res/drawable

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: onDidReceiveBackgroundNotificationResponse,
    );

    _setupMessageHandlers();
    _refreshTokenAndSendToServer();
  }

  // [PERBAIKAN] Fungsi untuk menangani aksi saat notifikasi di-tap
  void onDidReceiveNotificationResponse(NotificationResponse notificationResponse) {
    if (kDebugMode) {
      print('NOTIFICATION TAPPED (app open/background): ${notificationResponse.payload}');
    }
    final String? payload = notificationResponse.payload;
    if (payload != null) {
      // Navigasi ke halaman riwayat
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (context) => const RiwayatPermohonanPage()),
      );
    }
  }

  void _setupMessageHandlers() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print("--- FOREGROUND (onMessage) HANDLER TRIGGERED ---");
        print("Menampilkan notifikasi secara manual karena aplikasi terbuka.");
      }
      
      final notification = message.notification;
      final android = message.notification?.android;

      // [PERBAIKAN] Tampilkan notifikasi lokal saat pesan diterima di foreground
      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                'high_importance_channel', // Gunakan ID channel yang sama
                'Notifikasi Prioritas Tinggi',
                channelDescription: 'Channel ini digunakan untuk notifikasi penting dari aplikasi.',
                icon: 'launch_background',
                importance: Importance.max,
                priority: Priority.high,
              ),
            ),
            // Simpan data dari FCM ke payload notifikasi lokal
            payload: jsonEncode(message.data) 
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('--- onMessageOpenedApp HANDLER TRIGGERED ---');
        print('Pesan yang diketuk berisi data: ${message.data}');
      }
      // Navigasi ke halaman riwayat saat di-tap dari background
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (context) => const RiwayatPermohonanPage()),
      );
    });
  }

  Future<void> _refreshTokenAndSendToServer() async {
    final String? fcmToken = await _firebaseMessaging.getToken();
    if (kDebugMode) {
      print("========================================");
      print("FCM Token: $fcmToken");
      print("========================================");
    }
    if (fcmToken != null) {
      await _sendTokenToServer(fcmToken);
    }
    _firebaseMessaging.onTokenRefresh.listen(_sendTokenToServer);
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiToken = prefs.getString('auth_token');
      final lastSentToken = prefs.getString('fcm_token');

      if (apiToken != null && token != lastSentToken) {
        if (kDebugMode) {
          print("Mengirim FCM Token baru ke server...");
        }
        final response = await http.post(
          Uri.parse('${AppConfig.apiBaseUrl}/notifikasi/user/update-fcm-token'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $apiToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'fcm_token': token}),
        );

        if (response.statusCode == 200) {
          if (kDebugMode) {
            print("FCM Token berhasil disimpan di server.");
          }
          await prefs.setString('fcm_token', token);
        } else {
          if (kDebugMode) {
            print("Gagal mengirim FCM token ke server: ${response.statusCode} - ${response.body}");
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error saat mengirim FCM token: $e");
      }
    }
  }
}
