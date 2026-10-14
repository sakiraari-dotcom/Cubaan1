import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

import 'home_screen.dart';
import 'settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();

  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    launchAtStartup.setup(
      appName: 'Waktu Solat',
      appPath: Platform.resolvedExecutable,
    );
    await applyAutostart(settings.autostart);
    const opts = WindowOptions(
      title: 'Waktu Solat',
      size: Size(1280, 720),
      minimumSize: Size(640, 400),
      center: true,
      backgroundColor: Color(0xFF0D1412),
    );
    windowManager.waitUntilReadyToShow(opts, () async {
      await windowManager.show();
      await windowManager.setFullScreen(true);
      await windowManager.focus();
    });
  } else if (Platform.isAndroid) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  try {
    await WakelockPlus.enable(); // skrin tidak padam
  } catch (_) {}

  runApp(WaktuSolatApp(settings: settings));
}

Future<void> applyAutostart(bool on) async {
  if (!Platform.isWindows) return;
  try {
    if (on) {
      await launchAtStartup.enable();
    } else {
      await launchAtStartup.disable();
    }
  } catch (_) {}
}

class WaktuSolatApp extends StatelessWidget {
  final AppSettings settings;
  const WaktuSolatApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Waktu Solat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kAccent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0D1412),
      ),
      home: HomeScreen(initialSettings: settings),
    );
  }
}
