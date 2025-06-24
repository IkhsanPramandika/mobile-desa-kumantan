import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class AppConfig {
  // Alamat IP Komputer Anda di jaringan WiFi.
  // Ganti dengan alamat IP yang Anda dapatkan dari 'ipconfig'.
 static const String _physicalDeviceIp = '192.168.1.17';

  static String get baseUrl {
    if (kIsWeb) {
      // Berjalan di Web (Chrome, Edge)
      return 'http://localhost:8000';
    } else {
      // Berjalan di Mobile (Android/iOS)
      if (Platform.isAndroid) {
        // Untuk Emulator Android, gunakan alamat khusus ini.
        // Untuk HP Fisik, kita akan gunakan IP yang sudah ditentukan.
        // Cara ini kurang ideal jika Anda sering berganti-ganti,
        // cara manual lebih disarankan untuk saat ini.
        // Untuk sekarang, kita fokus pada HP Fisik.
        return 'http://$_physicalDeviceIp:8000';
      } else {
        // Untuk iOS Simulator atau perangkat lain
        return 'http://localhost:8000';
      }
    }
  }

  // Endpoint API akan otomatis menggunakan baseUrl yang benar
  static String get apiBaseUrl => '$baseUrl/api/masyarakat';
}
