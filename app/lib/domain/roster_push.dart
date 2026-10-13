/// What the terminal needs to send Telegram alerts on its own: names as text,
/// and who is expected to start when over the next days.
///
/// The terminal judges lateness against this, so it must agree with the
/// timesheet: the same [ShiftResolver] decides who works which day, and the
/// grace period is the shift's own. Binary rather than JSON because the
/// terminal stores it in a few flash sectors and parses it in C; the layout is
/// documented in firmware/main/notify.h.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'attendance_rules.dart';

class RosterEmployee {
  const RosterEmployee(this.id, this.name);
  final int id;
  final String name;
}

class RosterPayload {
  const RosterPayload({
    required this.version,
    required this.names,
    required this.days,
    required this.tzOffsetMin,
  });

  /// Changes whenever anything the terminal would see changes, so the app can
  /// skip pushing an identical roster every sync.
  final int version;
  final Uint8List names;
  final Uint8List days;
  final int tzOffsetMin;

  /// How far ahead to send. Two weeks keeps the alerts working through a long
  /// stretch with the PC off, and fits the terminal's storage with room left.
  static const defaultDays = 14;

  /// Longest name in bytes the terminal keeps. Arabic is two bytes a letter,
  /// so this is still around thirty letters.
  static const maxNameBytes = 60;

  static RosterPayload build({
    required List<RosterEmployee> employees,
    required ShiftResolver resolver,
    required DateTime from,
    int dayCount = defaultDays,
    required int tzOffsetMin,
  }) {
    final names = BytesBuilder();
    for (final e in employees) {
      final bytes = truncateUtf8(e.name.trim(), maxNameBytes);
      names
        ..add(_u16(e.id))
        ..addByte(bytes.length)
        ..add(bytes);
    }

    final days = BytesBuilder();
    final start = DateTime(from.year, from.month, from.day);
    for (var i = 0; i < dayCount; i++) {
      final d = DateTime(start.year, start.month, start.day + i);
      final entries = BytesBuilder();
      var n = 0;
      for (final e in employees) {
        final shift = resolver.shiftFor(e.id, d);
        if (shift == null) continue;
        // A flexible shift has no start time: the person is expected, so an
        // absence still shows, but nobody can be late.
        final startMinute = shift.kind == ShiftKind.flexible
            ? -1
            : shift.startMinute;
        entries
          ..add(_u16(e.id))
          ..add(_i16(startMinute))
          ..addByte(shift.graceInMinutes.clamp(0, 255))
          ..addByte(0);
        n++;
      }
      days
        ..add(_u32(d.year * 10000 + d.month * 100 + d.day))
        ..add(_u16(n))
        ..add(entries.takeBytes());
    }

    final n = names.takeBytes();
    final dd = days.takeBytes();
    return RosterPayload(
      version: _fnv1a([...n, ...dd, ..._i16(tzOffsetMin)]),
      names: n,
      days: dd,
      tzOffsetMin: tzOffsetMin,
    );
  }

  /// Cuts at a character boundary, never in the middle of a multi-byte one.
  static Uint8List truncateUtf8(String s, int maxBytes) {
    final all = utf8.encode(s);
    if (all.length <= maxBytes) return all;
    var end = maxBytes;
    // Continuation bytes are 10xxxxxx; back up to the start of a character.
    while (end > 0 && (all[end] & 0xC0) == 0x80) {
      end--;
    }
    return Uint8List.sublistView(all, 0, end);
  }

  static List<int> _u16(int v) => [v & 0xFF, (v >> 8) & 0xFF];
  static List<int> _i16(int v) => _u16(v & 0xFFFF);
  static List<int> _u32(int v) => [
    v & 0xFF,
    (v >> 8) & 0xFF,
    (v >> 16) & 0xFF,
    (v >> 24) & 0xFF,
  ];

  /// 32-bit FNV-1a, never 0 (the terminal reports 0 for "no roster").
  static int _fnv1a(List<int> bytes) {
    var h = 0x811C9DC5;
    for (final b in bytes) {
      h ^= b;
      // h * 0x01000193 mod 2^32, split as h * 2^24 + h * 0x193 so no
      // intermediate passes 2^53 -- the web build's integers are doubles.
      h = ((h & 0xFF) * 0x1000000 + h * 0x193) & 0xFFFFFFFF;
    }
    return h == 0 ? 1 : h;
  }
}
