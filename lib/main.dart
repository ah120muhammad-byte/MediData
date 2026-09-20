import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'services/audio_player_service.dart';
import 'services/remote_app_settings_service.dart';
import 'services/theme_mode_service.dart';
import 'screens/authentication/auth_gate_v2.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  await Supabase.initialize(
    url: 'https://eoyehpqknyoksaxlvnwl.supabase.co',
    publishableKey: 'sb_publishable_vkiv3hr00CNPiGJKlQosNw_oZEG81zZ',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  // Keep the first frame fast: local services that are required for the
  // initial theme are loaded before runApp, while audio and remote settings
  // continue after the UI is visible.
  await ThemeModeService.instance.load();

  runApp(const MyApp(settings: RemoteAppSettings.defaults));
}

class MyApp extends StatefulWidget {
  final RemoteAppSettings settings;

  const MyApp({super.key, required this.settings});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeModeService _themeService = ThemeModeService.instance;

  late RemoteAppSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
    _themeService.addListener(_onThemeChanged);

    // These services no longer block the first rendered frame.
    unawaited(AudioPlayerService.instance.initialize());
    unawaited(_loadRemoteSettings());
  }

  Future<void> _loadRemoteSettings() async {
    try {
      final settings = await RemoteAppSettingsService().getSettings();
      if (!mounted) return;

      setState(() {
        _settings = settings;
      });
    } catch (e) {
      debugPrint('Remote app settings load failed: $e');
    }
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: _settings.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeService.themeMode,
      home: AuthGateV2(settings: _settings),
    );
  }
}
