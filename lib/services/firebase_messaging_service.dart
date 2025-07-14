import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Ganti dengan path yang benar ke config Anda
import '../core/config/app_config.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void onDidReceiveBackgroundNotificationResponse(NotificationResponse notificationResponse) {
  if (kDebugMode) {
    print('NOTIFICATION TAPPED (app was terminated): ${notificationResponse.payload}');
  }
}

class FirebaseMessagingService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    await _firebaseMessaging.requestPermission();

    // [PERBAIKAN KUNCI & FINAL]
    // Membuat channel notifikasi secara eksplisit saat aplikasi dimulai.
    // Ini memberitahu sistem Android bahwa channel 'high_importance_chan nel'
    // harus selalu ditampilkan sebagai notifikasi pop-up (heads-up).
    // Ini adalah langkah yang hilang dan paling penting.
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // ID ini HARUS SAMA dengan di Laravel & AndroidManifest
      'Notifikasi Prioritas Tinggi', // Nama yang terlihat di pengaturan HP
      description: 'Channel ini digunakan untuk notifikasi penting dari aplikasi.', // Deskripsi
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

    _setupMessageHandlers();
    _refreshTokenAndSendToServer();
  }

  void _setupMessageHandlers() {
    // Handler untuk pesan saat aplikasi di foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print("--- FOREGROUND (onMessage) HANDLER TRIGGERED ---");
        print("Menampilkan notifikasi secara manual karena aplikasi terbuka.");
      }
      
      // Saat di foreground, kita perlu menampilkan notifikasi secara manual
      // agar pengalaman pengguna konsisten.
      final notification = message.notification;
      final android = message.notification?.android;

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
                icon: 'launch_background', // atau nama ikon lain di drawable
                importance: Importance.max,
                priority: Priority.high,
              ),
            ),
            payload: jsonEncode(message.data)
        );
      }
    });

    // Handler saat notifikasi di-tap dan membuka aplikasi
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('--- onMessageOpenedApp HANDLER TRIGGERED ---');
        print('Pesan yang diketuk berisi data: ${message.data}');
      }
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
