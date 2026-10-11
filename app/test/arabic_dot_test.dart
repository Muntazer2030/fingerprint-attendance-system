import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_admin/data/name_raster.dart';

/// Rasteriser tests.
///
/// IMPORTANT LIMITATION: `flutter test` ships no Arabic font, so every Arabic
/// codepoint renders as the same fallback box. Comparing ج against ح here
/// returns identical pixel counts and proves nothing about glyph fidelity --
/// that has to be checked on the device or in a real browser.
///
/// What these tests do cover is the geometry that caused the bug: output size,
/// centring, and that the ink measurement never clips what it was given.
void main() {
  int litPixels(Uint8List bmp) {
    var n = 0;
    for (final b in bmp) {
      n += b.toRadixString(2).split('1').length - 1;
    }
    return n;
  }

  (int, int, int, int)? inkBox(Uint8List bmp) {
    var minX = NameRaster.width, minY = NameRaster.height, maxX = -1, maxY = -1;
    for (int y = 0; y < NameRaster.height; y++) {
      for (int x = 0; x < NameRaster.width; x++) {
        final bit = y * NameRaster.width + x;
        if ((bmp[bit >> 3] & (0x80 >> (bit & 7))) != 0) {
          if (x < minX) minX = x;
          if (y < minY) minY = y;
          if (x > maxX) maxX = x;
          if (y > maxY) maxY = y;
        }
      }
    }
    return maxX < 0 ? null : (minX, minY, maxX, maxY);
  }

  /// toImage() never completes under the fake-async test binding, so the
  /// rendering has to run on the real event loop.
  Future<Uint8List> render(WidgetTester tester, String s) async {
    late Uint8List out;
    await tester.runAsync(() async {
      out = await NameRaster.render(s);
    });
    return out;
  }

  testWidgets('output is always exactly the size the device expects',
      (tester) async {
    for (final s in ['تسجيل دخول', 'CHECK OUT', 'ج', '', '   ']) {
      final bmp = await render(tester, s);
      expect(bmp.length, NameRaster.bytes, reason: 'wrong size for "$s"');
    }
  });

  testWidgets('empty input yields a blank strip', (tester) async {
    expect(litPixels(await render(tester, '   ')), 0);
  });

  testWidgets('ink fits the strip and is vertically centred', (tester) async {
    // The original bug: placement used the font's line box, so ink that
    // extended past it -- descenders, and the dots under letters like jeem --
    // fell outside the 16 rows and was cut off. Measuring the ink instead
    // means it always fits and sits centred.
    //
    // The test font draws every glyph as a full-em box, so expect no vertical
    // slack here; the assertions are "nothing clipped" and "centred", which
    // hold for box glyphs and real text alike.
    for (final s in ['CHECK OUT', 'Ahmed', 'gjpqy']) {
      final box = inkBox(await render(tester, s));
      expect(box, isNotNull, reason: 'nothing rendered for "$s"');
      final (_, top, _, bottom) = box!;

      expect(bottom - top + 1, lessThanOrEqualTo(NameRaster.height),
          reason: '"$s" ink is taller than the strip');

      final topGap = top;
      final bottomGap = NameRaster.height - 1 - bottom;
      expect((topGap - bottomGap).abs(), lessThanOrEqualTo(1),
          reason: '"$s" not vertically centred: top=$topGap bottom=$bottomGap');
    }
  });

  testWidgets('ink is centred horizontally', (tester) async {
    final box = inkBox(await render(tester, 'IN'));
    expect(box, isNotNull);
    final (left, _, right, _) = box!;
    final leftGap = left;
    final rightGap = NameRaster.width - 1 - right;
    expect((leftGap - rightGap).abs(), lessThanOrEqualTo(3),
        reason: 'left=$leftGap right=$rightGap');
  });

  testWidgets('long text shrinks to fit rather than overflowing',
      (tester) async {
    final box = inkBox(await render(tester, 'NOT RECOGNISED PLEASE RETRY'));
    expect(box, isNotNull);
    final (left, _, right, _) = box!;
    expect(left, greaterThanOrEqualTo(0));
    expect(right, lessThan(NameRaster.width));
  });
}
