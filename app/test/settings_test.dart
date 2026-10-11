import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_admin/data/settings.dart';
import 'package:attendance_admin/data/device_scanner.dart';

void main() {
  group('host normalisation accepts what people actually paste', () {
    test('a bare address is unchanged', () {
      expect(Settings.normaliseHost('192.168.137.206'), '192.168.137.206');
    });

    test('a pasted URL loses its scheme', () {
      // Uri.http() wants an authority; leaving the scheme in silently breaks
      // every request with no useful error.
      expect(Settings.normaliseHost('http://192.168.137.206'),
          '192.168.137.206');
      expect(Settings.normaliseHost('https://192.168.137.206/'),
          '192.168.137.206');
    });

    test('a path and stray whitespace are stripped', () {
      expect(Settings.normaliseHost('  192.168.137.206/api/v1/info  '),
          '192.168.137.206');
    });

    test('a host with a port keeps the port', () {
      expect(Settings.normaliseHost('192.168.137.206:8080'),
          '192.168.137.206:8080');
    });
  });

  group('subnet derivation for discovery', () {
    test('extracts the /24 prefix', () {
      expect(DeviceScanner.subnetOf('192.168.137.206'), '192.168.137');
      expect(DeviceScanner.subnetOf(' 10.0.0.5 '), '10.0.0');
    });

    test('returns null for anything that is not a bare IPv4 address', () {
      expect(DeviceScanner.subnetOf('attendance.local'), isNull);
      expect(DeviceScanner.subnetOf(''), isNull);
      expect(DeviceScanner.subnetOf('192.168.137'), isNull);
    });
  });
}
