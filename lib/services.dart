import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _api = 'https://api.waktusolat.app';

/// Nama waktu yang dipaparkan dan kunci medan dalam data API.
const prayerFields = <(String, String)>[
  ('Imsak', 'imsak'),
  ('Subuh', 'fajr'),
  ('Syuruk', 'syuruk'),
  ('Zohor', 'dhuhr'),
  ('Asar', 'asr'),
  ('Maghrib', 'maghrib'),
  ('Isyak', 'isha'),
];

const stateNames = {
  'JHR': 'Johor',
  'KDH': 'Kedah',
  'KTN': 'Kelantan',
  'MLK': 'Melaka',
  'NGS': 'Negeri Sembilan',
  'PHG': 'Pahang',
  'PLS': 'Perlis',
  'PNG': 'Pulau Pinang',
  'PRK': 'Perak',
  'SBH': 'Sabah',
  'SGR': 'Selangor',
  'SWK': 'Sarawak',
  'TRG': 'Terengganu',
  'WLY': 'W.P.',
};

class ZoneInfo {
  final String code;
  final String label;
  const ZoneInfo(this.code, this.label);
}

class DayTimes {
  final DateTime date;
  final String hijri; // YYYY-MM-DD
  final List<DateTime> times; // ikut susunan prayerFields
  DayTimes(this.date, this.hijri, this.times);
}

class JakimZone {
  final String code;
  final String state;
  final String district;
  JakimZone(this.code, this.state, this.district);
}

Future<http.Response> _get(String path) =>
    http.get(Uri.parse('$_api$path')).timeout(const Duration(seconds: 20));

// ---------------------------------------------------------------- lokasi

class LocationService {
  /// Cari koordinat: lokasi peranti dahulu (GPS/Wi-Fi), kemudian anggaran IP.
  static Future<(double, double)?> _coords() async {
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.always ||
            perm == LocationPermission.whileInUse) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings:
                const LocationSettings(accuracy: LocationAccuracy.low),
          ).timeout(const Duration(seconds: 20));
          return (pos.latitude, pos.longitude);
        }
      }
    } catch (_) {
      // teruskan ke anggaran IP
    }
    try {
      final r = await http
          .get(Uri.parse('https://ipwho.is/'))
          .timeout(const Duration(seconds: 15));
      final m = jsonDecode(r.body) as Map<String, dynamic>;
      if (m['success'] == true) {
        return (
          (m['latitude'] as num).toDouble(),
          (m['longitude'] as num).toDouble(),
        );
      }
    } catch (_) {}
    return null;
  }

  /// Kesan zon JAKIM berdasarkan lokasi. Pulangkan null jika gagal.
  static Future<ZoneInfo?> detectZone() async {
    final c = await _coords();
    if (c == null) return null;
    try {
      final r = await _get('/zones/${c.$1}/${c.$2}');
      if (r.statusCode != 200) return null;
      final m = jsonDecode(r.body) as Map<String, dynamic>;
      final code = m['zone'] as String;
      final st = stateNames[m['state']] ?? m['state'] ?? '';
      final info = ZoneInfo(code, '${m['district']}, $st');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_zone', '${info.code}|${info.label}');
      return info;
    } catch (_) {
      return null;
    }
  }

  static Future<ZoneInfo?> lastZone() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('last_zone');
    if (s == null || !s.contains('|')) return null;
    final p = s.split('|');
    return ZoneInfo(p[0], p[1]);
  }

  static Future<List<JakimZone>> allZones() async {
    final prefs = await SharedPreferences.getInstance();
    String? raw;
    try {
      final r = await _get('/zones');
      if (r.statusCode == 200) {
        raw = r.body;
        await prefs.setString('zones_cache', raw);
      }
    } catch (_) {}
    raw ??= prefs.getString('zones_cache');
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => JakimZone(e['jakimCode'], e['negeri'], e['daerah']))
        .toList();
  }
}

// ---------------------------------------------------------- waktu solat

class PrayerService {
  /// Dapatkan waktu bagi tarikh tertentu. Data sebulan disimpan dalam
  /// peranti supaya masih berfungsi tanpa internet.
  static Future<DayTimes?> forDate(String zone, DateTime d) async {
    final key = 'solat_${zone}_${d.year}_${d.month}';
    final prefs = await SharedPreferences.getInstance();
    var raw = prefs.getString(key);
    if (raw == null) {
      try {
        final r = await _get('/v2/solat/$zone?year=${d.year}&month=${d.month}');
        if (r.statusCode == 200) {
          raw = r.body;
          await prefs.setString(key, raw);
        }
      } catch (_) {}
    }
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      for (final p in (m['prayers'] as List)) {
        if (p['day'] == d.day) {
          final times = prayerFields
              .map((f) => DateTime.fromMillisecondsSinceEpoch(
                    (p[f.$2] as num).toInt() * 1000,
                    isUtc: true,
                  ).toLocal())
              .toList();
          return DayTimes(
            DateTime(d.year, d.month, d.day),
            p['hijri'] as String? ?? '',
            times,
          );
        }
      }
    } catch (_) {
      await prefs.remove(key);
    }
    return null;
  }
}
