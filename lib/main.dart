import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'screens/authentication/auth_gate.dart';
import 'services/audio_player_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // FIREBASE
  // ===========================================================================

  await Firebase.initializeApp();

  // ===========================================================================
  // SUPABASE
  // ===========================================================================

  await Supabase.initialize(
    url: 'https://eoyehpqknyoksaxlvnwl.supabase.co',
    publishableKey:
        'sb_publishable_vkiv3hr00CNPiGJKlQosNw_oZEG81zZ',
  );

  // ===========================================================================
  // AUDIO SERVICE
  // ===========================================================================

  await AudioPlayerService.instance.initialize();

  // ===========================================================================
  // APP
  // ===========================================================================

  runApp(
    const MyApp(),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MediData',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const AuthGate(),
    );
  }
}