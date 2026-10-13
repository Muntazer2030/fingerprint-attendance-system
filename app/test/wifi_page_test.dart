import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:attendance_admin/data/api_client.dart';
import 'package:attendance_admin/data/models.dart';
import 'package:attendance_admin/l10n/app_localizations.dart';
import 'package:attendance_admin/ui/wifi_page.dart';

void main() {
  late List<Map<String, dynamic>> posted;
  late Map<String, dynamic> wifi;

  ApiClient api() => ApiClient(
    host: '10.0.0.9',
    token: 't',
    client: MockClient((req) async {
      final path = req.url.path;
      if (path == '/api/v1/wifi' && req.method == 'POST') {
        final b = jsonDecode(req.body) as Map<String, dynamic>;
        posted.add(b);
        wifi = {
          ...wifi,
          'configured': (b['ssid'] as String).isNotEmpty,
          'ssid': b['ssid'],
        };
        return http.Response(jsonEncode(wifi), 200);
      }
      if (path == '/api/v1/wifi') return http.Response(jsonEncode(wifi), 200);
      if (path == '/api/v1/wifi/scan') {
        return http.Response(
          jsonEncode({
            'networks': [
              {'ssid': 'Store-WiFi', 'rssi': -48, 'secure': true},
              {'ssid': 'Guest', 'rssi': -80, 'secure': false},
            ],
          }),
          200,
        );
      }
      return http.Response('{}', 404);
    }),
  );

  setUp(() {
    posted = [];
    wifi = {
      'configured': false,
      'ssid': '',
      'state': 'off',
      'ip': '0.0.0.0',
      'rssi': 0,
      'last_error': '',
      'active': 'eth',
      'eth_link': true,
    };
  });

  Future<void> pump(WidgetTester t) async {
    t.view.physicalSize = const Size(1200, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: WifiPage(api: api()),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('scan, pick a network, save with a password', (t) async {
    await pump(t);
    expect(find.text('The terminal is on Ethernet.'), findsOneWidget);
    expect(find.textContaining('No Wi-Fi network set'), findsOneWidget);

    await t.tap(find.text('Scan'));
    await t.pumpAndSettle();
    await t.tap(find.text('Store-WiFi'));
    await t.pump();

    await t.enterText(find.widgetWithText(TextField, 'Password'), 'short');
    await t.tap(find.widgetWithText(FilledButton, 'Save'));
    await t.pumpAndSettle();
    expect(find.text('A Wi-Fi password has at least 8 characters'), findsOne);
    expect(posted, isEmpty);

    await t.enterText(
      find.widgetWithText(TextField, 'Password'),
      'longenough1',
    );
    await t.tap(find.widgetWithText(FilledButton, 'Save'));
    await t.pumpAndSettle();
    expect(posted.single, {'ssid': 'Store-WiFi', 'password': 'longenough1'});
    expect(find.textContaining('Standing by'), findsOneWidget);
  });

  testWidgets('forget clears the network on the terminal', (t) async {
    wifi = {...wifi, 'configured': true, 'ssid': 'Store-WiFi'};
    await pump(t);
    await t.tap(find.text('Forget network'));
    await t.pumpAndSettle();
    expect(posted.single, {'ssid': '', 'password': ''});
    expect(find.textContaining('No Wi-Fi network set'), findsOneWidget);
  });

  test('signal bars follow the usual thresholds', () {
    WifiNetwork n(int rssi) => WifiNetwork(ssid: 'x', rssi: rssi, secure: true);
    expect(n(-50).bars, 4);
    expect(n(-60).bars, 3);
    expect(n(-70).bars, 2);
    expect(n(-80).bars, 1);
    expect(n(-90).bars, 0);
  });
}
