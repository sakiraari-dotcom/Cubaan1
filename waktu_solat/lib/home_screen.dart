import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';

import 'services.dart';
import 'settings.dart';
import 'settings_screen.dart';

const kAccent = Color(0xFFE8C77A);
const kInk = Color(0xFFF4F1EA);
const kDark = Color(0xFF060A09);

const _hari = ['Isnin', 'Selasa', 'Rabu', 'Khamis', 'Jumaat', 'Sabtu', 'Ahad'];
const _bulan = [
  'Januari', 'Februari', 'Mac', 'April', 'Mei', 'Jun', 'Julai', 'Ogos',
  'September', 'Oktober', 'November', 'Disember'
];
const _bulanHijri = [
  'Muharram', 'Safar', 'Rabiulawal', 'Rabiulakhir', 'Jamadilawal',
  'Jamadilakhir', 'Rejab', 'Syaaban', 'Ramadan', 'Syawal', 'Zulkaedah',
  'Zulhijjah'
];
const _placeholderTints = [
  Color(0xFF2C4A3F), Color(0xFF4A3A2A), Color(0xFF24394F), Color(0xFF47304A)
];
const _imageExt = ['.jpg', '.jpeg', '.png', '.webp', '.bmp', '.gif'];

String _two(int n) => n.toString().padLeft(2, '0');

class HomeScreen extends StatefulWidget {
  final AppSettings initialSettings;
  const HomeScreen({super.key, required this.initialSettings});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late AppSettings _s = widget.initialSettings;
  DateTime _now = DateTime.now();
  ZoneInfo? _zone;
  DayTimes? _today;
  DayTimes? _tomorrow;
  String? _status;
  DateTime? _locatedAt;
  bool _online = false;

  List<String> _images = [];
  int _slide = 0;

  bool _controlsVisible = false;
  Timer? _clockTimer, _slideTimer, _refreshTimer, _hideTimer;
  DateTime? _lastLocate;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final prevDay = _now.day;
      setState(() => _now = DateTime.now());
      if (_now.day != prevDay) _loadTimes();
    });
    _refreshTimer =
        Timer.periodic(const Duration(minutes: 30), (_) => _refresh());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadImages();
      _refresh(forceLocate: true);
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _slideTimer?.cancel();
    _refreshTimer?.cancel();
    _hideTimer?.cancel();
    _focus.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ data

  Future<void> _refresh({bool forceLocate = false}) async {
    final needLocate = forceLocate ||
        _zone == null ||
        _lastLocate == null ||
        DateTime.now().difference(_lastLocate!) > const Duration(hours: 6);

    if (!_s.autoLocation && _s.manualZone != null) {
      final zones = await LocationService.allZones();
      final z = zones.where((e) => e.code == _s.manualZone).firstOrNull;
      _zone = ZoneInfo(
          _s.manualZone!, z == null ? 'Zon pilihan' : '${z.district}, ${z.state}');
      _online = zones.isNotEmpty;
    } else if (needLocate) {
      _zone ??= await LocationService.lastZone();
      if (mounted) setState(() {});
      final z = await LocationService.detectZone();
      if (z != null) {
        _zone = z;
        _online = true;
        _locatedAt = DateTime.now();
        _lastLocate = DateTime.now();
      } else {
        _online = false;
      }
    }
    await _loadTimes();
  }

  Future<void> _loadTimes() async {
    final zone = _zone;
    if (zone == null) {
      setState(() => _status =
          'Lokasi belum dapat dikesan. Sambung ke Wi-Fi atau pilih zon di Tetapan.');
      return;
    }
    final today = DateTime.now();
    final t = await PrayerService.forDate(zone.code, today);
    final tm =
        await PrayerService.forDate(zone.code, today.add(const Duration(days: 1)));
    if (!mounted) return;
    setState(() {
      _today = t;
      _tomorrow = tm;
      _status = t == null
          ? 'Waktu solat belum dapat dimuat turun. Sila sambung ke internet.'
          : null;
    });
  }

  Future<void> _loadImages() async {
    final list = <String>[..._s.images.where((p) => File(p).existsSync())];
    final folder = _s.folder;
    if (folder != null && Directory(folder).existsSync()) {
      try {
        final files = Directory(folder)
            .listSync()
            .whereType<File>()
            .map((f) => f.path)
            .where((p) => _imageExt.any((e) => p.toLowerCase().endsWith(e)))
            .toList()
          ..sort();
        list.addAll(files);
      } catch (_) {}
    }
    setState(() {
      _images = list;
      _slide = 0;
    });
    _startSlides();
  }

  void _startSlides() {
    _slideTimer?.cancel();
    _slideTimer = Timer.periodic(Duration(seconds: _s.interval), (_) {
      final n = _images.isEmpty ? _placeholderTints.length : _images.length;
      if (n < 2) return;
      setState(() => _slide = (_slide + 1) % n);
      _precacheNext();
    });
  }

  void _precacheNext() {
    if (_images.length < 2) return;
    final next = _images[(_slide + 1) % _images.length];
    precacheImage(FileImage(File(next)), context).catchError((_) {});
  }

  // ------------------------------------------------------- tindakan

  void _showControls() {
    _hideTimer?.cancel();
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  Future<void> _openSettings() async {
    final result = await Navigator.of(context).push<AppSettings>(
      MaterialPageRoute(builder: (_) => SettingsScreen(settings: _s.copy())),
    );
    if (result == null) return;
    final locationChanged = result.autoLocation != _s.autoLocation ||
        result.manualZone != _s.manualZone;
    setState(() => _s = result);
    await _loadImages();
    if (locationChanged) {
      _zone = null;
      await _refresh(forceLocate: true);
    } else {
      setState(() {});
    }
    _focus.requestFocus();
  }

  Future<void> _toggleFullscreen() async {
    if (!Platform.isWindows) return;
    final fs = await windowManager.isFullScreen();
    await windowManager.setFullScreen(!fs);
  }

  // --------------------------------------------------------- paparan

  String _fmt(DateTime t, {bool withSuffix = false}) {
    if (!_s.use12h) return '${_two(t.hour)}:${_two(t.minute)}';
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final suffix = withSuffix ? (t.hour < 12 ? ' PG' : ' PTG') : '';
    return '$h:${_two(t.minute)}$suffix';
  }

  String _hijriText() {
    final h = _today?.hijri ?? '';
    final p = h.split('-');
    if (p.length != 3) return '';
    final m = int.tryParse(p[1]) ?? 0;
    if (m < 1 || m > 12) return '';
    return '${int.parse(p[2])} ${_bulanHijri[m - 1]} ${p[0]}H';
  }

  /// Indeks waktu seterusnya dan masa baki.
  (int, Duration)? _next() {
    final t = _today;
    if (t == null) return null;
    for (var i = 0; i < t.times.length; i++) {
      if (t.times[i].isAfter(_now)) return (i, t.times[i].difference(_now));
    }
    final tm = _tomorrow;
    if (tm != null) return (0, tm.times[0].difference(_now));
    return null;
  }

  String _countdown(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    return '${h > 0 ? '$h jam ' : ''}$m min ${_two(s)} s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.f11): _toggleFullscreen,
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (Platform.isWindows) windowManager.setFullScreen(false);
          },
          const SingleActivator(LogicalKeyboardKey.keyS): _openSettings,
        },
        child: Focus(
          focusNode: _focus,
          autofocus: true,
          child: MouseRegion(
            onHover: (_) => _showControls(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _showControls,
              child: LayoutBuilder(builder: (ctx, c) => _body(c)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BoxConstraints c) {
    final w = c.maxWidth;
    final compact = w < 900;
    final double sc = compact
        ? (w / 420).clamp(0.75, 1.2).toDouble()
        : (w / 1600).clamp(0.6, 1.6).toDouble();
    final pad = (compact ? 20.0 : 64.0) * (compact ? 1 : sc);

    final body = GoogleFonts.figtree(color: kInk);
    final num = GoogleFonts.spaceGrotesk(color: kInk, fontWeight: FontWeight.w600);

    return Stack(
      fit: StackFit.expand,
      children: [
        _background(sc),
        // lapisan gelap supaya tulisan jelas dibaca
        const Positioned(
          left: 0, right: 0, bottom: 0, height: 480,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xEB060A09), Color(0xBF060A09), Color(0x00060A09)],
                stops: [0, 0.45, 1],
              ),
            ),
          ),
        ),
        const Positioned(
          left: 0, right: 0, top: 0, height: 240,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xB3060A09), Color(0x00060A09)],
              ),
            ),
          ),
        ),
        Positioned(
          top: pad * (compact ? 1.4 : 0.75),
          left: pad,
          right: pad,
          child: _topBar(compact, sc, body, num),
        ),
        Positioned(
          left: pad,
          right: pad,
          bottom: pad * 0.75,
          child: _bottomPanel(compact, sc, body, num),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: AnimatedOpacity(
            opacity: _controlsVisible ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: !_controlsVisible,
              child: Row(children: [
                if (Platform.isWindows)
                  _roundButton(Icons.fullscreen, 'Skrin penuh (F11)',
                      _toggleFullscreen),
                const SizedBox(width: 8),
                _roundButton(Icons.settings_outlined, 'Tetapan', _openSettings),
              ]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _roundButton(IconData icon, String tip, VoidCallback onTap) {
    return Tooltip(
      message: tip,
      child: Material(
        color: const Color(0xCC060A09),
        shape: const CircleBorder(side: BorderSide(color: Color(0x33FFFFFF))),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, color: kInk, semanticLabel: tip),
          ),
        ),
      ),
    );
  }

  Widget _background(double sc) {
    Widget child;
    if (_images.isEmpty) {
      final i = _slide % _placeholderTints.length;
      child = Container(
        key: ValueKey('ph$i'),
        color: _placeholderTints[i],
        alignment: Alignment.center,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.photo_outlined, size: 64, color: Colors.white.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text('Tambah gambar keluarga di Tetapan',
              style: GoogleFonts.figtree(
                  fontSize: 18, color: Colors.white.withValues(alpha: 0.6))),
        ]),
      );
    } else {
      final path = _images[_slide % _images.length];
      child = Image.file(
        File(path),
        key: ValueKey(path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => Container(color: _placeholderTints[0]),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 1200),
      child: child,
    );
  }

  Widget _topBar(bool compact, double sc, TextStyle body, TextStyle num) {
    final clockSize = (compact ? 72.0 : 112.0) * sc;
    final clock = _s.use12h
        ? '${_now.hour % 12 == 0 ? 12 : _now.hour % 12}:${_two(_now.minute)}'
        : '${_two(_now.hour)}:${_two(_now.minute)}';
    final suffix = _s.use12h ? (_now.hour < 12 ? 'PG' : 'PTG') : '';
    final dateText =
        '${_hari[_now.weekday - 1]}, ${_now.day} ${_bulan[_now.month - 1]} ${_now.year}';

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(clock,
                style: num.copyWith(
                    fontSize: clockSize, height: 1, letterSpacing: -2)),
            SizedBox(width: 8 * sc),
            Text(_two(_now.second),
                style: num.copyWith(
                    fontSize: clockSize * 0.36,
                    fontWeight: FontWeight.w500,
                    color: kInk.withValues(alpha: 0.7))),
            if (suffix.isNotEmpty) ...[
              SizedBox(width: 8 * sc),
              Text(suffix,
                  style: body.copyWith(
                      fontSize: clockSize * 0.22,
                      color: kInk.withValues(alpha: 0.7))),
            ],
          ],
        ),
        SizedBox(height: 6 * sc),
        Text(dateText,
            style: body.copyWith(
                fontSize: 24 * sc, color: kInk.withValues(alpha: 0.85))),
        if (_hijriText().isNotEmpty)
          Text(_hijriText(),
              style: body.copyWith(fontSize: 20 * sc, color: kAccent)),
      ],
    );

    final locLine = Container(
      padding: EdgeInsets.symmetric(horizontal: 18 * sc, vertical: 10 * sc),
      decoration: BoxDecoration(
        color: const Color(0x8C060A09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.location_on_outlined, size: 20 * sc, color: kInk),
        SizedBox(width: 8 * sc),
        Flexible(
          child: Text(
            _zone == null ? 'Mengesan lokasi…' : '${_zone!.label} · ${_zone!.code}',
            overflow: TextOverflow.ellipsis,
            style: body.copyWith(fontSize: 18 * sc),
          ),
        ),
      ]),
    );

    final netLine = Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(_online ? Icons.wifi : Icons.wifi_off,
          size: 18 * sc, color: kInk.withValues(alpha: 0.75)),
      SizedBox(width: 8 * sc),
      Text(
        !_s.autoLocation
            ? 'Zon dipilih secara manual'
            : _online
                ? 'Internet disambung${_locatedAt == null ? '' : ' · lokasi dikemas kini ${_fmt(_locatedAt!)}'}'
                : 'Luar talian · guna data tersimpan',
        style: body.copyWith(
            fontSize: 15 * sc, color: kInk.withValues(alpha: 0.75)),
      ),
    ]);

    if (compact) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        left,
        SizedBox(height: 14 * sc),
        locLine,
        SizedBox(height: 8 * sc),
        netLine,
      ]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        left,
        const Spacer(),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [locLine, SizedBox(height: 10 * sc), netLine],
          ),
        ),
      ],
    );
  }

  Widget _bottomPanel(bool compact, double sc, TextStyle body, TextStyle num) {
    final next = _next();
    final today = _today;

    final header = next == null
        ? Text(_status ?? 'Memuatkan waktu solat…',
            style: body.copyWith(fontSize: 20 * sc))
        : Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 14 * sc,
            children: [
              Text('Waktu seterusnya',
                  style: body.copyWith(
                      fontSize: 22 * sc, color: kInk.withValues(alpha: 0.8))),
              Text(prayerFields[next.$1].$1,
                  style: num.copyWith(fontSize: 34 * sc, color: kAccent)),
              Text('dalam',
                  style: body.copyWith(
                      fontSize: 22 * sc, color: kInk.withValues(alpha: 0.8))),
              Text(_countdown(next.$2), style: num.copyWith(fontSize: 34 * sc)),
            ],
          );

    final cols = compact ? 4 : 7;
    final gap = 12.0 * (compact ? 0.7 : sc);

    Widget card(int i) {
      final on = next != null && next.$1 == i && today != null &&
          // sorot hanya jika waktu seterusnya hari ini (bukan Imsak esok)
          today.times[i].isAfter(_now);
      final fg = on ? const Color(0xFF14110A) : kInk;
      return Container(
        padding: EdgeInsets.symmetric(
            horizontal: 20 * sc, vertical: (compact ? 14 : 20) * sc),
        decoration: BoxDecoration(
          color: on ? kAccent : const Color(0x80060A09),
          borderRadius: BorderRadius.circular(16 * sc),
          border: on ? null : Border.all(color: const Color(0x24FFFFFF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(prayerFields[i].$1.toUpperCase(),
                style: body.copyWith(
                    fontSize: (compact ? 13 : 18) * sc,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: on ? fg : kInk.withValues(alpha: 0.75))),
            SizedBox(height: 8 * sc),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                today == null ? '--:--' : _fmt(today.times[i]),
                style: num.copyWith(
                    fontSize: (compact ? 26 : 40) * sc, height: 1, color: fg),
              ),
            ),
          ],
        ),
      );
    }

    final grid = LayoutBuilder(builder: (ctx, c) {
      final itemW = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (var i = 0; i < prayerFields.length; i++)
            SizedBox(width: itemW, child: card(i)),
        ],
      );
    });

    final n = _images.isEmpty ? _placeholderTints.length : _images.length;
    final dots = Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < n.clamp(0, 12); i++)
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          margin: const EdgeInsets.only(left: 8),
          width: i == _slide % n ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: i == _slide % n ? kAccent : const Color(0x59FFFFFF),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
    ]);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        SizedBox(height: 20 * sc),
        grid,
        SizedBox(height: 16 * sc),
        Row(children: [
          Expanded(
            child: Text(
              'Sumber: JAKIM e-Solat melalui waktusolat.app',
              style: body.copyWith(
                  fontSize: 13 * sc.clamp(1.0, 1.6).toDouble(),
                  color: kInk.withValues(alpha: 0.6)),
            ),
          ),
          if (n <= 12) dots,
        ]),
      ],
    );
  }
}
