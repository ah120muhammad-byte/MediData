import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'services/audio_player_service.dart';
import 'services/remote_app_settings_service.dart';
import 'screens/authentication/auth_gate_v2.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Supabase.initialize(
    url: 'https://eoyehpqknyoksaxlvnwl.supabase.co',
    publishableKey: 'sb_publishable_vkiv3hr00CNPiGJKlQosNw_oZEG81zZ',
    authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
  );
  await AudioPlayerService.instance.initialize();
  RemoteAppSettings settings = RemoteAppSettings.defaults;
  try {
    settings = await RemoteAppSettingsService().getSettings();
  } catch (e) {
    debugPrint('Remote app settings load failed: $e');
  }
  runApp(MyApp(settings: settings));
}

class MyApp extends StatelessWidget {
  final RemoteAppSettings settings;
  const MyApp({super.key, required this.settings});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: settings.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: AuthGateV2(settings: settings),
    );
  }
}
