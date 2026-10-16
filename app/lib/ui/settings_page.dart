import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/app_reset.dart';
import '../data/device_scanner.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import 'lock_page.dart';
import 'reset_app_dialog.dart';
import 'theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.firstRun = false});

  final bool firstRun;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _host;
  late TextEditingController _token;
  String? _probeResult;
  bool _probing = false;
  bool _scanning = false;
  double _scanProgress = 0;
  bool _ok = false;

  @override
  void initState() {
    super.initState();
    _host = TextEditingController();
    _token = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = SettingsScope.of(context);
    if (_host.text.isEmpty) _host.text = s.host;
    if (_token.text.isEmpty) _token.text = s.rememberedToken;
  }

  @override
  void dispose() {
    _host.dispose();
    _token.dispose();
    super.dispose();
  }

  /// Looks for the terminal across every candidate network. The device takes
  /// whatever DHCP hands it, and moving it between networks changes its subnet
  /// entirely, so hunting through `arp -a` should not be the user's job.
  Future<void> _findDevice() async {
    final l = AppLocalizations.of(context)!;
    final scanner = DeviceScanner();

    setState(() {
      _scanning = true;
      _scanProgress = 0;
      _probeResult = null;
    });

    try {
      final found = await scanner.locate(
        lastKnownHost: _host.text.trim(),
        onProgress: (subnet, p) {
          if (mounted) setState(() => _scanProgress = p);
        },
      );

      if (!mounted) return;
      if (found == null) {
        setState(() {
          _ok = false;
          _probeResult = l.deviceNotFound;
        });
        return;
      }

      _host.text = found;
      setState(() => _probeResult = '${l.deviceFound}: $found');
      // A found address is only useful once the token is checked against it.
      if (_token.text.trim().isNotEmpty) await _saveAndProbe();
    } finally {
      scanner.close();
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _saveAndProbe() async {
    final settings = SettingsScope.of(context);
    setState(() {
      _probing = true;
      _probeResult = null;
    });

    final api = ApiClient(host: _host.text.trim(), token: _token.text.trim());
    await settings.rememberToken(_token.text);
    try {
      final info = await api.info();
      await settings.setConnection(_host.text, _token.text);
      if (!mounted) return;
      setState(() {
        _ok = true;
        _probeResult =
            '${info.board} · ${info.display} · '
            'fw ${info.firmware} · ${info.events.head} events';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ok = false;
        _probeResult = e is ApiException && e.isAuthFailure
            ? AppLocalizations.of(context)!.tokenRejected
            : e.toString();
      });
    } finally {
      if (mounted) setState(() => _probing = false);
      api.close();
    }
  }

  Future<void> _password(PasswordAction action) async {
    final l = AppLocalizations.of(context)!;
    final done = await showDialog<bool>(
      context: context,
      builder: (_) =>
          PasswordDialog(action: action, settings: SettingsScope.of(context)),
    );
    if (done != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          action == PasswordAction.remove ? l.passwordRemoved : l.passwordSaved,
        ),
      ),
    );
  }

  Future<void> _resetApp() async {
    // Looked up before the await: a reset sends the app back to the connect
    // screen, and this page is gone by the time it finishes.
    final settings = AppScope.settingsOf(context);
    final db = AppScope.dbOf(context);
    final sync = AppScope.syncOf(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => ResetAppDialog(settings: settings),
    );
    if (ok != true) return;
    await resetApp(settings: settings, db: db, sync: sync);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final settings = SettingsScope.of(context);

    final body = ListView(
      padding: const EdgeInsets.all(24),
      children: [
        CappedWidth(
          maxWidth: 520,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.deviceAddress,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _host,
                // Not saved while typing: clearing the field to type a new
                // address made the app unconfigured and threw this page away
                // mid-edit. Connect checks the address, then saves it.
                onSubmitted: (_) => _saveAndProbe(),
                decoration: InputDecoration(
                  hintText: l.deviceAddressHint,
                  prefixIcon: const Icon(Icons.lan_outlined),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l.deviceToken,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _token,
                // Remembered on every keystroke so it is never lost, but only
                // made live by Connect once the device accepts it.
                onChanged: (v) => SettingsScope.of(context).rememberToken(v),
                onSubmitted: (_) => _saveAndProbe(),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.key_outlined),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: (_probing || _scanning) ? null : _saveAndProbe,
                    icon: _probing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.link),
                    label: Text(l.connect),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: (_probing || _scanning) ? null : _findDevice,
                    icon: const Icon(Icons.radar),
                    label: Text(l.findDevice),
                  ),
                ],
              ),
              if (_scanning) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(value: _scanProgress),
                const SizedBox(height: 6),
                Text(l.scanning, style: Theme.of(context).textTheme.bodySmall),
              ],
              if (_probeResult != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (_ok ? AppTheme.present : AppTheme.danger)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _ok ? Icons.check_circle : Icons.error_outline,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_probeResult!)),
                    ],
                  ),
                ),
              ],
              const Divider(height: 48),
              Text(l.language, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'en', label: Text(l.english)),
                  ButtonSegment(value: 'ar', label: Text(l.arabic)),
                ],
                selected: {settings.locale.languageCode},
                onSelectionChanged: (sel) =>
                    settings.setLocale(Locale(sel.first)),
              ),
              const SizedBox(height: 28),
              Text(
                l.appearance,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: const Icon(Icons.brightness_auto, size: 18),
                    label: Text(l.themeSystem),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: const Icon(Icons.light_mode_outlined, size: 18),
                    label: Text(l.themeLight),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: const Icon(Icons.dark_mode_outlined, size: 18),
                    label: Text(l.themeDark),
                  ),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (sel) => settings.setThemeMode(sel.first),
              ),
              if (!widget.firstRun) ...[
                const SizedBox(height: 28),
                Text(
                  l.appPassword,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  settings.hasPassword ? l.appPasswordHint : l.appPasswordOff,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (!settings.hasPassword)
                      FilledButton.tonalIcon(
                        onPressed: () => _password(PasswordAction.set),
                        icon: const Icon(Icons.lock_outline),
                        label: Text(l.setPassword),
                      )
                    else ...[
                      FilledButton.tonalIcon(
                        onPressed: () => _password(PasswordAction.change),
                        icon: const Icon(Icons.key_outlined),
                        label: Text(l.changePassword),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _password(PasswordAction.remove),
                        icon: const Icon(Icons.lock_open_outlined),
                        label: Text(l.removePassword),
                      ),
                    ],
                  ],
                ),
                const Divider(height: 56),
                Text(
                  l.resetApp,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: AppTheme.danger),
                ),
                const SizedBox(height: 4),
                Text(
                  l.resetAppHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _resetApp,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                    side: const BorderSide(color: AppTheme.danger),
                  ),
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: Text(l.resetApp),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    // On first run this is embedded in the shell's own Scaffold.
    if (widget.firstRun) return body;

    return Scaffold(
      appBar: AppBar(title: Text(l.navSettings)),
      body: body,
    );
  }
}
