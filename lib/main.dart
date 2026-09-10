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

  await AudioPlayerService.instance.initialize();
  await ThemeModeService.instance.load();

  RemoteAppSettings settings = RemoteAppSettings.defaults;
  try {
    settings = await RemoteAppSettingsService().getSettings();
  } catch (e) {
    debugPrint('Remote app settings load failed: $e');
  }

  runApp(MyApp(settings: settings));
}

class MyApp extends StatefulWidget {
  final RemoteAppSettings settings;

  const MyApp({super.key, required this.settings});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeModeService _themeService = ThemeModeService.instance;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
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
      title: widget.settings.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeService.themeMode,
      home: AuthGateV2(settings: widget.settings),
    );
  }
}
