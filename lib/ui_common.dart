import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'masjid_config.dart';

const kAccent = Color(0xFFE8C77A);
const kInk = Color(0xFFF4F1EA);
const kBg = Color(0xFF0D1412);
const kCard = Color(0xFF151C1A);
const kOnAccent = Color(0xFF14110A);
const kLine = Color(0x1FFFFFFF);

const hariMs = ['Isnin', 'Selasa', 'Rabu', 'Khamis', 'Jumaat', 'Sabtu', 'Ahad'];
const bulanMs = [
  'Januari', 'Februari', 'Mac', 'April', 'Mei', 'Jun', 'Julai', 'Ogos',
  'September', 'Oktober', 'November', 'Disember'
];

Color muted([double a = 0.7]) => kInk.withValues(alpha: a);

String two(int n) => n.toString().padLeft(2, '0');

String fmtTime(DateTime t, bool use12h, {bool suffix = false}) {
  if (!use12h) return '${two(t.hour)}:${two(t.minute)}';
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final s = suffix ? (t.hour < 12 ? ' PG' : ' PTG') : '';
  return '$h:${two(t.minute)}$s';
}

String dateText(DateTime d) =>
    '${hariMs[d.weekday - 1]}, ${d.day} ${bulanMs[d.month - 1]} ${d.year}';

String hijriText(String? h) {
  final p = (h ?? '').split('-');
  if (p.length != 3) return '';
  final m = int.tryParse(p[1]) ?? 0;
  final d = int.tryParse(p[2]);
  if (m < 1 || m > 12 || d == null) return '';
  return '$d ${bulanHijri[m - 1]} ${p[0]}H';
}

/// Baki masa: "mm:ss" jika kurang sejam, jika tidak "h jam m min".
String shortCountdown(Duration d) {
  if (d.isNegative) d = Duration.zero;
  if (d.inHours > 0) return '${d.inHours} jam ${d.inMinutes % 60} min';
  return '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
}

TextStyle sg(double size, {FontWeight w = FontWeight.w600, Color? c, double? h, double? ls}) =>
    GoogleFonts.spaceGrotesk(
        fontSize: size, fontWeight: w, color: c ?? kInk, height: h, letterSpacing: ls);

TextStyle ft(double size, {FontWeight w = FontWeight.w400, Color? c, double? h, double? ls}) =>
    GoogleFonts.figtree(
        fontSize: size, fontWeight: w, color: c ?? kInk, height: h, letterSpacing: ls);

TextStyle arab(double size, {Color? c}) =>
    GoogleFonts.notoNaskhArabic(fontSize: size, color: c ?? kInk, fontWeight: FontWeight.w500);
