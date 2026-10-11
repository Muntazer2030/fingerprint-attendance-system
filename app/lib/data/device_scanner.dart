import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'network_hints.dart';

/// Finds the terminal on the local network.
///
/// The device takes whatever address DHCP hands it, and that changes often
/// enough that asking the operator to hunt it down is not a reasonable design.
///
/// Order of search, fastest first:
///   1. the address it was last seen at -- usually it has not moved;
///   2. hosts in this PC's ARP table -- when the PC shares its connection it
///      is the DHCP server, so the terminal is nearly always listed;
///   3. a sweep of this PC's own subnets only. The terminal is either on the
///      router LAN the PC is on, or on the PC's shared adapter; nothing else
///      is reachable, so nothing else is worth scanning.
/// The browser cannot see adapters or ARP, so it falls back to a list of
/// common home and office ranges.
class DeviceScanner {
  DeviceScanner({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Probes genuinely in flight at once. A worker pool, not batches: batching
  /// made every batch wait for its slowest dead address.
  ///
  /// The browser caps sockets per host group and queues the rest, and a queued
  /// request burns its own timeout without ever being sent, so it stays low
  /// there. A desktop socket has no such queue.
  static int get _concurrency => kIsWeb ? 32 : 128;

  /// How long to wait on one address. Generous in the browser because it
  /// includes queueing; on desktop it is pure network time on a LAN, where a
  /// live terminal answers in tens of milliseconds even on 10 Mbps.
  static Duration get _perHostTimeout => kIsWeb
      ? const Duration(milliseconds: 2500)
      : const Duration(milliseconds: 1200);

  /// Networks worth trying when nothing better is known (the browser build).
  static const commonSubnets = <String>[
    '192.168.1',
    '192.168.0',
    '192.168.137', // Windows Internet Connection Sharing
    '10.0.0',
    '192.168.8',
    '172.16.0',
  ];

  /// Derives "192.168.137" from anything that looks like an address in that
  /// subnet, so a stale entry still points the scan at the right network.
  static String? subnetOf(String host) {
    final m = RegExp(
      r'^(\d{1,3}\.\d{1,3}\.\d{1,3})\.\d{1,3}$',
    ).firstMatch(host.trim());
    return m?.group(1);
  }

  /// Subnets to sweep, most likely first.
  ///
  /// With [local] known (desktop), only those are searched: the last known
  /// subnet goes first if it is still one of them. Without it (browser), the
  /// last known subnet and then the common list.
  static List<String> candidateSubnets(
    String lastKnownHost, {
    List<String> local = const [],
  }) {
    final last = subnetOf(lastKnownHost);
    final seen = <String>{};
    final out = <String>[];
    final pool = local.isNotEmpty ? local : commonSubnets;
    final ordered = [
      if (last != null && (local.isEmpty || local.contains(last))) last,
      ...pool,
    ];
    for (final s in ordered) {
      if (seen.add(s)) out.add(s);
    }
    return out;
  }

  /// Whether an HTTP answer came from our terminal.
  ///
  /// Probes carry no token, so the terminal always replies 401 with a JSON
  /// body of `{"error":"unauthorized"}`. Checking the body matters: accepting
  /// any 200 or 401 meant a home router -- which answers every URL with its
  /// login page -- was "found" as the terminal, and the background relocation
  /// then saved the router's address as the device.
  static bool isTerminalResponse(http.Response r) {
    if (r.statusCode != 401 && r.statusCode != 200) return false;
    try {
      final j = jsonDecode(r.body);
      if (j is! Map) return false;
      if (r.statusCode == 401) return j['error'] == 'unauthorized';
      return j['device'] == 'attendance';
    } catch (_) {
      return false;
    }
  }

  bool _cancelled = false;
  void cancel() => _cancelled = true;

  Future<bool> _probe(String ip, Duration timeout) async {
    try {
      final r = await _client
          .get(Uri.http(ip, '/api/v1/info'))
          .timeout(timeout);
      return isTerminalResponse(r);
    } catch (_) {
      return false;
    }
  }

  /// Checks one address on its own, with a longer allowance.
  Future<bool> check(String ip) async {
    if (ip.isEmpty) return false;
    return _probe(ip, const Duration(seconds: 4));
  }

  /// Probes a short list all at once and returns the first that answers.
  Future<String?> checkAny(List<String> ips) async {
    if (ips.isEmpty) return null;
    final completer = Completer<String?>();
    var pending = ips.length;
    for (final ip in ips) {
      _probe(ip, const Duration(seconds: 3)).then((hit) {
        pending--;
        if (completer.isCompleted) return;
        if (hit) {
          completer.complete(ip);
        } else if (pending == 0) {
          completer.complete(null);
        }
      });
    }
    return completer.future;
  }

  /// Sweeps `subnet.1` .. `subnet.254`, returning the first responder.
  ///
  /// Keeps [_concurrency] probes genuinely in flight and starts a replacement
  /// the instant one finishes, so a slow dead address never blocks the others.
  /// Completes as soon as anything answers, abandoning the rest.
  Future<String?> scan(
    String subnet, {
    void Function(double progress)? onProgress,
    String? skip,
    Set<String> skipAll = const {},
  }) async {
    final hosts = <String>[
      for (var i = 1; i <= 254; i++)
        if ('$subnet.$i' != skip && !skipAll.contains('$subnet.$i'))
          '$subnet.$i',
    ];

    final completer = Completer<String?>();
    var next = 0;
    var done = 0;
    var settled = false;
    final timeout = _perHostTimeout;

    void finish(String? result) {
      if (settled) return;
      settled = true;
      completer.complete(result);
    }

    void pump() {
      while (!settled && next < hosts.length) {
        final inFlight = next - done;
        if (inFlight >= _concurrency) return;

        final ip = hosts[next++];
        _probe(ip, timeout).then((hit) {
          done++;
          if (_cancelled) {
            finish(null);
            return;
          }
          if (hit) {
            finish(ip);
            return;
          }
          onProgress?.call(done / hosts.length);
          if (done >= hosts.length) {
            finish(null);
          } else {
            pump();
          }
        });
      }
    }

    pump();
    if (hosts.isEmpty) finish(null);
    return completer.future;
  }

  /// Walks several networks and returns the first device found.
  ///
  /// [preferFirst] is checked on its own before anything else, then every
  /// [priority] address at once, and only then the sweeps.
  Future<String?> scanAll(
    List<String> subnets, {
    String? preferFirst,
    List<String> priority = const [],
    void Function(String subnet, double progress)? onProgress,
  }) async {
    if (preferFirst != null && preferFirst.isNotEmpty) {
      onProgress?.call(subnetOf(preferFirst) ?? '', 0);
      if (await check(preferFirst)) return preferFirst;
    }
    if (_cancelled) return null;

    final quick = [
      for (final ip in priority)
        if (ip != preferFirst) ip,
    ];
    if (quick.isNotEmpty) {
      onProgress?.call(subnetOf(quick.first) ?? '', 0);
      final hit = await checkAny(quick);
      if (hit != null) return hit;
    }

    for (final subnet in subnets) {
      if (_cancelled) return null;
      final found = await scan(
        subnet,
        skip: preferFirst,
        skipAll: quick.toSet(),
        onProgress: (p) => onProgress?.call(subnet, p),
      );
      if (found != null) return found;
    }
    return null;
  }

  /// The whole search, as every caller wants it: learn this PC's networks,
  /// then [scanAll] with them.
  Future<String?> locate({
    required String lastKnownHost,
    void Function(String subnet, double progress)? onProgress,
  }) async {
    final hints = await NetworkHints.discover();
    return scanAll(
      candidateSubnets(lastKnownHost, local: hints.subnets),
      preferFirst: lastKnownHost,
      priority: hints.neighbours,
      onProgress: onProgress,
    );
  }

  void close() => _client.close();
}
