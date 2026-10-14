import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import 'app_state.dart';
import 'masjid_screen.dart';
import 'services.dart';
import 'settings_screen.dart';
import 'ui_common.dart';

const _placeholderTints = [
  Color(0xFF2C4A3F), Color(0xFF4A3A2A), Color(0xFF24394F), Color(0xFF47304A)
];
const _imageExt = ['.jpg', '.jpeg', '.png', '.webp', '.bmp', '.gif'];

/// Skrin akar: pilih Mod Rumah atau Mod Masjid, serta butang kawalan.
class HomeScreen extends StatefulWidget {
  final AppState app;
  const HomeScreen({super.key, required this.app});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppState get app => widget.app;

  List<String> _images = [];
  int _slide = 0;
  Timer? _slideTimer, _hideTimer;
  bool _controlsVisible = false;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadImages());
  }

  @override
  void dispose() {
    _slideTimer?.cancel();
    _hideTimer?.cancel();
    _focus.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ gambar

  void _loadImages() {
    final s = app.settings;
    final list = <String>[...s.images.where((p) => File(p).existsSync())];
    final folder = s.folder;
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
    _slideTimer?.cancel();
    _slideTimer = Timer.periodic(Duration(seconds: s.interval), (_) {
      final n = _images.isEmpty ? _placeholderTints.length : _images.length;
      if (n < 2 || !mounted) return;
      setState(() => _slide = (_slide + 1) % n);
      if (_images.length > 1) {
        precacheImage(FileImage(File(_images[(_slide + 1) % _images.length])), context)
            .catchError((_) {});
      }
    });
  }

  // ---------------------------------------------------------- tindakan

  void _showControls() {
    _hideTimer?.cancel();
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SettingsScreen(app: app)),
    );
    _loadImages();
    _focus.requestFocus();
  }

  Future<void> _toggleFullscreen() async {
    if (!Platform.isWindows) return;
    final fs = await windowManager.isFullScreen();
    await windowManager.setFullScreen(!fs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
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
              child: ListenableBuilder(
                listenable: app,
                builder: (ctx, _) => Stack(
                  fit: StackFit.expand,
                  children: [
                    if (app.settings.mode == 'masjid')
                      MasjidView(app: app)
                    else
                      LayoutBuilder(builder: (ctx, c) => _homeBody(c)),
                    _controls(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _controls() {
    return Positioned(
      top: 16,
      right: 16,
      child: AnimatedOpacity(
        opacity: _controlsVisible ? 1 : 0,
        duration: const Duration(milliseconds: 250),
        child: IgnorePointer(
          ignoring: !_controlsVisible,
          child: Row(children: [
            if (Platform.isWindows) ...[
              _roundButton(Icons.fullscreen, 'Skrin penuh (F11)', _toggleFullscreen),
              const SizedBox(width: 8),
            ],
            _roundButton(Icons.settings_outlined, 'Tetapan', _openSettings),
          ]),
        ),
      ),
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

  // ======================================================== Mod Rumah

  Widget _homeBody(BoxConstraints c) {
    final w = c.maxWidth;
    final compact = w < 900;
    final double sc = compact
        ? (w / 420).clamp(0.75, 1.2).toDouble()
        : (w / 1600).clamp(0.6, 1.6).toDouble();
    final pad = (compact ? 20.0 : 64.0) * (compact ? 1 : sc);

    return Stack(
      fit: StackFit.expand,
      children: [
        _background(sc),
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
          child: _topBar(compact, sc),
        ),
        Positioned(
          left: pad,
          right: pad,
          bottom: pad * 0.75,
          child: _bottomPanel(compact, sc),
        ),
      ],
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
              style: ft(18, c: Colors.white.withValues(alpha: 0.6))),
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
    return AnimatedSwitcher(duration: const Duration(milliseconds: 1200), child: child);
  }

  Widget _topBar(bool compact, double sc) {
    final now = app.now;
    final use12 = app.settings.use12h;
    final clockSize = (compact ? 72.0 : 112.0) * sc;
    final suffix = use12 ? (now.hour < 12 ? 'PG' : 'PTG') : '';
    final hijri = hijriText(app.today?.hijri);

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(fmtTime(now, use12), style: sg(clockSize, h: 1, ls: -2)),
            SizedBox(width: 8 * sc),
            Text(two(now.second),
                style: sg(clockSize * 0.36, w: FontWeight.w500, c: muted())),
            if (suffix.isNotEmpty) ...[
              SizedBox(width: 8 * sc),
              Text(suffix, style: ft(clockSize * 0.22, c: muted())),
            ],
          ],
        ),
        SizedBox(height: 6 * sc),
        Text(dateText(now), style: ft(24 * sc, c: muted(0.85))),
        if (hijri.isNotEmpty) Text(hijri, style: ft(20 * sc, c: kAccent)),
      ],
    );

    final z = app.zone;
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
            z == null ? 'Mengesan lokasi…' : '${z.label} · ${z.code}',
            overflow: TextOverflow.ellipsis,
            style: ft(18 * sc),
          ),
        ),
      ]),
    );

    final netLine = Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(app.online ? Icons.wifi : Icons.wifi_off, size: 18 * sc, color: muted(0.75)),
      SizedBox(width: 8 * sc),
      Flexible(
        child: Text(
          !app.settings.autoLocation
              ? 'Zon dipilih secara manual'
              : app.online
                  ? 'Internet disambung${app.locatedAt == null ? '' : ' · lokasi dikemas kini ${fmtTime(app.locatedAt!, use12)}'}'
                  : 'Luar talian · guna data tersimpan',
          style: ft(15 * sc, c: muted(0.75)),
        ),
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

  Widget _bottomPanel(bool compact, double sc) {
    final next = app.next();
    final today = app.today;
    final now = app.now;

    final header = next == null
        ? Text(app.status ?? 'Memuatkan waktu solat…', style: ft(20 * sc))
        : Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 14 * sc,
            children: [
              Text('Waktu seterusnya', style: ft(22 * sc, c: muted(0.8))),
              Text(prayerFields[next.$1].$1, style: sg(34 * sc, c: kAccent)),
              Text('dalam', style: ft(22 * sc, c: muted(0.8))),
              Text(_countdown(next.$2), style: sg(34 * sc)),
            ],
          );

    final cols = compact ? 4 : 7;
    final gap = 12.0 * (compact ? 0.7 : sc);

    Widget card(int i) {
      final on = next != null && next.$1 == i && today != null && today.times[i].isAfter(now);
      final fg = on ? kOnAccent : kInk;
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 20 * sc, vertical: (compact ? 14 : 20) * sc),
        decoration: BoxDecoration(
          color: on ? kAccent : const Color(0x80060A09),
          borderRadius: BorderRadius.circular(16 * sc),
          border: on ? null : Border.all(color: const Color(0x24FFFFFF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(prayerFields[i].$1.toUpperCase(),
                style: ft((compact ? 13 : 18) * sc,
                    w: FontWeight.w600, ls: 0.8, c: on ? fg : muted(0.75))),
            SizedBox(height: 8 * sc),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                today == null ? '--:--' : fmtTime(today.times[i], app.settings.use12h),
                style: sg((compact ? 26 : 40) * sc, h: 1, c: fg),
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
          for (var i = 0; i < prayerFields.length; i++) SizedBox(width: itemW, child: card(i)),
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
            child: Text('Sumber: JAKIM e-Solat melalui waktusolat.app',
                style: ft(13 * sc.clamp(1.0, 1.6).toDouble(), c: muted(0.6))),
          ),
          if (n <= 12) dots,
        ]),
      ],
    );
  }

  String _countdown(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    return '${h > 0 ? '$h jam ' : ''}$m min ${two(s)} s';
  }
}
