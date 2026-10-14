import 'dart:async';

import 'package:flutter/material.dart';

import 'app_state.dart';
import 'masjid_config.dart';
import 'services.dart';
import 'ui_common.dart';

const _innaLillah = 'إِنَّا لِلَّٰهِ وَإِنَّا إِلَيْهِ رَاجِعُونَ';

String? _iqamahKeyFor(int i) {
  for (final e in iqamahIndex.entries) {
    if (e.value == i) return e.key;
  }
  return null;
}

/// Paparan Mod Masjid: skrin utama, iqamah, solat, Jumaat dan rehat.
class MasjidView extends StatefulWidget {
  final AppState app;
  const MasjidView({super.key, required this.app});

  @override
  State<MasjidView> createState() => _MasjidViewState();
}

class _MasjidViewState extends State<MasjidView> {
  AppState get app => widget.app;
  MasjidConfig get m => app.masjid;

  int _slide = 0;
  int _ticker = 0;
  int _slideSecs = -1;
  Timer? _slideTimer, _tickerTimer;

  @override
  void initState() {
    super.initState();
    _tickerTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (mounted) setState(() => _ticker++);
    });
  }

  @override
  void dispose() {
    _slideTimer?.cancel();
    _tickerTimer?.cancel();
    super.dispose();
  }

  void _ensureSlideTimer() {
    final secs = m.slideSeconds;
    if (secs == _slideSecs) return;
    _slideSecs = secs;
    _slideTimer?.cancel();
    _slideTimer = Timer.periodic(Duration(seconds: secs), (_) {
      if (mounted) setState(() => _slide++);
    });
  }

  String _prayerName(int i) =>
      (app.now.weekday == DateTime.friday && i == 3) ? 'Jumaat' : prayerFields[i].$1;

  @override
  Widget build(BuildContext context) {
    _ensureSlideTimer();
    final phase = computePhase(m, app.today, app.now);
    return LayoutBuilder(builder: (ctx, c) {
      final w = c.maxWidth;
      final double sc = (w / 1600).clamp(0.45, 1.6).toDouble();
      final Widget child;
      switch (phase.kind) {
        case PhaseKind.rest:
          child = _rest(sc);
        case PhaseKind.solat:
          child = _solat(phase, sc);
        case PhaseKind.iqamah:
          child = _iqamah(phase, sc);
        case PhaseKind.jumaat:
          child = _jumaat(sc);
        case PhaseKind.normal:
          child = _main(w, sc);
      }
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        child: KeyedSubtree(key: ValueKey(phase.kind), child: child),
      );
    });
  }

  // ================================================================ utama

  Widget _main(double w, double sc) {
    final acc = Color(m.accentValue);
    final compact = w < 900;
    final side = _sideCard(sc, acc);
    final verse = _verseCard(sc, acc);
    final pad = (compact ? 16.0 : 48.0 * sc);

    if (compact) {
      return Container(
        color: kBg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(sc, acc, true),
            Padding(padding: EdgeInsets.all(pad), child: _prayerTable(sc, acc, true)),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, 0, pad, pad),
                child: _slideCard(sc, acc),
              ),
            ),
            _tickerBar(sc, acc),
          ],
        ),
      );
    }

    return Container(
      color: kBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(sc, acc, false),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: pad, vertical: 28 * sc),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _slideCard(sc, acc)),
                        if (verse != null) ...[SizedBox(height: 16 * sc), verse],
                      ],
                    ),
                  ),
                  SizedBox(width: 28 * sc),
                  SizedBox(
                    width: 480 * sc,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _prayerTable(sc, acc, false),
                        if (side != null) ...[SizedBox(height: 16 * sc), Expanded(child: side)],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _tickerBar(sc, acc),
        ],
      ),
    );
  }

  Widget _logo(double size, Color acc) {
    final f = app.media(m.logo);
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF1F2E29),
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: f != null
          ? Image.file(f, fit: BoxFit.cover)
          : Icon(Icons.mosque, color: acc, size: size * 0.55),
    );
  }

  Widget _header(double sc, Color acc, bool compact) {
    final s = compact ? 0.75 : sc;
    final loc = m.locationText.isNotEmpty
        ? m.locationText
        : [if (app.zone != null) app.zone!.label, if (app.zone != null) 'Zon ${app.zone!.code}']
            .join(' · ');
    final use12 = app.settings.use12h;
    final clock = fmtTime(app.now, use12);
    final suffix = use12 ? (app.now.hour < 12 ? 'PG' : 'PTG') : '';

    final left = Row(children: [
      _logo(64 * s, acc),
      SizedBox(width: 16 * s),
      Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(m.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: sg(30 * s, w: FontWeight.w700)),
            if (loc.isNotEmpty)
              Text(loc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ft(17 * s, c: muted())),
          ],
        ),
      ),
    ]);

    final clockW = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(clock, style: sg(72 * s, h: 1)),
        if (suffix.isNotEmpty) ...[
          SizedBox(width: 8 * s),
          Text(suffix, style: ft(22 * s, c: muted())),
        ],
      ],
    );

    final dates = Column(
      crossAxisAlignment: compact ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(dateText(app.now), style: ft(20 * s)),
        if (hijriText(app.today?.hijri).isNotEmpty)
          Text(hijriText(app.today?.hijri), style: ft(18 * s, c: acc)),
      ],
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: (compact ? 16 : 48) * s, vertical: 24 * s),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kLine))),
      child: compact
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              left,
              SizedBox(height: 12 * s),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [clockW, const Spacer(), dates],
              ),
            ])
          : Row(children: [
              Expanded(child: left),
              clockW,
              Expanded(child: Align(alignment: Alignment.centerRight, child: dates)),
            ]),
    );
  }

  Widget _prayerTable(double sc, Color acc, bool compact) {
    final s = compact ? 0.8 : sc;
    final t = app.today;
    final nx = app.next();
    final use12 = app.settings.use12h;
    final friday = app.now.weekday == DateTime.friday;
    final label = ft(14 * s, w: FontWeight.w700, c: muted(0.6), ls: 1.1);

    Widget row(int i) {
      final name = _prayerName(i);
      final key = _iqamahKeyFor(i);
      final azan = t?.times[i];
      final iq = (key != null && azan != null && !(friday && i == 3))
          ? azan.add(Duration(minutes: m.iqamah(key)))
          : null;
      final on = nx != null && t != null && nx.$1 == i && t.times[i].isAfter(app.now);
      final fg = on ? kOnAccent : kInk;
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 9 * s),
        decoration: BoxDecoration(
          color: on ? acc : Colors.transparent,
          borderRadius: BorderRadius.circular(12 * s),
        ),
        child: Row(children: [
          Text(name, style: ft(22 * s, w: on ? FontWeight.w700 : FontWeight.w600, c: fg)),
          if (m.jawi && jawiNames[name] != null) ...[
            SizedBox(width: 12 * s),
            Text(jawiNames[name]!,
                textDirection: TextDirection.rtl,
                style: arab(19 * s, c: on ? fg : muted(0.6))),
          ],
          const Spacer(),
          SizedBox(
            width: 84 * s,
            child: Text(azan == null ? '--:--' : fmtTime(azan, use12),
                textAlign: TextAlign.right,
                style: sg(26 * s, w: on ? FontWeight.w700 : FontWeight.w600, c: fg)),
          ),
          SizedBox(
            width: 84 * s,
            child: Text(iq == null ? '—' : fmtTime(iq, use12),
                textAlign: TextAlign.right,
                style: sg(26 * s, w: on ? FontWeight.w700 : FontWeight.w600, c: on ? fg : muted(0.6))),
          ),
        ]),
      );
    }

    final footer = nx == null
        ? Text(app.status ?? 'Memuatkan waktu solat…', style: ft(16 * s, c: muted()))
        : Text.rich(TextSpan(children: [
            TextSpan(text: 'Azan ${nx.$1 == 0 ? 'Imsak' : _prayerName(nx.$1)} dalam ', style: ft(18 * s, c: acc)),
            TextSpan(text: shortCountdown(nx.$2), style: sg(18 * s, w: FontWeight.w700, c: acc)),
          ]));

    return Container(
      padding: EdgeInsets.fromLTRB(8 * s, 16 * s, 8 * s, 16 * s),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(20 * s),
        border: Border.all(color: kLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16 * s, 0, 16 * s, 8 * s),
            child: Row(children: [
              Text('WAKTU', style: label),
              const Spacer(),
              SizedBox(width: 84 * s, child: Text('AZAN', textAlign: TextAlign.right, style: label)),
              SizedBox(width: 84 * s, child: Text('IQAMAH', textAlign: TextAlign.right, style: label)),
            ]),
          ),
          for (final i in [1, 2, 3, 4, 5, 6]) row(i),
          Padding(padding: EdgeInsets.fromLTRB(16 * s, 10 * s, 16 * s, 0), child: footer),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- slaid

  Widget _slideCard(double sc, Color acc) {
    var slides = m.activeSlides;
    if (slides.isEmpty) {
      slides = [
        {
          'type': 'text',
          'label': 'SELAMAT DATANG',
          'title': m.name,
          'subtitle': 'Semoga dipermudahkan urusan ibadah anda.',
          'detail': '',
        }
      ];
    }
    final i = _slide % slides.length;
    final s = slides[i];
    final dots = slides.length < 2
        ? const SizedBox.shrink()
        : Row(mainAxisSize: MainAxisSize.min, children: [
            for (var k = 0; k < slides.length.clamp(0, 12); k++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                margin: EdgeInsets.only(right: 8 * sc),
                width: k == i ? 26 * sc : 8 * sc,
                height: 8 * sc,
                decoration: BoxDecoration(
                  color: k == i ? acc : Colors.white.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(4 * sc),
                ),
              ),
          ]);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20 * sc),
      child: Stack(fit: StackFit.expand, children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 900),
          child: KeyedSubtree(key: ValueKey('slide$i-${s['title']}-${s['image']}'), child: _slideBody(s, sc, acc)),
        ),
        Positioned(left: 44 * sc, bottom: 28 * sc, child: dots),
      ]),
    );
  }

  String _str(Map s, String k) => ((s[k] as String?) ?? '').trim();

  Widget _slideBody(Map<String, dynamic> s, double sc, Color acc) {
    final type = _str(s, 'type');
    final label = _str(s, 'label');
    final title = _str(s, 'title');
    final sub = _str(s, 'subtitle');
    final detail = _str(s, 'detail');

    if (type == 'image') {
      final f = app.media(s['image'] as String?);
      return Stack(fit: StackFit.expand, children: [
        if (f != null)
          Image.file(f, fit: BoxFit.cover)
        else
          Container(
            color: const Color(0xFF24394F),
            alignment: Alignment.center,
            child: Icon(Icons.image_outlined, size: 64 * sc, color: muted(0.5)),
          ),
        if (title.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(44 * sc, 60 * sc, 44 * sc, 56 * sc),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xDD060A09), Color(0x00060A09)],
                ),
              ),
              child: Text(title, style: sg(40 * sc, w: FontWeight.w700)),
            ),
          ),
      ]);
    }

    if (type == 'kematian') {
      return Container(
        color: const Color(0xFF181B1A),
        padding: EdgeInsets.all(44 * sc),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_innaLillah, textDirection: TextDirection.rtl, textAlign: TextAlign.center, style: arab(34 * sc, c: acc)),
            SizedBox(height: 18 * sc),
            Text(label.isEmpty ? 'BERITA KEMATIAN' : label.toUpperCase(),
                style: ft(16 * sc, w: FontWeight.w700, c: muted(0.7), ls: 1.4)),
            SizedBox(height: 12 * sc),
            if (title.isNotEmpty)
              Text(title, textAlign: TextAlign.center, style: sg(46 * sc, w: FontWeight.w700)),
            if (sub.isNotEmpty) ...[
              SizedBox(height: 10 * sc),
              Text(sub, textAlign: TextAlign.center, style: ft(22 * sc, c: muted(0.85))),
            ],
            if (detail.isNotEmpty) ...[
              SizedBox(height: 6 * sc),
              Text(detail, textAlign: TextAlign.center, style: ft(20 * sc, c: muted(0.7))),
            ],
            SizedBox(height: 18 * sc),
            Text('Al-Fatihah', style: ft(18 * sc, c: acc)),
          ],
        ),
      );
    }

    // teks
    return Container(
      color: Color.alphaBlend(acc.withValues(alpha: 0.10), const Color(0xFF1B2A35)),
      padding: EdgeInsets.fromLTRB(44 * sc, 44 * sc, 44 * sc, 64 * sc),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14 * sc, vertical: 6 * sc),
              decoration: BoxDecoration(color: acc, borderRadius: BorderRadius.circular(999)),
              child: Text(label.toUpperCase(),
                  style: ft(15 * sc, w: FontWeight.w700, c: kOnAccent, ls: 1)),
            ),
          SizedBox(height: 16 * sc),
          if (title.isNotEmpty)
            Text(title, maxLines: 3, overflow: TextOverflow.ellipsis, style: sg(52 * sc, w: FontWeight.w700, h: 1.1)),
          if (sub.isNotEmpty) ...[
            SizedBox(height: 14 * sc),
            Text(sub, style: ft(22 * sc, c: muted(0.85))),
          ],
          if (detail.isNotEmpty) ...[
            SizedBox(height: 8 * sc),
            Text(detail, style: ft(20 * sc, c: muted(0.7))),
          ],
        ],
      ),
    );
  }

  Widget? _verseCard(double sc, Color acc) {
    final vs = m.activeVerses;
    if (vs.isEmpty) return null;
    final day = app.now.difference(DateTime(app.now.year)).inDays;
    final v = vs[day % vs.length];
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24 * sc, vertical: 18 * sc),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16 * sc),
        border: Border.all(color: kLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_str(v, 'ar'),
              textDirection: TextDirection.rtl,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: arab(28 * sc, c: acc)),
          SizedBox(height: 6 * sc),
          Text(
            '"${_str(v, 'ms')}"${_str(v, 'ref').isEmpty ? '' : ' — ${_str(v, 'ref')}'}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: ft(17 * sc, c: muted(0.8)),
          ),
        ],
      ),
    );
  }

  Widget? _sideCard(double sc, Color acc) {
    final qr = app.media(m.qr);
    final imam = m.petugas('imamBertugas');
    if (qr == null && m.tabung.isEmpty && imam.isEmpty) return null;
    return Container(
      padding: EdgeInsets.all(20 * sc),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(20 * sc),
        border: Border.all(color: kLine),
      ),
      child: Row(children: [
        if (qr != null) ...[
          Container(
            width: 130 * sc,
            height: 130 * sc,
            padding: EdgeInsets.all(6 * sc),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12 * sc)),
            child: Image.file(qr, fit: BoxFit.contain),
          ),
          SizedBox(width: 20 * sc),
        ],
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (qr != null || m.tabung.isNotEmpty) ...[
                Text('Infaq & derma', style: ft(20 * sc, w: FontWeight.w700)),
                if (qr != null)
                  Text('Imbas dengan mana-mana aplikasi bank', style: ft(16 * sc, c: muted(0.75))),
                if (m.tabung.isNotEmpty)
                  Text.rich(TextSpan(children: [
                    TextSpan(text: 'Tabung Jumaat lalu: ', style: ft(16 * sc, c: muted(0.75))),
                    TextSpan(text: m.tabung, style: ft(16 * sc, w: FontWeight.w700, c: acc)),
                  ])),
              ],
              if (imam.isNotEmpty) ...[
                if (qr != null || m.tabung.isNotEmpty) SizedBox(height: 10 * sc),
                Text('Imam bertugas', style: ft(14 * sc, w: FontWeight.w700, c: muted(0.6), ls: 1)),
                Text(imam, style: ft(19 * sc, w: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ]),
    );
  }

  Widget _tickerBar(double sc, Color acc) {
    final items = [
      ...m.activeAnnouncements,
      if (m.puasaReminder) ...puasaReminders(app.now, app.today?.hijri ?? ''),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    final text = items[_ticker % items.length];
    final h = (60 * sc).clamp(40.0, 90.0).toDouble();
    return Container(
      height: h,
      decoration: const BoxDecoration(
        color: kCard,
        border: Border(top: BorderSide(color: kLine)),
      ),
      child: Row(children: [
        Container(
          height: double.infinity,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: 24 * sc),
          color: acc,
          child: Text('PENGUMUMAN', style: ft(16 * sc, w: FontWeight.w700, c: kOnAccent, ls: 1.2)),
        ),
        SizedBox(width: 20 * sc),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: Align(
              key: ValueKey(text),
              alignment: Alignment.centerLeft,
              child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: ft(19 * sc)),
            ),
          ),
        ),
        SizedBox(width: 24 * sc),
      ]),
    );
  }

  // ============================================================== iqamah

  Widget _iqamah(Phase p, double sc) {
    final acc = Color(m.accentValue);
    final until = p.until ?? app.now;
    final start = p.start ?? app.now;
    final left = until.difference(app.now);
    final total = until.difference(start).inSeconds;
    final progress = total <= 0 ? 1.0 : (1 - left.inSeconds / total).clamp(0.0, 1.0).toDouble();
    final name = _prayerName(p.prayer);

    Widget chip(IconData icon, String text) => Container(
          padding: EdgeInsets.symmetric(horizontal: 28 * sc, vertical: 18 * sc),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16 * sc),
            border: Border.all(color: kLine),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: kInk, size: 30 * sc),
            SizedBox(width: 14 * sc),
            Text(text, style: ft(24 * sc)),
          ]),
        );

    return Container(
      color: const Color(0xFF0F241D),
      padding: EdgeInsets.symmetric(horizontal: 56 * sc, vertical: 40 * sc),
      child: Column(children: [
        Row(children: [
          Expanded(child: Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ft(20 * sc, c: muted()))),
          Text(fmtTime(app.now, app.settings.use12h, suffix: true), style: sg(20 * sc, c: muted())),
        ]),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(name.toUpperCase(), style: sg(48 * sc, w: FontWeight.w700, c: acc, ls: 4)),
                  if (m.jawi && jawiNames[name] != null) ...[
                    SizedBox(width: 20 * sc),
                    Text(jawiNames[name]!, textDirection: TextDirection.rtl, style: arab(44 * sc, c: acc)),
                  ],
                ],
              ),
              SizedBox(height: 14 * sc),
              Text('Iqamah dalam', style: ft(30 * sc, c: muted(0.85))),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('${two(left.inMinutes.clamp(0, 99))}:${two(left.inSeconds.clamp(0, 5999) % 60)}',
                    style: sg(240 * sc, w: FontWeight.w700, h: 1.05, ls: -4)),
              ),
              SizedBox(height: 10 * sc),
              SizedBox(
                width: 720 * sc,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6 * sc),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10 * sc,
                    color: acc,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
              ),
            ],
          ),
        ),
        Wrap(spacing: 24 * sc, runSpacing: 12 * sc, alignment: WrapAlignment.center, children: [
          chip(Icons.phone_disabled, 'Senyapkan telefon bimbit'),
          chip(Icons.view_headline, 'Luruskan dan rapatkan saf'),
        ]),
      ]),
    );
  }

  // =============================================================== solat

  Widget _solat(Phase p, double sc) {
    return Container(
      color: const Color(0xFF040605),
      child: Stack(children: [
        Positioned(
          top: 36 * sc,
          right: 48 * sc,
          child: Text(fmtTime(app.now, app.settings.use12h), style: sg(22 * sc, c: const Color(0xFF5E5A54))),
        ),
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.mosque, size: 44 * sc, color: const Color(0xFF9A958C)),
            SizedBox(height: 16 * sc),
            Text('Solat ${_prayerName(p.prayer)} sedang didirikan',
                textAlign: TextAlign.center,
                style: ft(30 * sc, w: FontWeight.w500, c: const Color(0xFF9A958C))),
            SizedBox(height: 10 * sc),
            Text('Sila senyapkan telefon bimbit', style: ft(20 * sc, c: const Color(0xFF6F6A62))),
          ]),
        ),
      ]),
    );
  }

  // ============================================================== Jumaat

  Widget _jumaat(double sc) {
    final acc = Color(m.accentValue);
    Widget card(String label, String value, {bool highlight = false}) => Expanded(
          child: Container(
            padding: EdgeInsets.all(22 * sc),
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(16 * sc),
              border: Border.all(color: highlight ? acc : kLine),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: ft(14 * sc, w: FontWeight.w700, c: highlight ? acc : muted(0.6), ls: 1.1)),
              SizedBox(height: 8 * sc),
              Text(value, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: highlight ? sg(28 * sc, w: FontWeight.w700) : ft(24 * sc, w: FontWeight.w600)),
            ]),
          ),
        );
    final cards = <Widget>[
      if (m.petugas('khatib').isNotEmpty) card('KHATIB', m.petugas('khatib')),
      if (m.petugas('imam').isNotEmpty) card('IMAM', m.petugas('imam')),
      if (m.petugas('bilal').isNotEmpty) card('BILAL', m.petugas('bilal')),
      if (m.tabung.isNotEmpty) card('TABUNG JUMAAT LALU', m.tabung, highlight: true),
    ];

    return Container(
      color: kBg,
      padding: EdgeInsets.symmetric(horizontal: 64 * sc, vertical: 48 * sc),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16 * sc, vertical: 8 * sc),
            decoration: BoxDecoration(color: acc, borderRadius: BorderRadius.circular(999)),
            child: Text('SOLAT JUMAAT', style: ft(16 * sc, w: FontWeight.w700, c: kOnAccent, ls: 1.2)),
          ),
          SizedBox(width: 14 * sc),
          Expanded(child: Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ft(20 * sc, c: muted()))),
          Text(fmtTime(app.now, app.settings.use12h, suffix: true), style: sg(40 * sc)),
        ]),
        SizedBox(height: 36 * sc),
        Text('Khutbah sedang\ndisampaikan', style: sg(84 * sc, w: FontWeight.w700, h: 1.05)),
        SizedBox(height: 12 * sc),
        Text('Sila diam dan dengar khutbah dengan tertib', style: ft(28 * sc, c: muted(0.8))),
        SizedBox(height: 32 * sc),
        if (cards.isNotEmpty)
          Row(children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) SizedBox(width: 16 * sc),
              cards[i],
            ],
          ]),
        const Spacer(),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 28 * sc, vertical: 24 * sc),
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(16 * sc),
            border: Border.all(color: kLine),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(verseJumaat['ar']!, textDirection: TextDirection.rtl, style: arab(30 * sc, c: acc)),
            SizedBox(height: 8 * sc),
            Text('"${verseJumaat['ms']}" — ${verseJumaat['ref']}', style: ft(18 * sc, c: muted(0.8))),
          ]),
        ),
      ]),
    );
  }

  // =============================================================== rehat

  Widget _rest(double sc) => Container(
        color: Colors.black,
        alignment: Alignment.bottomRight,
        padding: EdgeInsets.all(32 * sc),
        child: Text(fmtTime(app.now, app.settings.use12h),
            style: sg(18 * sc, c: const Color(0xFF333333))),
      );
}
