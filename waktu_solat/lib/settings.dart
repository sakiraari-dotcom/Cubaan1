import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Tetapan pengguna yang disimpan dalam peranti.
class AppSettings {
  bool autoLocation;
  String? manualZone;
  List<String> images;
  String? folder;
  int interval; // saat
  bool use12h;
  bool autostart;

  AppSettings({
    this.autoLocation = true,
    this.manualZone,
    List<String>? images,
    this.folder,
    this.interval = 6,
    this.use12h = true,
    this.autostart = true,
  }) : images = images ?? [];

  AppSettings copy() => AppSettings(
        autoLocation: autoLocation,
        manualZone: manualZone,
        images: List.of(images),
        folder: folder,
        interval: interval,
        use12h: use12h,
        autostart: autostart,
      );

  static const _key = 'app_settings_v1';

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return AppSettings();
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return AppSettings(
        autoLocation: m['autoLocation'] as bool? ?? true,
        manualZone: m['manualZone'] as String?,
        images: (m['images'] as List?)?.cast<String>() ?? [],
        folder: m['folder'] as String?,
        interval: m['interval'] as int? ?? 6,
        use12h: m['use12h'] as bool? ?? true,
        autostart: m['autostart'] as bool? ?? true,
      );
    } catch (_) {
      return AppSettings();
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'autoLocation': autoLocation,
        'manualZone': manualZone,
        'images': images,
        'folder': folder,
        'interval': interval,
        'use12h': use12h,
        'autostart': autostart,
      }),
    );
  }
}
