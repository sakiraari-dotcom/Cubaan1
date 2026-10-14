import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'masjid_config.dart';
import 'server.dart';
import 'services.dart';
import 'settings.dart';

/// Keadaan utama aplikasi: tetapan, kandungan masjid, lokasi dan waktu solat.
class AppState extends ChangeNotifier {
  AppSettings settings;
  MasjidConfig masjid;
  AppState(this.settings, this.masjid);

  DateTime now = DateTime.now();
  ZoneInfo? zone;
  DayTimes? today;
  DayTimes? tomorrow;
  bool online = false;
  DateTime? locatedAt;
  String? status;
  String mediaPath = '';
  String? lanIp;
  String? syncStatus;

  DateTime? _lastLocate;
  Timer? _tick, _refreshTimer, _syncTimer;
  late final AdminServer server = AdminServer(this);
  final AudioPlayer _player = AudioPlayer();
  PhaseKind? _lastKind;
  int _lastPrayer = -1;

  String get adminUrl => 'http://${lanIp ?? 'localhost'}:${AdminServer.port}';

  Future<void> init() async {
    try {
      mediaPath = (await MasjidConfig.mediaDir()).path;
    } catch (_) {}
    lanIp = await _findLanIp();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    _refreshTimer =
        Timer.periodic(const Duration(minutes: 30), (_) => refresh());
    await server.start();
    _setupSync();
    refresh(forceLocate: true);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _refreshTimer?.cancel();
    _syncTimer?.cancel();
    server.stop();
    _player.dispose();
    super.dispose();
  }

  File? media(String? name) {
    if (!MasjidConfig.safeName(name) || mediaPath.isEmpty) return null;
    final f = File('$mediaPath${Platform.pathSeparator}$name');
    return f.existsSync() ? f : null;
  }

  // ------------------------------------------------------------ masa

  void _onTick() {
    final prev = now;
    now = DateTime.now();
    if (now.day != prev.day) {
      loadTimes();
      _findLanIp().then((ip) => lanIp = ip);
    }
    _checkSound();
    notifyListeners();
  }

  void _checkSound() {
    final p = computePhase(masjid, today, now, includeRest: false);
    final first = _lastKind == null;
    final changed = p.kind != _lastKind || p.prayer != _lastPrayer;
    final prevKind = _lastKind;
    _lastKind = p.kind;
    _lastPrayer = p.prayer;
    if (first || !changed) return;
    if (p.kind == PhaseKind.iqamah || p.kind == PhaseKind.jumaat) {
      _playAzan();
    } else if (p.kind == PhaseKind.solat &&
        prevKind == PhaseKind.iqamah &&
        settings.mode == 'masjid' &&
        masjid.beep) {
      _playBeep();
    }
  }

  Future<void> _playAzan() async {
    try {
      final f = media(masjid.azanAudio);
      if (f != null) {
        await _player.stop();
        await _player.play(DeviceFileSource(f.path));
      } else if (masjid.beep) {
        await _playBeep();
      }
    } catch (e) {
      debugPrint('Audio: $e');
    }
  }

  Future<void> _playBeep() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('beep.wav'));
    } catch (e) {
      debugPrint('Beep: $e');
    }
  }

  Future<void> testSound() => _playAzan();

  // ---------------------------------------------------- lokasi & waktu

  Future<void> refresh({bool forceLocate = false}) async {
    final needLocate = forceLocate ||
        zone == null ||
        _lastLocate == null ||
        DateTime.now().difference(_lastLocate!) > const Duration(hours: 6);

    if (!settings.autoLocation && settings.manualZone != null) {
      final zones = await LocationService.allZones();
      final z = zones.where((e) => e.code == settings.manualZone).firstOrNull;
      zone = ZoneInfo(settings.manualZone!,
          z == null ? 'Zon pilihan' : '${z.district}, ${z.state}');
      online = zones.isNotEmpty;
    } else if (needLocate) {
      zone ??= await LocationService.lastZone();
      notifyListeners();
      final z = await LocationService.detectZone();
      if (z != null) {
        zone = z;
        online = true;
        locatedAt = DateTime.now();
        _lastLocate = DateTime.now();
      } else {
        online = false;
      }
    }
    await loadTimes();
  }

  Future<void> loadTimes() async {
    final z = zone;
    if (z == null) {
      status =
          'Lokasi belum dapat dikesan. Sambung ke Wi-Fi atau pilih zon di Tetapan.';
      notifyListeners();
      return;
    }
    final d = DateTime.now();
    today = await PrayerService.forDate(z.code, d);
    tomorrow =
        await PrayerService.forDate(z.code, d.add(const Duration(days: 1)));
    status = today == null
        ? 'Waktu solat belum dapat dimuat turun. Sila sambung ke internet.'
        : null;
    notifyListeners();
  }

  /// Indeks waktu seterusnya dan baki masa.
  (int, Duration)? next() {
    final t = today;
    if (t == null) return null;
    for (var i = 0; i < t.times.length; i++) {
      if (t.times[i].isAfter(now)) return (i, t.times[i].difference(now));
    }
    final tm = tomorrow;
    if (tm != null) return (0, tm.times[0].difference(now));
    return null;
  }

  // -------------------------------------------------------- tetapan

  Future<void> updateSettings(AppSettings s) async {
    final locationChanged =
        s.autoLocation != settings.autoLocation || s.manualZone != settings.manualZone;
    final syncChanged = s.role != settings.role ||
        s.masterHost != settings.masterHost ||
        s.masterPin != settings.masterPin;
    settings = s;
    await s.save();
    if (syncChanged) _setupSync();
    notifyListeners();
    if (locationChanged) {
      zone = null;
      await refresh(forceLocate: true);
    }
  }

  /// Simpan kandungan masjid yang dihantar dari panel web.
  Future<void> saveMasjid(Map<String, dynamic> data) async {
    data['version'] = masjid.version + 1;
    masjid = MasjidConfig(data);
    await masjid.save();
    notifyListeners();
  }

  Future<void> setMode(String mode) async {
    if (mode != 'rumah' && mode != 'masjid') return;
    settings.mode = mode;
    await settings.save();
    notifyListeners();
  }

  // ------------------------------------------------- TV pendua (sync)

  void _setupSync() {
    _syncTimer?.cancel();
    syncStatus = null;
    if (settings.role != 'pendua' || settings.masterHost.trim().isEmpty) return;
    syncFromMaster();
    _syncTimer = Timer.periodic(
        const Duration(seconds: 60), (_) => syncFromMaster());
  }

  String get _masterBase {
    var h = settings.masterHost.trim();
    if (!h.startsWith('http')) h = 'http://$h';
    final u = Uri.parse(h);
    return u.hasPort && u.port != 80 ? '${u.scheme}://${u.host}:${u.port}' : '${u.scheme}://${u.host}:${AdminServer.port}';
  }

  Future<void> syncFromMaster() async {
    try {
      final base = _masterBase;
      final r = await http.get(Uri.parse('$base/api/config'),
          headers: {'X-Pin': settings.masterPin}).timeout(const Duration(seconds: 15));
      if (r.statusCode == 401) {
        syncStatus = 'PIN TV utama salah';
        notifyListeners();
        return;
      }
      if (r.statusCode != 200) throw 'HTTP ${r.statusCode}';
      final body = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      final cfg = MasjidConfig(Map<String, dynamic>.from(body['config'] as Map));
      for (final n in cfg.mediaNames) {
        if (media(n) != null) continue;
        final m = await http.get(Uri.parse('$base/media/$n')).timeout(const Duration(seconds: 60));
        if (m.statusCode == 200) {
          await File('$mediaPath${Platform.pathSeparator}$n').writeAsBytes(m.bodyBytes);
        }
      }
      if (cfg.version != masjid.version) {
        masjid = cfg;
        await masjid.save();
      }
      final mode = body['mode'];
      if (mode is String && mode != settings.mode) {
        settings.mode = mode;
        await settings.save();
      }
      syncStatus = 'Disegerakkan dengan TV utama';
    } catch (e) {
      syncStatus = 'Tidak dapat hubungi TV utama';
    }
    notifyListeners();
  }

  // ----------------------------------------------------------- rangkaian

  static Future<String?> _findLanIp() async {
    try {
      final ifs = await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLoopback: false);
      final all = [for (final i in ifs) ...i.addresses.map((a) => a.address)];
      for (final pre in ['192.168.', '10.', '172.']) {
        final hit = all.where((a) => a.startsWith(pre)).firstOrNull;
        if (hit != null) return hit;
      }
      return all.firstOrNull;
    } catch (_) {
      return null;
    }
  }
}
