import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../l10n/app_localizations.dart';
import 'theme.dart';

/// Wi-Fi for when the Ethernet cable is not connected.
///
/// Set while the app can still reach the terminal (usually over the cable).
/// The terminal keeps it and switches to it on its own; the app then finds the
/// terminal at its new address by itself.
class WifiPage extends StatefulWidget {
  const WifiPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<WifiPage> createState() => _WifiPageState();
}

class _WifiPageState extends State<WifiPage> {
  WifiStatus? _status;
  Object? _loadError;
  bool _busy = false;
  bool _scanning = false;
  bool _showPassword = false;
  List<WifiNetwork>? _networks;
  String? _passwordError;

  final _ssid = TextEditingController();
  final _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ssid.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final s = await widget.api.wifiStatus();
      if (!mounted) return;
      setState(() {
        _status = s;
        _loadError = null;
        if (_ssid.text.isEmpty) _ssid.text = s.ssid;
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _scan() async {
    setState(() => _scanning = true);
    try {
      final n = await widget.api.wifiScan();
      if (mounted) setState(() => _networks = n);
    } catch (e) {
      if (mounted) _snack(e.toString());
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _save({bool forget = false}) async {
    final l = AppLocalizations.of(context)!;
    final ssid = forget ? '' : _ssid.text.trim();
    final pw = forget ? '' : _password.text;
    // The terminal checks too; saying so here is friendlier than its 400.
    if (!forget && pw.isNotEmpty && pw.length < 8) {
      setState(() => _passwordError = l.wifiPasswordShort);
      return;
    }
    setState(() {
      _busy = true;
      _passwordError = null;
    });
    try {
      final s = await widget.api.setWifi(ssid, pw);
      if (!mounted) return;
      setState(() {
        _status = s;
        _password.clear();
        if (forget) _ssid.clear();
      });
      _snack(forget ? l.wifiForgotten : l.saved);
    } catch (e) {
      if (mounted) _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final s = _status;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.wifiTitle),
        actions: [
          IconButton(
            tooltip: l.refresh,
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loadError != null
          ? Center(child: Text(_loadError.toString()))
          : s == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                CappedWidth(
                  maxWidth: 600,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.wifiIntro),
                      const SizedBox(height: 16),
                      _StatusCard(status: s),
                      const SizedBox(height: 28),
                      Text(
                        l.wifiNetwork,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _ssid,
                              // Save is enabled by a non-empty name.
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                labelText: l.wifiSsid,
                                prefixIcon: const Icon(Icons.wifi),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: OutlinedButton.icon(
                              onPressed: _scanning || _busy ? null : _scan,
                              icon: _scanning
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.wifi_find),
                              label: Text(l.wifiScan),
                            ),
                          ),
                        ],
                      ),
                      if (_scanning) ...[
                        const SizedBox(height: 6),
                        Text(
                          l.wifiScanning,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if (_networks != null) ...[
                        const SizedBox(height: 10),
                        if (_networks!.isEmpty)
                          Text(
                            l.wifiNoneFound,
                            style: const TextStyle(color: AppTheme.warning),
                          )
                        else
                          Card(
                            child: Column(
                              children: [
                                for (final n in _networks!)
                                  ListTile(
                                    dense: true,
                                    leading: Icon(_barsIcon(n.bars)),
                                    title: Text(n.ssid),
                                    subtitle: Text(
                                      '${n.rssi} dBm'
                                      '${n.secure ? '' : '  ·  ${l.wifiOpen}'}',
                                    ),
                                    trailing: n.secure
                                        ? const Icon(
                                            Icons.lock_outline,
                                            size: 16,
                                          )
                                        : null,
                                    selected: _ssid.text == n.ssid,
                                    onTap: () =>
                                        setState(() => _ssid.text = n.ssid),
                                  ),
                              ],
                            ),
                          ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        obscureText: !_showPassword,
                        decoration: InputDecoration(
                          labelText: l.wifiPassword,
                          hintText: s.configured ? l.wifiPasswordKeep : null,
                          errorText: _passwordError,
                          prefixIcon: const Icon(Icons.key_outlined),
                          suffixIcon: IconButton(
                            tooltip: l.wifiShowPassword,
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l.wifiPasswordHelp,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed: _busy || _ssid.text.trim().isEmpty
                                ? null
                                : () => _save(),
                            icon: const Icon(Icons.check),
                            label: Text(l.save),
                          ),
                          if (s.configured)
                            OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _save(forget: true),
                              icon: const Icon(Icons.wifi_off),
                              label: Text(l.wifiForget),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  static IconData _barsIcon(int bars) => switch (bars) {
    4 => Icons.network_wifi,
    3 => Icons.network_wifi_3_bar,
    2 => Icons.network_wifi_2_bar,
    1 => Icons.network_wifi_1_bar,
    _ => Icons.signal_wifi_0_bar,
  };
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final WifiStatus status;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final s = status;

    final (IconData icon, Color color, String text) = switch (s.active) {
      'wifi' => (Icons.wifi, AppTheme.warning, l.wifiActiveWifi(s.ip)),
      'eth' => (Icons.settings_ethernet, AppTheme.present, l.wifiActiveEth),
      _ => (Icons.cloud_off, AppTheme.danger, l.wifiActiveNone),
    };

    final wifiLine = !s.configured
        ? l.wifiNotSet
        : switch (s.state) {
            'connected' => l.wifiConnected(s.ssid, s.rssi),
            'connecting' => l.wifiConnecting(s.ssid),
            'failed' => l.wifiFailed(s.ssid, s.lastError),
            _ => l.wifiStandby(s.ssid),
          };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 10),
                Expanded(child: Text(text)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  s.configured ? Icons.wifi_password : Icons.wifi_off,
                  size: 18,
                  color: s.state == 'failed' ? AppTheme.danger : null,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(wifiLine)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
