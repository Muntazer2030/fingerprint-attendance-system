import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:attendance_admin/data/device_scanner.dart';

void main() {
  /// A fake network where exactly one address answers and every other one
  /// hangs until the caller gives up -- which is how a real subnet behaves.
  MockClient network({
    required String liveIp,
    Duration liveDelay = const Duration(milliseconds: 5),
    Duration deadDelay = const Duration(seconds: 30),
    void Function(String ip)? onProbe,
    int liveStatus = 401,
  }) {
    return MockClient((req) async {
      final ip = req.url.host;
      onProbe?.call(ip);
      if (ip == liveIp) {
        await Future<void>.delayed(liveDelay);
        return http.Response(liveStatus == 401 ? '{"error":"unauthorized"}' : '{"device":"attendance"}', liveStatus);
      }
      await Future<void>.delayed(deadDelay);
      return http.Response('', 200);
    });
  }

  test('finds the device even when it is the last address on the subnet',
      () async {
    final s = DeviceScanner(client: network(liveIp: '192.168.0.254'));
    final found = await s.scan('192.168.0');
    expect(found, '192.168.0.254');
    s.close();
  });

  test('a 401 counts as found, so discovery works before the token is known',
      () async {
    final s = DeviceScanner(
        client: network(liveIp: '192.168.0.42', liveStatus: 401));
    expect(await s.scan('192.168.0'), '192.168.0.42');
    s.close();
  });

  test('returns quickly instead of waiting for dead addresses', () async {
    // The regression this guards: batching meant a hit still waited for every
    // other probe in its batch to time out.
    final s = DeviceScanner(client: network(liveIp: '192.168.0.5'));
    final sw = Stopwatch()..start();
    final found = await s.scan('192.168.0');
    sw.stop();

    expect(found, '192.168.0.5');
    expect(sw.elapsed, lessThan(const Duration(seconds: 5)),
        reason: 'took ${sw.elapsedMilliseconds}ms - not exiting on first hit');
    s.close();
  });

  test('never exceeds its concurrency limit', () async {
    // Requests queued beyond the browser's socket pool burn their timeout
    // while waiting to be sent, which is how a live device got missed.
    var active = 0;
    var peak = 0;

    final client = MockClient((req) async {
      active++;
      peak = active > peak ? active : peak;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      active--;
      return http.Response('', 404);
    });

    final s = DeviceScanner(client: client);
    await s.scan('10.1.1');
    expect(peak, lessThanOrEqualTo(128));
    s.close();
  });

  test('checks the remembered address before sweeping anything', () async {
    final probed = <String>[];
    final s = DeviceScanner(
        client: network(liveIp: '192.168.0.77', onProbe: probed.add));

    final found = await s.scanAll(
      DeviceScanner.candidateSubnets('192.168.0.77'),
      preferFirst: '192.168.0.77',
    );

    expect(found, '192.168.0.77');
    expect(probed, ['192.168.0.77'],
        reason: 'swept the subnet instead of trying the known address first');
    s.close();
  });

  test('does not re-probe the remembered address during the sweep', () async {
    final probed = <String>[];
    // Remembered address is stale; the device has moved.
    final s = DeviceScanner(
        client: network(liveIp: '192.168.0.9', onProbe: probed.add));

    final found = await s.scanAll(['192.168.0'], preferFirst: '192.168.0.200');
    expect(found, '192.168.0.9');
    expect(probed.where((ip) => ip == '192.168.0.200').length, 1,
        reason: 'stale address probed more than once');
    s.close();
  });

  test('reports null when nothing answers', () async {
    final client = MockClient((req) async => http.Response('', 404));
    final s = DeviceScanner(client: client);
    expect(await s.scan('172.31.9'), isNull);
    s.close();
  });

  group('identifying the terminal', () {
    test('a router answering every URL with 200 HTML is not the terminal', () {
      // The real regression: 192.168.0.1 on the user's network does exactly
      // this, and the old scanner "found" it.
      expect(
          DeviceScanner.isTerminalResponse(http.Response(
              '<!DOCTYPE html><html>router login</html>', 200,
              headers: {'content-type': 'text/html'})),
          isFalse);
    });

    test('a router asking for its own password is not the terminal', () {
      expect(
          DeviceScanner.isTerminalResponse(
              http.Response('<html>401 Authorization Required</html>', 401)),
          isFalse);
      expect(
          DeviceScanner.isTerminalResponse(
              http.Response('{"error":"login required"}', 401)),
          isFalse);
    });

    test('the terminal refusing an untokened probe is the terminal', () {
      expect(
          DeviceScanner.isTerminalResponse(
              http.Response('{"error":"unauthorized"}', 401)),
          isTrue);
    });

    test('a sweep skips the router and finds the terminal behind it',
        () async {
      final s = DeviceScanner(
        client: MockClient((req) async {
          if (req.url.host == '192.168.0.1') {
            return http.Response('<html>router</html>', 200);
          }
          if (req.url.host == '192.168.0.60') {
            return http.Response('{"error":"unauthorized"}', 401);
          }
          return http.Response('not found', 404);
        }),
      );
      expect(await s.scan('192.168.0'), '192.168.0.60');
      s.close();
    });
  });

  group('using what this PC knows about its networks', () {
    test('only the PC\'s own subnets are searched when they are known', () {
      final subnets = DeviceScanner.candidateSubnets('',
          local: ['192.168.137', '192.168.0']);
      expect(subnets, ['192.168.137', '192.168.0']);
    });

    test('a remembered subnet the PC is no longer on is not searched', () {
      final subnets = DeviceScanner.candidateSubnets('10.9.9.9',
          local: ['192.168.0']);
      expect(subnets, ['192.168.0']);
    });

    test('a remembered subnet the PC is still on goes first', () {
      final subnets = DeviceScanner.candidateSubnets('192.168.0.40',
          local: ['192.168.137', '192.168.0']);
      expect(subnets, ['192.168.0', '192.168.137']);
    });

    test('ARP neighbours are tried before any sweep', () async {
      final probed = <String>[];
      final s = DeviceScanner(
          client: network(liveIp: '192.168.137.214', onProbe: probed.add));

      final found = await s.scanAll(['192.168.137'],
          priority: ['192.168.137.50', '192.168.137.214']);

      expect(found, '192.168.137.214');
      expect(probed.toSet(), {'192.168.137.50', '192.168.137.214'},
          reason: 'swept the subnet although a neighbour answered');
      s.close();
    });
  });

  group('subnet selection', () {    test('last known network is searched first', () {
      final subnets = DeviceScanner.candidateSubnets('10.20.30.40');
      expect(subnets.first, '10.20.30');
    });

    test('no subnet is searched twice', () {
      final subnets = DeviceScanner.candidateSubnets('192.168.1.5');
      expect(subnets.toSet().length, subnets.length);
      expect(subnets.first, '192.168.1');
    });

    test('falls back to the common list when nothing is remembered', () {
      expect(DeviceScanner.candidateSubnets(''),
          DeviceScanner.commonSubnets);
    });
  });
}
