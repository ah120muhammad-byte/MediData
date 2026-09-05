// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. For more information, see the Flutter testing documentation.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:MediData/main.dart';
import 'package:MediData/services/remote_app_settings_service.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MyApp(settings: RemoteAppSettings.defaults),
    );

    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
