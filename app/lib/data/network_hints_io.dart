import 'dart:io';

import 'network_hints.dart';

Future<NetworkHints> discoverNetworkHints() async {
  final subnets = <String>[];
  final own = <String>{};

  try {
    final ifaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final iface in ifaces) {
      for (final a in iface.addresses) {
        final ip = a.address;
        // Link-local means the adapter never got an address; nothing to scan.
        if (ip.startsWith('169.254.')) continue;
        own.add(ip);
        final prefix = ip.substring(0, ip.lastIndexOf('.'));
        if (!subnets.contains(prefix)) subnets.add(prefix);
      }
    }
  } catch (_) {
    // Fall through with whatever was gathered.
  }

  // The shared-connection adapter first: if the PC is sharing its connection,
  // that cable is almost certainly where the terminal is.
  subnets.sort((a, b) {
    int rank(String s) => s == '192.168.137' ? 0 : 1;
    return rank(a).compareTo(rank(b));
  });

  return NetworkHints(
    subnets: subnets,
    neighbours: await _arpNeighbours(subnets.toSet(), own),
  );
}

/// Reads `arp -a`. Only dynamic entries count: static ones are broadcast and
/// multicast addresses, and the gateway is dropped because it is never the
/// terminal (and a router answers every URL, which once fooled the scanner).
Future<List<String>> _arpNeighbours(
  Set<String> subnets,
  Set<String> own,
) async {
  if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
    return const [];
  }
  try {
    final r = await Process.run('arp', [
      '-a',
    ]).timeout(const Duration(seconds: 3));
    if (r.exitCode != 0) return const [];

    final out = <String>[];
    final ipRe = RegExp(r'(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})');
    for (final line in (r.stdout as String).split('\n')) {
      if (Platform.isWindows && !line.contains('dynamic')) continue;
      final m = ipRe.firstMatch(line);
      if (m == null) continue;
      final ip = m.group(0)!;
      final prefix = '${m.group(1)}.${m.group(2)}.${m.group(3)}';
      final last = int.parse(m.group(4)!);
      if (!subnets.contains(prefix) || own.contains(ip)) continue;
      if (last == 0 || last == 1 || last == 255) continue;
      if (!out.contains(ip)) out.add(ip);
    }
    return out;
  } catch (_) {
    return const [];
  }
}
