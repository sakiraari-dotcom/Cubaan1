import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Tetapan peranti (bukan kandungan masjid).
class AppSettings {
  String mode; // 'rumah' atau 'masjid'
  bool autoLocation;
  String? manualZone;
  List<String> images;
  String? folder;
  int interval; // saat
  bool use12h;
  bool autostart;
  String pin; // PIN panel kawalan jauh
  String role; // 'utama' atau 'pendua'
  String masterHost; // IP TV utama (untuk pendua)
  String masterPin;

  AppSettings({
    this.mode = 'rumah',
    this.autoLocation = true,
    this.manualZone,
    List<String>? images,
    this.folder,
    this.interval = 6,
    this.use12h = true,
    this.autostart = true,
    String? pin,
    this.role = 'utama',
    this.masterHost = '',
    this.masterPin = '',
  })  : images = images ?? [],
        pin = pin ?? newPin();

  static String newPin() => (100000 + Random.secure().nextInt(900000)).toString();

  AppSettings copy() => AppSettings.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'autoLocation': autoLocation,
        'manualZone': manualZone,
        'images': images,
        'folder': folder,
        'interval': interval,
        'use12h': use12h,
        'autostart': autostart,
        'pin': pin,
        'role': role,
        'masterHost': masterHost,
        'masterPin': masterPin,
      };

  factory AppSettings.fromJson(Map<String, dynamic> m) => AppSettings(
        mode: m['mode'] as String? ?? 'rumah',
        autoLocation: m['autoLocation'] as bool? ?? true,
        manualZone: m['manualZone'] as String?,
        images: (m['images'] as List?)?.cast<String>() ?? [],
        folder: m['folder'] as String?,
        interval: (m['interval'] as num?)?.toInt() ?? 6,
        use12h: m['use12h'] as bool? ?? true,
        autostart: m['autostart'] as bool? ?? true,
        pin: m['pin'] as String?,
        role: m['role'] as String? ?? 'utama',
        masterHost: m['masterHost'] as String? ?? '',
        masterPin: m['masterPin'] as String? ?? '',
      );

  static const _key = 'app_settings_v1';

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    AppSettings s;
    try {
      s = raw == null
          ? AppSettings()
          : AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      s = AppSettings();
    }
    await s.save(); // simpan PIN yang baru dijana
    return s;
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(toJson()));
  }
}
