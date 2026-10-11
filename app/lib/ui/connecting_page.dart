import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/device_scanner.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import 'settings_page.dart';
import 'theme.dart';

/// Finds and connects to the terminal without the operator typing an address.
///
/// The old flow put a blank IP field in front of someone whose device gets a
/// different address on nearly every boot. This searches instead: the network
/// it was last seen on, then the usual private ranges. Manual entry stays
/// available, but as a fallback rather than the front door.
class ConnectingPage extends StatefulWidget {
  const ConnectingPage({super.key});

  @override
  State<ConnectingPage> createState() => _ConnectingPageState();
}

enum _Phase { searching, needsToken, failed }

class _ConnectingPageState extends State<ConnectingPage> {
  _Phase _phase = _Phase.searching;
  String _subnet = '';
  double _progress = 0;
  String? _foundHost;
  DeviceScanner? _scanner;
  bool _manual = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

  @override
  void dispose() {
    _scanner?.cancel();
    _scanner?.close();
    super.dispose();
  }

  Future<void> _search() async {
    final settings = AppScope.settingsOf(context);
    final scanner = DeviceScanner();
    _scanner = scanner;

    setState(() {
      _phase = _Phase.searching;
      _progress = 0;
    });

    try {
      final found = await scanner.locate(
        lastKnownHost: settings.host,
        onProgress: (subnet, p) {
          if (!mounted) return;
          setState(() {
            _subnet = subnet;
            _progress = p;
          });
        },
      );

      if (!mounted) return;
      if (found == null) {
        setState(() => _phase = _Phase.failed);
        return;
      }

      _foundHost = found;

      // An address alone is not a connection, so nothing is committed yet --
      // committing the address early made the app count as configured and
      // leave this screen before the token had been checked. If a token is
      // remembered, try it; success goes straight through to the dashboard.
      final token = settings.rememberedToken;
      if (token.isNotEmpty) {
        final api = ApiClient(host: found, token: token);
        try {
          await api.info();
          // AppShell watches Settings and swaps itself in once configured.
          await settings.setConnection(found, token);
          return;
        } on ApiException {
          // Remembered token does not match this device.
        } finally {
          api.close();
        }
      }
      if (mounted) setState(() => _phase = _Phase.needsToken);
    } catch (_) {
      if (mounted) setState(() => _phase = _Phase.failed);
    } finally {
      scanner.close();
      _scanner = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    if (_manual) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l.deviceAddress),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => _manual = false),
          ),
        ),
        body: const SettingsPage(firstRun: true),
      );
    }

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.fingerprint,
                    size: 34,
                    color: scheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l.appTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 32),
                ..._phaseContent(context, l, scheme),
                const SizedBox(height: 28),
                TextButton.icon(
                  onPressed: () => setState(() => _manual = true),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(l.enterManually),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _phaseContent(
    BuildContext context,
    AppLocalizations l,
    ColorScheme scheme,
  ) {
    switch (_phase) {
      case _Phase.searching:
        return [
          Text(
            l.searchingNetwork,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text('$_subnet.x', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _progress == 0 ? null : _progress,
              minHeight: 6,
            ),
          ),
        ];

      case _Phase.needsToken:
        return [
          StatusPill(
            label: '${l.deviceFound}: $_foundHost',
            color: AppTheme.present,
            icon: Icons.check,
          ),
          const SizedBox(height: 20),
          Text(l.tokenNeeded, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            l.tokenWhere,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          _TokenField(host: _foundHost!),
        ];

      case _Phase.failed:
        return [
          Icon(Icons.wifi_find_outlined, size: 40, color: scheme.error),
          const SizedBox(height: 16),
          Text(
            l.deviceNotFound,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            l.notFoundHelp,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _search,
            icon: const Icon(Icons.refresh),
            label: Text(l.retry),
          ),
        ];
    }
  }
}

/// Token entry shown only once the device has been located, so the operator
/// never has to supply an address and a token in the same breath.
class _TokenField extends StatefulWidget {
  const _TokenField({required this.host});
  final String host;

  @override
  State<_TokenField> createState() => _TokenFieldState();
}

class _TokenFieldState extends State<_TokenField> {
  final _controller = TextEditingController();
  bool _checking = false;
  String? _error;
  bool _prefilled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Carry over a previously saved token. It usually still works -- the
    // device moved, the token did not -- so there is nothing to retype.
    if (_prefilled) return;
    _prefilled = true;
    _controller.text = AppScope.settingsOf(context).rememberedToken;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final settings = AppScope.settingsOf(context);
    final token = _controller.text.trim();
    if (token.isEmpty) return;

    setState(() {
      _checking = true;
      _error = null;
    });

    // Remembered before the check: a token that fails against a stale address
    // is still the right token, and losing it means typing it again. It only
    // goes live once the device accepts it.
    await settings.rememberToken(token);

    final api = ApiClient(host: widget.host, token: token);
    try {
      await api.info();
      await settings.setConnection(widget.host, token);
    } on ApiException catch (e) {
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        setState(() {
          _error = e.isAuthFailure ? l.tokenRejected : e.toString();
        });
      }
    } finally {
      api.close();
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          onSubmitted: (_) => _submit(),
          onChanged: (v) => AppScope.settingsOf(context).rememberToken(v),
          decoration: InputDecoration(
            labelText: l.deviceToken,
            prefixIcon: const Icon(Icons.key_outlined),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: AppTheme.danger)),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _checking ? null : _submit,
            child: _checking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l.connect),
          ),
        ),
      ],
    );
  }
}
