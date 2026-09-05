import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:MediData/main.dart';
import 'package:MediData/services/remote_app_settings_service.dart';


void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // MyApp contains AuthGateV2, which reads Supabase.instance.client.
    // Widget tests do not execute main(), so Supabase must be initialized here.
    await Supabase.initialize(
      url: 'https://eoyehpqknyoksaxlvnwl.supabase.co',
      publishableKey: 'sb_publishable_vkiv3hr00CNPiGJKlQosNw_oZEG81zZ',
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );

    await tester.pumpWidget(
      const MyApp(settings: RemoteAppSettings.defaults),
    );

    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
