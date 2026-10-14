import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

import 'home_screen.dart' show kAccent, kInk;
import 'main.dart' show applyAutostart;
import 'services.dart';
import 'settings.dart';

class SettingsScreen extends StatefulWidget {
  final AppSettings settings;
  const SettingsScreen({super.key, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final AppSettings _s = widget.settings;
  List<JakimZone> _zones = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    LocationService.allZones().then((z) {
      if (mounted) setState(() => _zones = z);
    });
  }

  Future<void> _addImages() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (res == null) return;
    setState(() => _busy = true);
    final paths = res.files.map((f) => f.path).whereType<String>().toList();
    if (Platform.isAndroid) {
      // salin ke folder aplikasi supaya gambar kekal walaupun cache dibersihkan
      final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/gambar');
      await dir.create(recursive: true);
      for (final p in paths) {
        final name = '${DateTime.now().microsecondsSinceEpoch}_${p.split('/').last}';
        final dest = await File(p).copy('${dir.path}/$name');
        _s.images.add(dest.path);
      }
    } else {
      _s.images.addAll(paths.where((p) => !_s.images.contains(p)));
    }
    setState(() => _busy = false);
  }

  Future<void> _pickFolder() async {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir != null) setState(() => _s.folder = dir);
  }

  Future<void> _clearImages() async {
    if (Platform.isAndroid) {
      for (final p in _s.images) {
        try {
          await File(p).delete();
        } catch (_) {}
      }
    }
    setState(() {
      _s.images.clear();
      _s.folder = null;
    });
  }

  Future<void> _save() async {
    if (!_s.autoLocation && _s.manualZone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sila pilih zon terlebih dahulu.')),
      );
      return;
    }
    await _s.save();
    await applyAutostart(_s.autostart);
    if (mounted) Navigator.of(context).pop(_s);
  }

  @override
  Widget build(BuildContext context) {
    final title = GoogleFonts.spaceGrotesk(
        fontSize: 30, fontWeight: FontWeight.w600, color: kInk);
    final section = GoogleFonts.figtree(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: kAccent);
    final text = GoogleFonts.figtree(fontSize: 16, color: kInk);
    final muted =
        GoogleFonts.figtree(fontSize: 14, color: kInk.withValues(alpha: 0.7));

    final folderCount = () {
      final f = _s.folder;
      if (f == null || !Directory(f).existsSync()) return 0;
      try {
        return Directory(f).listSync().whereType<File>().where((x) {
          final p = x.path.toLowerCase();
          return ['.jpg', '.jpeg', '.png', '.webp', '.bmp', '.gif']
              .any(p.endsWith);
        }).length;
      } catch (_) {
        return 0;
      }
    }();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1412),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(28),
              children: [
                Row(children: [
                  Expanded(child: Text('Tetapan', style: title)),
                  IconButton(
                    tooltip: 'Tutup tanpa simpan',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ]),
                const SizedBox(height: 24),

                Text('LOKASI', style: section),
                const SizedBox(height: 8),
                RadioListTile<bool>(
                  value: true,
                  groupValue: _s.autoLocation,
                  onChanged: (v) => setState(() => _s.autoLocation = true),
                  title: Text('Auto melalui Wi-Fi / internet', style: text),
                  subtitle: Text(
                      'Zon JAKIM dikesan semula setiap 6 jam dan setiap kali aplikasi dibuka.',
                      style: muted),
                  activeColor: kAccent,
                ),
                RadioListTile<bool>(
                  value: false,
                  groupValue: _s.autoLocation,
                  onChanged: (v) => setState(() => _s.autoLocation = false),
                  title: Text('Pilih zon sendiri', style: text),
                  activeColor: kAccent,
                ),
                if (!_s.autoLocation)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: _zones.isEmpty
                        ? Text('Senarai zon memerlukan internet kali pertama.',
                            style: muted)
                        : DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _zones.any((z) => z.code == _s.manualZone)
                                ? _s.manualZone
                                : null,
                            hint: const Text('Pilih zon'),
                            items: [
                              for (final z in _zones)
                                DropdownMenuItem(
                                  value: z.code,
                                  child: Text(
                                    '${z.code} · ${z.state}: ${z.district}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (v) => setState(() => _s.manualZone = v),
                          ),
                  ),
                const SizedBox(height: 28),

                Text('GAMBAR LATAR', style: section),
                const SizedBox(height: 8),
                Text(
                  '${_s.images.length} gambar dipilih'
                  '${_s.folder != null ? ' · folder: ${_s.folder} ($folderCount gambar)' : ''}',
                  style: muted,
                ),
                const SizedBox(height: 12),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  FilledButton.icon(
                    onPressed: _busy ? null : _addImages,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Tambah gambar'),
                    style: FilledButton.styleFrom(
                        backgroundColor: kAccent,
                        foregroundColor: const Color(0xFF14110A),
                        minimumSize: const Size(0, 48)),
                  ),
                  if (!Platform.isAndroid)
                    OutlinedButton.icon(
                      onPressed: _pickFolder,
                      icon: const Icon(Icons.folder_open_outlined),
                      label: const Text('Pilih folder'),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48)),
                    ),
                  OutlinedButton(
                    onPressed: _clearImages,
                    style:
                        OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                    child: const Text('Kosongkan'),
                  ),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Text('Tukar gambar setiap', style: text),
                  Expanded(
                    child: Slider(
                      min: 3,
                      max: 60,
                      divisions: 57,
                      value: _s.interval.toDouble(),
                      activeColor: kAccent,
                      label: '${_s.interval} s',
                      onChanged: (v) => setState(() => _s.interval = v.round()),
                    ),
                  ),
                  SizedBox(
                      width: 48,
                      child: Text('${_s.interval} s',
                          textAlign: TextAlign.right, style: text)),
                ]),
                const SizedBox(height: 28),

                Text('PAPARAN', style: section),
                SwitchListTile(
                  value: _s.use12h,
                  onChanged: (v) => setState(() => _s.use12h = v),
                  title: Text('Format 12 jam', style: text),
                  activeColor: kAccent,
                ),
                if (Platform.isWindows)
                  SwitchListTile(
                    value: _s.autostart,
                    onChanged: (v) => setState(() => _s.autostart = v),
                    title: Text('Buka automatik bila Windows bermula', style: text),
                    activeColor: kAccent,
                  ),
                if (Platform.isWindows)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                        'Pintasan: F11 skrin penuh · Esc keluar skrin penuh · S tetapan',
                        style: muted),
                  ),
                const SizedBox(height: 32),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style:
                        OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    style: FilledButton.styleFrom(
                        backgroundColor: kAccent,
                        foregroundColor: const Color(0xFF14110A),
                        minimumSize: const Size(120, 48)),
                    child: const Text('Simpan'),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
