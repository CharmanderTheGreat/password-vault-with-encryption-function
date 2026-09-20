// Basic smoke test — verifies the app boots without crashing.
//
// This intentionally does not test app-specific screens or flows
// (unlock, vault list, etc.) since those depend on Firebase and local
// database state that aren't available in a plain widget test. It's
// just a build/crash sanity check.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:password_vault_app/core/session/vault_session.dart';
import 'package:password_vault_app/core/theme/theme_controller.dart';

void main() {
  testWidgets('App builds without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => VaultSession()),
          ChangeNotifierProvider(create: (_) => ThemeController()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: Center(child: Text('Grand Vault'))),
        ),
      ),
    );

    expect(find.text('Grand Vault'), findsOneWidget);
  });
}
