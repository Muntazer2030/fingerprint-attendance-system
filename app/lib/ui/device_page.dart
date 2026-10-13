import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/device_strings.dart';
import '../data/models.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import 'shell.dart';
import 'telegram_page.dart';
import 'theme.dart';
import 'wifi_page.dart';

/// Full control of the terminal from the app. Everything here is stored on the
/// device in NVS and survives a reflash, so the operator never needs the
/// toolchain to change how it behaves.
class DevicePage extends StatefulWidget {
  const DevicePage({super.key, required this.api});

  final ApiClient api;

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  DeviceConfig? _draft;
  bool _saving = false;
  bool _pushing = false;
  int _pushDone = 0;
  String? _notice;

  Future<DeviceConfig> _load() async {
    final c = await widget.api.config();
    _draft ??= c;
    return _draft!;
  }

  void _edit(DeviceConfig Function(DeviceConfig) f) {
    setState(() {
      _draft = f(_draft!);
    });
  }

  Future<void> _apply() async {
    setState(() => _saving = true);
    try {
      final saved = await widget.api.setConfig(_draft!);
      if (!mounted) return;
      final l = AppLocalizations.of(context)!;
      setState(() {
        _draft = saved;
        _notice = l.saved;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _notice = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Renders every device phrase in the selected language and uploads it.
  /// Must be re-run after switching language, since the device stores rasters
  /// rather than text.
  Future<void> _pushStrings() async {
    final l = AppLocalizations.of(context)!;
    setState(() {
      _pushing = true;
      _pushDone = 0;
      _notice = null;
    });
    try {
      await DeviceStrings.pushAll(
        widget.api,
        _draft!.language,
        onProgress: (done, total) {
          if (mounted) setState(() => _pushDone = done);
        },
      );
      if (mounted) setState(() => _notice = l.stringsSent);
    } catch (e) {
      if (mounted) {
        setState(() {
          _notice = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _pushing = false);
    }
  }

  Future<void> _clear(String scope, VoidCallback refresh) async {
    final l = AppLocalizations.of(context)!;
    try {
      // Pull everything first. Clearing the terminal's log throws away any
      // punch not yet copied here; the description promises synced records
      // are kept, so make sure that is all of them.
      if (scope == 'events' || scope == 'all') {
        final sync = AppScope.syncOf(context);
        await sync.pull(widget.api);
        if (sync.lastError != null) throw sync.lastError!;
      }
      await widget.api.resetDevice(scope);
      if (!mounted) return;
      // Config may have gone back to defaults, so drop the local draft and
      // re-read rather than showing stale values.
      setState(() {
        _draft = null;
        _notice = l.clearedOk;
      });
      refresh();
    } catch (e) {
      if (mounted) {
        setState(() {
          _notice = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return AsyncPage<DeviceConfig>(
      title: l.deviceSettings,
      load: _load,
      builder: (context, loaded, refresh) {
        // Render the draft, not the snapshot. AsyncPage keeps its own
        // FutureBuilder, so a setState here re-runs its builder with the
        // *cached* value from load time -- every control appeared frozen
        // because edits went into _draft while the UI kept reading the
        // original fetch.
        final c = _draft ?? loaded;
        final scheme = Theme.of(context).colorScheme;

        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
              children: [
                CappedWidth(
                  maxWidth: 560,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_notice != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(_notice!),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // --- what a scan records ---
                      // The firmware has supported this all along; the app
                      // had no control for it, so a terminal could not be
                      // switched between CHECK IN and CHECK OUT without a
                      // reflash or the touch button.
                      _section(context, l.terminalMode),
                      SegmentedButton<String>(
                        segments: [
                          ButtonSegment(
                            value: 'in',
                            icon: const Icon(Icons.login),
                            label: Text(l.modeCheckIn),
                          ),
                          ButtonSegment(
                            value: 'out',
                            icon: const Icon(Icons.logout),
                            label: Text(l.modeCheckOut),
                          ),
                          ButtonSegment(
                            value: 'auto',
                            icon: const Icon(Icons.swap_horiz),
                            label: Text(l.modeAuto),
                          ),
                        ],
                        selected: {
                          c.directionAuto
                              ? 'auto'
                              : (c.directionOut ? 'out' : 'in'),
                        },
                        onSelectionChanged: (s) => _edit(
                          (d) => d.copyWith(
                            directionAuto: s.first == 'auto',
                            directionOut: s.first == 'out',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        c.directionAuto ? l.modeAutoHelp : l.modeFixedHelp,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),

                      // --- language and text ---
                      _section(context, l.displayLanguage),
                      SegmentedButton<String>(
                        segments: [
                          ButtonSegment(value: 'en', label: Text(l.english)),
                          ButtonSegment(value: 'ar', label: Text(l.arabic)),
                        ],
                        selected: {c.language},
                        onSelectionChanged: (s) =>
                            _edit((d) => d.copyWith(language: s.first)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l.pushStringsHelp,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: _pushing ? null : _pushStrings,
                            icon: const Icon(Icons.translate),
                            label: Text(
                              _pushing
                                  ? '${l.pushing} $_pushDone/${DeviceStrings.count}'
                                  : l.pushStrings,
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (!c.hasStrings)
                            Expanded(
                              child: Text(
                                l.stringsMissing,
                                style: TextStyle(color: scheme.error),
                              ),
                            ),
                        ],
                      ),
                      if (_pushing) ...[
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: _pushDone / DeviceStrings.count,
                        ),
                      ],

                      // --- clock ---
                      _section(context, l.clockFormat),
                      SegmentedButton<bool>(
                        segments: [
                          ButtonSegment(value: false, label: Text(l.hour24)),
                          ButtonSegment(value: true, label: Text(l.hour12)),
                        ],
                        selected: {c.time12h},
                        onSelectionChanged: (s) =>
                            _edit((d) => d.copyWith(time12h: s.first)),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l.showSeconds),
                        value: c.showSeconds,
                        onChanged: (v) =>
                            _edit((d) => d.copyWith(showSeconds: v)),
                      ),
                      _slider(
                        context,
                        label: l.timezoneOffset,
                        value: c.tzOffsetMin / 60,
                        min: -12,
                        max: 14,
                        divisions: 26,
                        display: _offsetLabel(c.tzOffsetMin),
                        onChanged: (v) => _edit(
                          (d) => d.copyWith(tzOffsetMin: (v * 60).round()),
                        ),
                      ),

                      // --- screen ---
                      _section(context, l.brightness),
                      _slider(
                        context,
                        label: l.brightness,
                        value: c.brightness.toDouble(),
                        min: 1,
                        max: 255,
                        divisions: 254,
                        display: '${(c.brightness / 255 * 100).round()}%',
                        onChanged: (v) =>
                            _edit((d) => d.copyWith(brightness: v.round())),
                      ),
                      _slider(
                        context,
                        label: l.dimAfter,
                        value: c.idleDimSeconds.toDouble(),
                        min: 0,
                        max: 300,
                        divisions: 30,
                        display: _secondsLabel(l, c.idleDimSeconds),
                        onChanged: (v) =>
                            _edit((d) => d.copyWith(idleDimSeconds: v.round())),
                      ),
                      _slider(
                        context,
                        label: l.blankAfter,
                        value: c.idleOffSeconds.toDouble(),
                        min: 0,
                        max: 900,
                        divisions: 30,
                        display: _secondsLabel(l, c.idleOffSeconds),
                        onChanged: (v) =>
                            _edit((d) => d.copyWith(idleOffSeconds: v.round())),
                      ),
                      if (c.burnInRisk)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber,
                                size: 18,
                                color: scheme.error,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l.burnInWarning,
                                  style: TextStyle(color: scheme.error),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // --- behaviour ---
                      _section(context, l.navDevice),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l.buzzerSound),
                        value: c.buzzer,
                        onChanged: (v) => _edit((d) => d.copyWith(buzzer: v)),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l.touchButtonWired),
                        subtitle: Text(l.touchButtonHelp),
                        value: c.useTouchButton,
                        onChanged: (v) =>
                            _edit((d) => d.copyWith(useTouchButton: v)),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l.fingerDetectWire),
                        subtitle: Text(l.fingerDetectHelp),
                        value: c.useFingerDetect,
                        onChanged: (v) =>
                            _edit((d) => d.copyWith(useFingerDetect: v)),
                      ),
                      _slider(
                        context,
                        label: l.duplicateWindow,
                        value: c.dupWindowSeconds.toDouble(),
                        min: 0,
                        max: 600,
                        divisions: 30,
                        display: _secondsLabel(l, c.dupWindowSeconds),
                        onChanged: (v) => _edit(
                          (d) => d.copyWith(dupWindowSeconds: v.round()),
                        ),
                      ),

                      // --- wifi fallback ---
                      _section(context, l.wifiTitle),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.wifi),
                          title: Text(l.wifiTitle),
                          subtitle: Text(l.wifiTileHelp),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => WifiPage(api: widget.api),
                            ),
                          ),
                        ),
                      ),

                      // --- telegram ---
                      _section(context, l.tgTitle),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.send_outlined),
                          title: Text(l.tgTitle),
                          subtitle: Text(l.tgTileHelp),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => TelegramPage(api: widget.api),
                            ),
                          ),
                        ),
                      ),

                      // --- destructive actions ---
                      _section(context, l.dangerZone),
                      _ClearTile(
                        title: l.clearEvents,
                        help: l.clearEventsHelp,
                        icon: Icons.delete_sweep_outlined,
                        onConfirmed: () => _clear('events', refresh),
                      ),
                      _ClearTile(
                        title: l.clearFingerprints,
                        help: l.clearFingerprintsHelp,
                        icon: Icons.fingerprint,
                        onConfirmed: () => _clear('fingerprints', refresh),
                      ),
                      _ClearTile(
                        title: l.clearConfig,
                        help: l.clearConfigHelp,
                        icon: Icons.settings_backup_restore,
                        onConfirmed: () => _clear('config', refresh),
                      ),
                      _ClearTile(
                        title: l.clearAll,
                        help: '${l.clearEventsHelp} ${l.clearFingerprintsHelp}',
                        icon: Icons.warning_amber,
                        destructive: true,
                        onConfirmed: () => _clear('all', refresh),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              right: 24,
              bottom: 24,
              child: FloatingActionButton.extended(
                onPressed: _saving ? null : _apply,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(l.applyToDevice),
              ),
            ),
          ],
        );
      },
    );
  }

  static Widget _section(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(top: 28, bottom: 10),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );

  static Widget _slider(
    BuildContext context, {
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String display,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(display, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }

  static String _offsetLabel(int minutes) {
    final sign = minutes < 0 ? '-' : '+';
    final abs = minutes.abs();
    return 'UTC$sign${(abs ~/ 60).toString().padLeft(2, '0')}:'
        '${(abs % 60).toString().padLeft(2, '0')}';
  }

  static String _secondsLabel(AppLocalizations l, int seconds) {
    if (seconds == 0) return l.never;
    if (seconds < 60) return '$seconds ${l.seconds}';
    return '${(seconds / 60).round()} ${l.minutes}';
  }
}

/// A destructive action behind a typed confirmation. A plain yes/no dialog is
/// too easy to click through when the button erases every enrolled fingerprint.
class _ClearTile extends StatelessWidget {
  const _ClearTile({
    required this.title,
    required this.help,
    required this.icon,
    required this.onConfirmed,
    this.destructive = false,
  });

  final String title;
  final String help;
  final IconData icon;
  final Future<void> Function() onConfirmed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final tint = destructive ? scheme.error : scheme.onSurfaceVariant;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: tint),
        title: Text(title, style: TextStyle(color: tint)),
        subtitle: Text(help, style: Theme.of(context).textTheme.bodySmall),
        trailing: OutlinedButton(
          onPressed: () => _confirm(context, l),
          style: OutlinedButton.styleFrom(foregroundColor: tint),
          child: Text(l.delete),
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context, AppLocalizations l) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final matches =
              controller.text.trim().toUpperCase() == l.typeToConfirm;
          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(help),
                const SizedBox(height: 16),
                Text(
                  l.confirmClear,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: l.typeToConfirm,
                  ),
                  onChanged: (_) => setLocal(() {}),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: matches ? () => Navigator.pop(ctx, true) : null,
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                ),
                child: Text(l.delete),
              ),
            ],
          );
        },
      ),
    );

    if (ok == true) await onConfirmed();
  }
}
