import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:attendance_admin/data/api_client.dart';
import 'package:attendance_admin/l10n/app_localizations.dart';
import 'package:attendance_admin/ui/device_page.dart';

/// Canned device responses so the page can be driven without hardware.
Map<String, dynamic> _config({
  String language = 'en',
  bool time12h = false,
  bool buzzer = true,
}) =>
    {
      'language': language,
      'time_12h': time12h,
      'show_seconds': false,
      'tz_offset_min': 180,
      'brightness': 128,
      'buzzer': buzzer,
      'dup_window_s': 60,
      'idle_dim_s': 20,
      'idle_off_s': 120,
      'use_finger_detect': true,
      'use_touch_button': true,
      'has_strings': true,
      'string_slots': 17,
    };

void main() {
  late List<Map<String, dynamic>> posted;

  ApiClient buildApi() {
    posted = [];
    final mock = MockClient((req) async {
      if (req.method == 'POST' && req.url.path.endsWith('/config')) {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        posted.add(body);
        // The device echoes back what it stored.
        return http.Response(jsonEncode(body..addAll({
              'has_strings': true,
              'string_slots': 17,
            })), 200,
            headers: {'content-type': 'application/json'});
      }
      return http.Response(jsonEncode(_config()), 200,
          headers: {'content-type': 'application/json'});
    });
    return ApiClient(host: '10.0.0.1', token: 'x', client: mock);
  }

  Future<void> pumpPage(WidgetTester tester) async {
    // The default 800x600 test surface cuts the page off partway down, so
    // controls further along end up outside the viewport and taps miss.
    // This page is a desktop admin screen; give it a desktop-sized window.
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: DevicePage(api: buildApi()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('clock format control responds to a tap', (tester) async {
    await pumpPage(tester);

    final twelve = find.text('12-hour');
    expect(twelve, findsOneWidget);

    // The regression: edits went into the draft while the UI kept rendering
    // the value fetched at load time, so nothing appeared to change.
    final before = tester.widget<SegmentedButton<bool>>(
        find.byType(SegmentedButton<bool>).first);
    expect(before.selected, {false});

    await tester.tap(twelve);
    await tester.pumpAndSettle();

    final after = tester.widget<SegmentedButton<bool>>(
        find.byType(SegmentedButton<bool>).first);
    expect(after.selected, {true}, reason: 'control did not move');
  });

  testWidgets('language control responds and carries into the save',
      (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();

    final sel = tester.widget<SegmentedButton<String>>(
        // The language control specifically -- the terminal mode control is
        // also a SegmentedButton<String> and now comes first on the page.
        find.ancestor(
            of: find.text('العربية'),
            matching: find.byType(SegmentedButton<String>)));
    expect(sel.selected, {'ar'});

    // Applying must send the edited value, not the originally loaded one.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(posted, isNotEmpty);
    expect(posted.last['language'], 'ar');
  });

  testWidgets('a switch toggles and is included in the payload',
      (tester) async {
    await pumpPage(tester);

    final buzzer = find.widgetWithText(SwitchListTile, 'Buzzer');
    expect(buzzer, findsOneWidget);
    expect(tester.widget<SwitchListTile>(buzzer).value, isTrue);

    // Tap the label, not the tile centre: the floating Apply button overlays
    // the right edge of the list, so a centre tap lands on the FAB instead.
    await tester.ensureVisible(find.text('Buzzer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buzzer'));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(buzzer).value, isFalse);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(posted.last['buzzer'], isFalse);
  });
}
