import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_admin/data/name_raster.dart';

void main() {
  group('script detection drives layout direction', () {
    test('Arabic names are RTL', () {
      expect(NameRaster.isRtl('محمد'), isTrue);
      expect(NameRaster.isRtl('علي حسن'), isTrue);
    });

    test('Latin names are LTR', () {
      expect(NameRaster.isRtl('Ahmed'), isFalse);
      expect(NameRaster.isRtl('Sara Khalid'), isFalse);
    });

    test('a mixed name is treated as RTL', () {
      // Staff lists often mix scripts; the Arabic portion should still lay
      // out right-to-left rather than being reversed.
      expect(NameRaster.isRtl('Ali علي'), isTrue);
    });

    test('digits and punctuation alone are not RTL', () {
      expect(NameRaster.isRtl('12345'), isFalse);
      expect(NameRaster.isRtl(''), isFalse);
    });
  });

  test('bitmap size matches the device buffer exactly', () {
    // USERS_NAME_BITMAP_BYTES on the firmware side is 256; a mismatch is
    // rejected by the device, so pin it here.
    expect(NameRaster.width, 128);
    expect(NameRaster.height, 16);
    expect(NameRaster.bytes, 256);
  });
}
