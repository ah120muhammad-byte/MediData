import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'services/remote_app_settings_service.dart';
import 'services/theme_mode_service.dart';
import 'screens/authentication/auth_gate_v2.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // These startup tasks are independent, so run them in parallel instead
  // of making the first frame wait on them sequentially.
  await Future.wait<void>([
    Firebase.initializeApp(),
    Supabase.initialize(
      url: 'https://eoyehpqknyoksaxlvnwl.supabase.co',
      publishableKey: 'sb_publishable_vkiv3hr00CNPiGJKlQosNw_oZEG81zZ',
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    ),
    ThemeModeService.instance.load(),
  ]);

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

    // Audio is initialized lazily when the user opens an audio lecture.
    // Initializing AudioService at startup can cause an audible click on launch.
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
