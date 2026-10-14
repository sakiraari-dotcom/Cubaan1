import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_state.dart';
import 'main.dart' show applyAutostart;
import 'server.dart';
import 'services.dart';
import 'settings.dart';
import 'ui_common.dart';

class SettingsScreen extends StatefulWidget {
  final AppState app;
  const SettingsScreen({super.key, required this.app});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final AppSettings _s = widget.app.settings.copy();
  late final _hostCtl = TextEditingController(text: _s.masterHost);
  late final _mPinCtl = TextEditingController(text: _s.masterPin);
  List<JakimZone> _zones = [];
  bool _busy = false;

  AppState get app => widget.app;

  @override
  void initState() {
    super.initState();
    LocationService.allZones().then((z) {
      if (mounted) setState(() => _zones = z);
    });
  }

  @override
  void dispose() {
    _hostCtl.dispose();
    _mPinCtl.dispose();
    super.dispose();
  }

  Future<void> _addImages() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
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
    _s.masterHost = _hostCtl.text.trim();
    _s.masterPin = _mPinCtl.text.trim();
    await app.updateSettings(_s);
    await applyAutostart(_s.autostart);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _openPanel() async {
    final ok = await launchUrl(Uri.parse('http://localhost:${AdminServer.port}'),
        mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka pelayar.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = sg(30, w: FontWeight.w600);
    final section = ft(13, w: FontWeight.w600, ls: 1.2, c: kAccent);
    final text = ft(16);
    final mutedS = ft(14, c: muted());

    final folderCount = () {
      final f = _s.folder;
      if (f == null || !Directory(f).existsSync()) return 0;
      try {
        return Directory(f).listSync().whereType<File>().where((x) {
          final p = x.path.toLowerCase();
          return ['.jpg', '.jpeg', '.png', '.webp', '.bmp', '.gif'].any(p.endsWith);
        }).length;
      } catch (_) {
        return 0;
      }
    }();

    final url = app.adminUrl;

    return Scaffold(
      backgroundColor: kBg,
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
                const SizedBox(height: 20),

                // ------------------------------------------------ mod
                Text('MOD PAPARAN', style: section),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'rumah', label: Text('Rumah'), icon: Icon(Icons.home_outlined)),
                    ButtonSegment(value: 'masjid', label: Text('Masjid / Surau'), icon: Icon(Icons.mosque)),
                  ],
                  selected: {_s.mode},
                  onSelectionChanged: (v) => setState(() => _s.mode = v.first),
                ),
                const SizedBox(height: 28),

                // ------------------------------------------ kawalan jauh
                if (_s.mode == 'masjid') ...[
                  Text('KAWALAN DARI TELEFON', style: section),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kLine),
                    ),
                    child: Wrap(
                      spacing: 20,
                      runSpacing: 16,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          color: Colors.white,
                          child: QrImageView(data: url, size: 150, backgroundColor: Colors.white),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Imbas kod QR dengan telefon yang disambung ke Wi-Fi yang sama, '
                                  'atau buka alamat ini dalam pelayar:', style: mutedS),
                              const SizedBox(height: 6),
                              SelectableText(url, style: sg(20, c: kAccent)),
                              const SizedBox(height: 6),
                              Row(children: [
                                Text('PIN: ', style: text),
                                SelectableText(_s.pin, style: sg(20)),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () => setState(() => _s.pin = AppSettings.newPin()),
                                  child: const Text('Tukar PIN'),
                                ),
                              ]),
                              if (app.server.error != null)
                                Text('Pelayan panel tidak dapat dimulakan: ${app.server.error}',
                                    style: ft(13, c: const Color(0xFFF2A07B))),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: _openPanel,
                                icon: const Icon(Icons.open_in_browser),
                                label: const Text('Buka panel di peranti ini'),
                                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Peranan TV ini', style: text),
                  RadioListTile<String>(
                    value: 'utama',
                    groupValue: _s.role,
                    onChanged: (v) => setState(() => _s.role = 'utama'),
                    title: Text('TV utama', style: text),
                    subtitle: Text('Kandungan diurus melalui panel TV ini.', style: mutedS),
                    activeColor: kAccent,
                  ),
                  RadioListTile<String>(
                    value: 'pendua',
                    groupValue: _s.role,
                    onChanged: (v) => setState(() => _s.role = 'pendua'),
                    title: Text('TV pendua', style: text),
                    subtitle: Text('Salin kandungan daripada TV utama setiap minit.', style: mutedS),
                    activeColor: kAccent,
                  ),
                  if (_s.role == 'pendua')
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        TextField(
                          controller: _hostCtl,
                          decoration: const InputDecoration(
                            labelText: 'Alamat IP TV utama',
                            hintText: 'cth. 192.168.1.20',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _mPinCtl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'PIN TV utama'),
                        ),
                        if (app.syncStatus != null) ...[
                          const SizedBox(height: 8),
                          Text(app.syncStatus!, style: mutedS),
                        ],
                      ]),
                    ),
                  const SizedBox(height: 28),
                ],

                // ------------------------------------------------ lokasi
                Text('LOKASI', style: section),
                const SizedBox(height: 8),
                RadioListTile<bool>(
                  value: true,
                  groupValue: _s.autoLocation,
                  onChanged: (v) => setState(() => _s.autoLocation = true),
                  title: Text('Auto melalui Wi-Fi / internet', style: text),
                  subtitle: Text('Zon JAKIM dikesan semula setiap 6 jam dan setiap kali aplikasi dibuka.',
                      style: mutedS),
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
                        ? Text('Senarai zon memerlukan internet kali pertama.', style: mutedS)
                        : DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _zones.any((z) => z.code == _s.manualZone) ? _s.manualZone : null,
                            hint: const Text('Pilih zon'),
                            items: [
                              for (final z in _zones)
                                DropdownMenuItem(
                                  value: z.code,
                                  child: Text('${z.code} · ${z.state}: ${z.district}',
                                      overflow: TextOverflow.ellipsis),
                                ),
                            ],
                            onChanged: (v) => setState(() => _s.manualZone = v),
                          ),
                  ),
                const SizedBox(height: 28),

                // ------------------------------------ gambar (mod rumah)
                if (_s.mode == 'rumah') ...[
                  Text('GAMBAR LATAR', style: section),
                  const SizedBox(height: 8),
                  Text(
                    '${_s.images.length} gambar dipilih'
                    '${_s.folder != null ? ' · folder: ${_s.folder} ($folderCount gambar)' : ''}',
                    style: mutedS,
                  ),
                  const SizedBox(height: 12),
                  Wrap(spacing: 12, runSpacing: 12, children: [
                    FilledButton.icon(
                      onPressed: _busy ? null : _addImages,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Tambah gambar'),
                      style: FilledButton.styleFrom(
                          backgroundColor: kAccent,
                          foregroundColor: kOnAccent,
                          minimumSize: const Size(0, 48)),
                    ),
                    if (!Platform.isAndroid)
                      OutlinedButton.icon(
                        onPressed: _pickFolder,
                        icon: const Icon(Icons.folder_open_outlined),
                        label: const Text('Pilih folder'),
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                      ),
                    OutlinedButton(
                      onPressed: _clearImages,
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
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
                        value: _s.interval.toDouble().clamp(3.0, 60.0).toDouble(),
                        activeColor: kAccent,
                        label: '${_s.interval} s',
                        onChanged: (v) => setState(() => _s.interval = v.round()),
                      ),
                    ),
                    SizedBox(
                        width: 48,
                        child: Text('${_s.interval} s', textAlign: TextAlign.right, style: text)),
                  ]),
                  const SizedBox(height: 28),
                ],

                // ------------------------------------------------ paparan
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
                ListTile(
                  title: Text('Uji bunyi azan / beep', style: text),
                  subtitle: Text('Fail azan dan beep ditetapkan melalui panel (Mod Masjid).', style: mutedS),
                  trailing: const Icon(Icons.volume_up_outlined),
                  onTap: app.testSound,
                ),
                if (Platform.isWindows)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text('Pintasan: F11 skrin penuh · Esc keluar skrin penuh · S tetapan',
                        style: mutedS),
                  ),
                const SizedBox(height: 32),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    style: FilledButton.styleFrom(
                        backgroundColor: kAccent,
                        foregroundColor: kOnAccent,
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
