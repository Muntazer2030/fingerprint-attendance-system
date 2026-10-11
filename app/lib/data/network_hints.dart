import 'network_hints_stub.dart' if (dart.library.io) 'network_hints_io.dart';

/// What this computer knows about its own networks.
///
/// [subnets] are the /24 prefixes of this PC's own IPv4 adapters -- the router
/// LAN it is on, and 192.168.137 when it is sharing its connection to the
/// terminal. The terminal can only be on one of those, so there is no point
/// sweeping anything else.
///
/// [neighbours] are addresses from the PC's ARP table inside those subnets:
/// machines it has exchanged packets with recently. When the PC is sharing
/// its connection it is also the DHCP server, so the terminal is nearly always
/// in here, and probing a handful of known hosts beats sweeping 254.
class NetworkHints {
  const NetworkHints({this.subnets = const [], this.neighbours = const []});

  final List<String> subnets;
  final List<String> neighbours;

  bool get isEmpty => subnets.isEmpty;

  /// Empty in the browser, which cannot see network adapters.
  static Future<NetworkHints> discover() => discoverNetworkHints();
}
