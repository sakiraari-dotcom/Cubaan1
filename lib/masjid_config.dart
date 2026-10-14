import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services.dart';

/// Kunci waktu yang ada iqamah, dan indeksnya dalam [prayerFields].
const iqamahKeys = ['subuh', 'zohor', 'asar', 'maghrib', 'isyak'];
const iqamahIndex = {'subuh': 1, 'zohor': 3, 'asar': 4, 'maghrib': 5, 'isyak': 6};

const jawiNames = {
  'Imsak': 'امساك',
  'Subuh': 'صبح',
  'Syuruk': 'شروق',
  'Zohor': 'ظهر',
  'Asar': 'عصر',
  'Maghrib': 'مغرب',
  'Isyak': 'عشاء',
  'Jumaat': 'جمعة',
};

const bulanHijri = [
  'Muharram', 'Safar', 'Rabiulawal', 'Rabiulakhir', 'Jamadilawal',
  'Jamadilakhir', 'Rejab', 'Syaaban', 'Ramadan', 'Syawal', 'Zulkaedah',
  'Zulhijjah'
];

const verseJumaat = {
  'ar': 'يَا أَيُّهَا الَّذِينَ آمَنُوا إِذَا نُودِيَ لِلصَّلَاةِ مِن يَوْمِ الْجُمُعَةِ فَاسْعَوْا إِلَىٰ ذِكْرِ اللَّهِ وَذَرُوا الْبَيْعَ',
  'ms': 'Wahai orang beriman, apabila diseru untuk solat pada hari Jumaat, bersegeralah kepada mengingati Allah dan tinggalkanlah jual beli.',
  'ref': "Al-Jumu'ah 62:9",
};

/// Ayat lalai. Pihak masjid boleh ubah, tambah atau matikan melalui panel.
const _defaultVerses = [
  {
    'ar': 'وَأَقِيمُوا الصَّلَاةَ وَآتُوا الزَّكَاةَ وَارْكَعُوا مَعَ الرَّاكِعِينَ',
    'ms': 'Dirikanlah solat, tunaikanlah zakat dan rukuklah bersama orang yang rukuk.',
    'ref': 'Al-Baqarah 2:43',
    'active': true,
  },
  {
    'ar': 'يَا أَيُّهَا الَّذِينَ آمَنُوا اسْتَعِينُوا بِالصَّبْرِ وَالصَّلَاةِ ۚ إِنَّ اللَّهَ مَعَ الصَّابِرِينَ',
    'ms': 'Wahai orang beriman, mohonlah pertolongan dengan sabar dan solat; sesungguhnya Allah bersama orang yang sabar.',
    'ref': 'Al-Baqarah 2:153',
    'active': true,
  },
  {
    'ar': 'فَاذْكُرُونِي أَذْكُرْكُمْ وَاشْكُرُوا لِي وَلَا تَكْفُرُونِ',
    'ms': 'Ingatlah kepada-Ku, nescaya Aku ingat kepadamu; bersyukurlah kepada-Ku dan janganlah kamu kufur.',
    'ref': 'Al-Baqarah 2:152',
    'active': true,
  },
  {
    'ar': 'أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ',
    'ms': 'Ketahuilah, dengan mengingati Allah hati menjadi tenteram.',
    'ref': "Ar-Ra'd 13:28",
    'active': true,
  },
  {
    'ar': 'إِنَّ الصَّلَاةَ تَنْهَىٰ عَنِ الْفَحْشَاءِ وَالْمُنكَرِ',
    'ms': 'Sesungguhnya solat itu mencegah daripada perbuatan keji dan mungkar.',
    'ref': "Al-'Ankabut 29:45",
    'active': true,
  },
  {
    'ar': 'فَإِنَّ مَعَ الْعُسْرِ يُسْرًا ۝ إِنَّ مَعَ الْعُسْرِ يُسْرًا',
    'ms': 'Maka sesungguhnya bersama kesulitan ada kemudahan. Sesungguhnya bersama kesulitan ada kemudahan.',
    'ref': 'Asy-Syarh 94:5-6',
    'active': true,
  },
];

Map<String, dynamic> _defaults() => {
      'version': 1,
      'name': 'Masjid [Nama Masjid]',
      'locationText': '',
      'logo': null,
      'accent': '#E8C77A',
      'iqamah': {'subuh': 15, 'zohor': 10, 'asar': 10, 'maghrib': 7, 'isyak': 10},
      'solatMinutes': 10,
      'khutbahMinutes': 30,
      'jumaatSolatMinutes': 15,
      'petugas': {'khatib': '', 'imam': '', 'bilal': '', 'imamBertugas': ''},
      'tabung': '',
      'qr': null,
      'announcements': [
        {'text': 'Selamat datang. Sila senyapkan telefon bimbit di dalam masjid.', 'active': true},
      ],
      'slides': <dynamic>[],
      'verses': _defaultVerses.map((e) => Map<String, dynamic>.from(e)).toList(),
      'slideSeconds': 10,
      'beep': true,
      'azanAudio': null,
      'rest': {'enabled': false, 'start': '23:30', 'end': '04:30'},
      'puasaReminder': true,
      'jawi': true,
    };

/// Semua kandungan Mod Masjid. Disimpan sebagai JSON supaya mudah
/// dihantar antara panel web, TV utama dan TV pendua.
class MasjidConfig {
  final Map<String, dynamic> data;
  MasjidConfig(Map<String, dynamic> d) : data = {..._defaults(), ...d};

  factory MasjidConfig.defaults() => MasjidConfig(_defaults());

  static const _key = 'masjid_config_v1';

  static Future<MasjidConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return MasjidConfig.defaults();
    try {
      return MasjidConfig(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return MasjidConfig.defaults();
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data));
  }

  // ------------------------------------------------------------ media

  static Future<Directory> mediaDir() async {
    final base = await getApplicationSupportDirectory();
    final d = Directory('${base.path}${Platform.pathSeparator}media');
    await d.create(recursive: true);
    return d;
  }

  static bool safeName(String? n) =>
      n != null && n.isNotEmpty && RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(n) && !n.startsWith('.');

  /// Semua nama fail media yang dirujuk oleh konfigurasi ini.
  List<String> get mediaNames {
    final out = <String>[];
    for (final n in [data['logo'], data['qr'], data['azanAudio']]) {
      if (n is String && safeName(n)) out.add(n);
    }
    for (final s in slides) {
      final n = s['image'];
      if (n is String && safeName(n)) out.add(n);
    }
    return out;
  }

  // ---------------------------------------------------------- getters

  int get version => (data['version'] as num?)?.toInt() ?? 1;
  String get name => (data['name'] as String?) ?? '';
  String get locationText => (data['locationText'] as String?) ?? '';
  String? get logo => data['logo'] as String?;
  String? get qr => data['qr'] as String?;
  String? get azanAudio => data['azanAudio'] as String?;
  String get tabung => (data['tabung'] as String?) ?? '';
  bool get beep => data['beep'] != false;
  bool get jawi => data['jawi'] != false;
  bool get puasaReminder => data['puasaReminder'] != false;
  int get slideSeconds => _int(data['slideSeconds'], 10).clamp(3, 120);
  int get solatMinutes => _int(data['solatMinutes'], 10).clamp(0, 60);
  int get khutbahMinutes => _int(data['khutbahMinutes'], 30).clamp(0, 90);
  int get jumaatSolatMinutes => _int(data['jumaatSolatMinutes'], 15).clamp(0, 60);

  int iqamah(String k) =>
      _int((data['iqamah'] as Map?)?[k], 10).clamp(0, 60);

  String petugas(String k) => ((data['petugas'] as Map?)?[k] as String?) ?? '';

  int get accentValue {
    final s = ((data['accent'] as String?) ?? '#E8C77A').replaceAll('#', '');
    final v = int.tryParse(s.length == 6 ? 'FF$s' : s, radix: 16);
    return v ?? 0xFFE8C77A;
  }

  List<Map<String, dynamic>> _list(String key) => ((data[key] as List?) ?? [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  List<Map<String, dynamic>> get slides => _list('slides');
  List<Map<String, dynamic>> get activeSlides =>
      slides.where((s) => s['active'] != false).toList();
  List<String> get activeAnnouncements => _list('announcements')
      .where((a) => a['active'] != false && (a['text'] as String? ?? '').trim().isNotEmpty)
      .map((a) => (a['text'] as String).trim())
      .toList();
  List<Map<String, dynamic>> get activeVerses => _list('verses')
      .where((v) => v['active'] != false && (v['ar'] as String? ?? '').isNotEmpty)
      .toList();

  bool get restEnabled => (data['rest'] as Map?)?['enabled'] == true;
  int _hm(String? s, int fallback) {
    final p = (s ?? '').split(':');
    if (p.length != 2) return fallback;
    final h = int.tryParse(p[0]), m = int.tryParse(p[1]);
    if (h == null || m == null) return fallback;
    return h * 60 + m;
  }

  bool inRest(DateTime now) {
    if (!restEnabled) return false;
    final r = data['rest'] as Map;
    final start = _hm(r['start'] as String?, 23 * 60 + 30);
    final end = _hm(r['end'] as String?, 4 * 60 + 30);
    final m = now.hour * 60 + now.minute;
    return start <= end ? (m >= start && m < end) : (m >= start || m < end);
  }

  static int _int(dynamic v, int fallback) =>
      v is num ? v.toInt() : int.tryParse('$v') ?? fallback;
}

// ------------------------------------------------------------- fasa

enum PhaseKind { normal, iqamah, solat, jumaat, rest }

class Phase {
  final PhaseKind kind;
  final int prayer; // indeks dalam prayerFields, -1 jika tiada
  final DateTime? start;
  final DateTime? until;
  const Phase(this.kind, {this.prayer = -1, this.start, this.until});
}

/// Tentukan apa yang patut dipaparkan pada masa [now].
Phase computePhase(MasjidConfig c, DayTimes? t, DateTime now,
    {bool includeRest = true}) {
  if (t != null) {
    final friday = now.weekday == DateTime.friday;
    for (final k in iqamahKeys) {
      final i = iqamahIndex[k]!;
      final azan = t.times[i];
      if (friday && k == 'zohor') {
        final kEnd = azan.add(Duration(minutes: c.khutbahMinutes));
        final sEnd = kEnd.add(Duration(minutes: c.jumaatSolatMinutes));
        if (!now.isBefore(azan) && now.isBefore(kEnd)) {
          return Phase(PhaseKind.jumaat, prayer: i, start: azan, until: kEnd);
        }
        if (!now.isBefore(kEnd) && now.isBefore(sEnd)) {
          return Phase(PhaseKind.solat, prayer: i, start: kEnd, until: sEnd);
        }
        continue;
      }
      final iq = azan.add(Duration(minutes: c.iqamah(k)));
      final end = iq.add(Duration(minutes: c.solatMinutes));
      if (!now.isBefore(azan) && now.isBefore(iq)) {
        return Phase(PhaseKind.iqamah, prayer: i, start: azan, until: iq);
      }
      if (!now.isBefore(iq) && now.isBefore(end)) {
        return Phase(PhaseKind.solat, prayer: i, start: iq, until: end);
      }
    }
  }
  if (includeRest && c.inRest(now)) return const Phase(PhaseKind.rest);
  return const Phase(PhaseKind.normal);
}

/// Peringatan puasa sunat berdasarkan hari dan tarikh Hijrah (YYYY-MM-DD).
List<String> puasaReminders(DateTime now, String hijri) {
  final p = hijri.split('-');
  final hm = p.length == 3 ? int.tryParse(p[1]) ?? 0 : 0;
  final hd = p.length == 3 ? int.tryParse(p[2]) ?? 0 : 0;
  if (hm == 9) return []; // Ramadan
  // Esoknya Aidiladha atau hari Tasyrik (10–13 Zulhijjah): haram berpuasa
  if (hm == 12 && hd >= 9 && hd <= 12) return [];
  final out = <String>[];
  if (now.weekday == DateTime.sunday) {
    out.add('Esok hari Isnin — digalakkan berpuasa sunat.');
  } else if (now.weekday == DateTime.wednesday) {
    out.add('Esok hari Khamis — digalakkan berpuasa sunat.');
  }
  if (hd >= 12 && hd <= 14 && hm >= 1 && hm <= 11) {
    out.add('Ayyamul Bidh 13–15 ${bulanHijri[hm - 1]} — digalakkan berpuasa sunat.');
  }
  return out;
}
