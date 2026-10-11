import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Renders text to the 1bpp bitmap the terminal displays.
///
/// This is decision D3. Arabic needs contextual shaping -- four glyph forms per
/// letter -- plus right-to-left layout. Rather than implement a shaper in
/// firmware for a 128x64 panel, we use Flutter's real text engine here and ship
/// the device a finished raster. The device only ever blits pixels.
///
/// Output is 128x16, row-major, MSB first: 16 bytes per row, 256 bytes total,
/// matching USERS_NAME_BITMAP_BYTES and UI_STRING_BYTES on the device.
class NameRaster {
  static const int width = 128;
  static const int height = 16;
  static const int bytes = width * height ~/ 8;

  /// Scratch canvas with generous margins. Text is drawn here first, then the
  /// *ink* is measured and placed -- never the font's reported line box.
  static const int _padW = 320;
  static const int _padH = 64;
  static const double _originX = 96;
  static const double _originY = 20;

  static const double _maxFontSize = 15;
  static const double _minFontSize = 7;

  /// Antialiased edges land as mid greys. A high cut keeps thin strokes and,
  /// critically, the small dots on Arabic letters: at a 50% cut the dot under
  /// jeem drops out and it reads as haa.
  static const int _inkThreshold = 200;

  /// True when the string contains Arabic-range codepoints, which decides
  /// text direction.
  static bool isRtl(String s) {
    for (final r in s.runes) {
      // Arabic, Arabic Supplement, Arabic Extended-A, Presentation Forms.
      if ((r >= 0x0600 && r <= 0x06FF) ||
          (r >= 0x0750 && r <= 0x077F) ||
          (r >= 0x08A0 && r <= 0x08FF) ||
          (r >= 0xFB50 && r <= 0xFDFF) ||
          (r >= 0xFE70 && r <= 0xFEFF)) {
        return true;
      }
    }
    return false;
  }

  static TextPainter _layout(String text, double size, bool rtl) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.black,
          fontSize: size,
          // A heavier weight survives 1-bit thresholding far better. Arabic
          // aliases worse than Latin: thin strokes and diacritics drop out
          // entirely at light weights on a mono panel.
          fontWeight: FontWeight.w600,
          // Room for ascenders and descenders; the ink measurement below is
          // what actually decides placement.
          height: 1.4,
        ),
      ),
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      maxLines: 1,
    )..layout();
  }

  /// Draws onto the oversized scratch canvas and returns its greyscale rows.
  static Future<Uint8List?> _paint(TextPainter painter) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _padW.toDouble(), _padH.toDouble()),
      Paint()..color = Colors.white,
    );
    painter.paint(canvas, const Offset(_originX, _originY));

    final image = await recorder.endRecording().toImage(_padW, _padH);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data?.buffer.asUint8List();
  }

  /// Tight bounds of everything actually inked: (left, top, right, bottom),
  /// or null when nothing was drawn.
  static (int, int, int, int)? _inkBounds(Uint8List rgba) {
    int minX = _padW, minY = _padH, maxX = -1, maxY = -1;
    for (int y = 0; y < _padH; y++) {
      for (int x = 0; x < _padW; x++) {
        final i = (y * _padW + x) * 4;
        final lum =
            (rgba[i] * 299 + rgba[i + 1] * 587 + rgba[i + 2] * 114) ~/ 1000;
        if (lum < _inkThreshold) {
          if (x < minX) minX = x;
          if (y < minY) minY = y;
          if (x > maxX) maxX = x;
          if (y > maxY) maxY = y;
        }
      }
    }
    return maxX < 0 ? null : (minX, minY, maxX, maxY);
  }

  static Future<Uint8List> render(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return Uint8List(bytes);

    final rtl = isRtl(trimmed);

    Uint8List? rgba;
    (int, int, int, int)? ink;

    // Shrink until the real ink fits, rather than trusting the line box.
    // Arabic ink routinely overflows its line box -- the dot under jeem sits
    // below the descender line, which is exactly what was being clipped.
    for (double size = _maxFontSize; size >= _minFontSize; size -= 0.5) {
      final painter = _layout(trimmed, size, rtl);
      rgba = await _paint(painter);
      if (rgba == null) return Uint8List(bytes);

      ink = _inkBounds(rgba);
      if (ink == null) return Uint8List(bytes);

      final w = ink.$3 - ink.$1 + 1;
      final h = ink.$4 - ink.$2 + 1;
      if (w <= width && h <= height) break;
    }

    if (rgba == null || ink == null) return Uint8List(bytes);

    final (l, t, r, b) = ink;
    final inkW = r - l + 1;
    final inkH = b - t + 1;

    // Centre the ink itself, so a string with a descender is not pushed up and
    // one without is not pushed down.
    final offX = ((width - inkW) / 2).floor();
    final offY = ((height - inkH) / 2).floor();

    final out = Uint8List(bytes);
    for (int y = 0; y < inkH; y++) {
      final dy = offY + y;
      if (dy < 0 || dy >= height) continue;
      for (int x = 0; x < inkW; x++) {
        final dx = offX + x;
        if (dx < 0 || dx >= width) continue;

        final i = ((t + y) * _padW + (l + x)) * 4;
        final lum =
            (rgba[i] * 299 + rgba[i + 1] * 587 + rgba[i + 2] * 114) ~/ 1000;
        if (lum < _inkThreshold) {
          final bit = dy * width + dx;
          out[bit >> 3] |= 0x80 >> (bit & 7);
        }
      }
    }
    return out;
  }
}
