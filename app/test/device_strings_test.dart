import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_admin/data/device_strings.dart';

void main() {
  test('slot numbers are a stable wire contract with the firmware', () {
    // These must match ui_string_t in firmware/main/cfg.h. Reordering would
    // silently put Arabic text on the wrong screen.
    expect(DeviceString.placeFinger.slot, 0);
    expect(DeviceString.inbound.slot, 2);
    expect(DeviceString.outbound.slot, 3);
    expect(DeviceString.forcedOut.slot, 16);
    expect(DeviceString.modeIn.slot, 17);
    expect(DeviceString.modeOut.slot, 18);
  });

  test('slots are unique and contiguous from zero', () {
    final slots = DeviceString.values.map((e) => e.slot).toList()..sort();
    expect(slots, List.generate(DeviceString.values.length, (i) => i));
  });

  test('every slot has text in both languages', () {
    for (final s in DeviceString.values) {
      final t = deviceStringText[s];
      expect(t, isNotNull, reason: 'missing text for $s');
      expect(t!.en.trim(), isNotEmpty, reason: 'empty English for $s');
      expect(t.ar.trim(), isNotEmpty, reason: 'empty Arabic for $s');
    }
  });

  test('Arabic strings are actually Arabic', () {
    // Guards against a copy-paste that leaves English in the Arabic column.
    final arabic = RegExp(r'[\u0600-\u06FF]');
    for (final s in DeviceString.values) {
      expect(arabic.hasMatch(deviceStringText[s]!.ar), isTrue,
          reason: '$s has no Arabic characters');
    }
  });

  test('strings stay short enough for a 128px strip', () {
    // ~13px per character at the size we render; 128px is roughly 20 chars.
    for (final s in DeviceString.values) {
      expect(deviceStringText[s]!.en.length, lessThanOrEqualTo(20),
          reason: '$s English is too long for the display');
    }
  });
}
