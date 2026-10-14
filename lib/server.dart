import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'app_state.dart';

const _mediaTypes = {
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.png': 'image/png',
  '.webp': 'image/webp',
  '.gif': 'image/gif',
  '.bmp': 'image/bmp',
  '.mp3': 'audio/mpeg',
  '.wav': 'audio/wav',
  '.m4a': 'audio/mp4',
  '.ogg': 'audio/ogg',
};

/// Pelayan web kecil dalam aplikasi. AJK masjid membuka panel ini dari
/// pelayar telefon (rangkaian Wi-Fi yang sama) untuk mengemas kini kandungan.
class AdminServer {
  static const port = 8765;
  final AppState app;
  HttpServer? _server;
  String? error;
  AdminServer(this.app);

  bool get running => _server != null;

  String _html = '<p>Panel tidak dapat dimuatkan.</p>';

  Future<void> start() async {
    try {
      _html = await rootBundle.loadString('assets/admin.html');
    } catch (_) {}
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: true);
      _server!.listen((req) {
        _handle(req).catchError((Object e) {
          debugPrint('Server: $e');
        });
      });
    } catch (e) {
      error = '$e';
      debugPrint('Tidak dapat buka port $port: $e');
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    res.headers.set('Access-Control-Allow-Origin', '*');
    res.headers.set('Access-Control-Allow-Headers', 'X-Pin, X-Filename, Content-Type');
    res.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    final path = req.uri.path;
    try {
      if (req.method == 'OPTIONS') {
        res.statusCode = 204;
      } else if (req.method == 'GET' && (path == '/' || path == '/index.html')) {
        res.headers.contentType = ContentType.html;
        res.write(_html);
      } else if (req.method == 'GET' && path.startsWith('/media/')) {
        await _serveMedia(res, path.substring('/media/'.length));
        return;
      } else if (path == '/api/status') {
        _json(res, {
          'name': app.masjid.name,
          'zone': app.zone?.label,
          'zoneCode': app.zone?.code,
          'role': app.settings.role,
          'version': app.masjid.version,
        });
      } else if (req.headers.value('x-pin') != app.settings.pin) {
        res.statusCode = 401;
        _json(res, {'error': 'PIN salah'});
      } else if (req.method == 'GET' && path == '/api/config') {
        _json(res, {
          'config': app.masjid.data,
          'mode': app.settings.mode,
          'zone': app.zone?.label,
          'zoneCode': app.zone?.code,
          'role': app.settings.role,
        });
      } else if (req.method == 'POST' && path == '/api/config') {
        final body = await _readBody(req, 2 << 20);
        final m = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
        await app.saveMasjid(Map<String, dynamic>.from(m['config'] as Map));
        final mode = m['mode'];
        if (mode is String) await app.setMode(mode);
        _json(res, {'ok': true, 'version': app.masjid.version});
      } else if (req.method == 'POST' && path == '/api/media') {
        final original = Uri.decodeComponent(req.headers.value('x-filename') ?? '');
        final dot = original.lastIndexOf('.');
        final ext = dot < 0 ? '' : original.substring(dot).toLowerCase();
        if (!_mediaTypes.containsKey(ext)) {
          res.statusCode = 400;
          _json(res, {'error': 'Jenis fail tidak disokong ($ext)'});
        } else {
          final bytes = await _readBody(req, 25 << 20);
          final name = '${DateTime.now().millisecondsSinceEpoch}$ext';
          await File('${app.mediaPath}${Platform.pathSeparator}$name').writeAsBytes(bytes);
          _json(res, {'name': name});
        }
      } else if (req.method == 'POST' && path == '/api/test-sound') {
        await app.testSound();
        _json(res, {'ok': true});
      } else {
        res.statusCode = 404;
        res.write('Tidak dijumpai');
      }
    } catch (e) {
      try {
        res.statusCode = 500;
        _json(res, {'error': '$e'});
      } catch (_) {}
    }
    await res.close();
  }

  void _json(HttpResponse res, Object data) {
    res.headers.contentType = ContentType.json;
    res.write(jsonEncode(data));
  }

  Future<Uint8List> _readBody(HttpRequest req, int max) async {
    final b = BytesBuilder(copy: false);
    await for (final chunk in req) {
      b.add(chunk);
      if (b.length > max) throw 'Fail terlalu besar';
    }
    return b.takeBytes();
  }

  Future<void> _serveMedia(HttpResponse res, String name) async {
    final f = app.media(name);
    if (f == null) {
      res.statusCode = 404;
      await res.close();
      return;
    }
    final dot = name.lastIndexOf('.');
    final ext = dot < 0 ? '' : name.substring(dot).toLowerCase();
    res.headers.set('Content-Type', _mediaTypes[ext] ?? 'application/octet-stream');
    res.headers.set('Cache-Control', 'max-age=86400');
    await res.addStream(f.openRead());
    await res.close();
  }
}
