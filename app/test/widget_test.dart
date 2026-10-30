import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tinerfuel/main.dart';
import 'package:tinerfuel/providers.dart';

void main() {
  testWidgets('sin servidor: el mapa arranca, avisa y cambia de capa', (tester) async {
    SharedPreferences.setMockInitialValues({'locale': 'es'});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(overrides: [prefsProvider.overrideWithValue(prefs)], child: const App()),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('env.json'), findsOneWidget);
    expect(find.text('Gasolina 95'), findsWidgets);

    await tester.tap(find.byIcon(Icons.ev_station));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Potencia mínima'), findsOneWidget);
    expect(prefs.getString('layer'), 'charger');
  });
}
