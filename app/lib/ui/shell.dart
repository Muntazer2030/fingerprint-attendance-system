import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import 'connecting_page.dart';
import 'dashboard_page.dart';
import 'device_page.dart';
import 'employees_page.dart';
import 'events_page.dart';
import 'lock_page.dart';
import 'payroll_page.dart';
import 'settings_page.dart';
import 'timesheet_page.dart';
import 'theme.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  bool _syncStarted = false;

  // One client per connection. A fresh ApiClient per build leaked an open
  // http.Client every time settings notified, and gave each page a new object
  // so nothing could tell whether the connection had actually changed.
  ApiClient? _api;
  String _apiKey = '';

  ApiClient _clientFor(String host, String token) {
    final key = '$host|$token';
    if (_api == null || key != _apiKey) {
      _api?.close();
      _api = ApiClient(host: host, token: token);
      _apiKey = key;
    }
    return _api!;
  }

  @override
  void dispose() {
    _api?.close();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = AppScope.settingsOf(context);
    if (!settings.isConfigured) {
      // After "Reset app" (which stops syncing) the next connection must
      // start it again, and open on the dashboard rather than Settings.
      _syncStarted = false;
      _index = 0;
      return;
    }
    if (_syncStarted) return;
    _syncStarted = true;

    // Pull punches into the local database on a timer. The service commits
    // locally before acking, so an interrupted round just replays next time,
    // and it rediscovers the device by itself if DHCP moved it.
    AppScope.syncOf(context).startPeriodic();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final settings = AppScope.settingsOf(context);

    // Syncing carries on underneath; only the screens are withheld.
    if (settings.locked) return const LockPage();

    // Nothing works without an address and token. Rather than presenting an
    // empty form, go and find the device -- its address changes on nearly
    // every boot, so typing it in is the wrong default.
    if (!settings.isConfigured) {
      return const ConnectingPage();
    }

    final api = _clientFor(settings.host, settings.token);

    final pages = <Widget>[
      DashboardPage(api: api),
      EmployeesPage(api: api),
      const EventsPage(),
      const TimesheetPage(),
      const PayrollPage(),
      DevicePage(api: api),
      const SettingsPage(),
    ];

    final destinations = [
      (Icons.dashboard_outlined, Icons.dashboard, l.navDashboard),
      (Icons.people_outline, Icons.people, l.navEmployees),
      (Icons.list_alt_outlined, Icons.list_alt, l.navEvents),
      (Icons.table_chart_outlined, Icons.table_chart, l.navTimesheet),
      (Icons.payments_outlined, Icons.payments, l.navPayroll),
      (Icons.memory_outlined, Icons.memory, l.navDevice),
      (Icons.settings_outlined, Icons.settings, l.navSettings),
    ];

    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            index: _index,
            destinations: destinations,
            onSelected: (i) => setState(() => _index = i),
            onOpenSettings: () => setState(() => _index = pages.length - 1),
          ),
          const VerticalDivider(width: 1),
          // Keyed by connection so a page holding state for the old device
          // (an edited config draft, say) starts clean for the new one.
          Expanded(
            child: KeyedSubtree(
              key: ValueKey(
                _index == pages.length - 1
                    ? 'settings' // keeps its "connected" result on screen
                    : '$_index|$_apiKey',
              ),
              // A messenger per page. Without it every snackbar went to the
              // outermost Scaffold: it spread under the sidebar, hid the
              // connection status, and covered the page's own buttons (the
              // page Scaffold never moved its FAB clear, so "Add employee"
              // could not be clicked for four seconds after each save).
              child: ScaffoldMessenger(child: pages[_index]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Branded rail with a live connection indicator pinned to the bottom, so the
/// state of the link is visible from every page rather than only the dashboard.
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.index,
    required this.destinations,
    required this.onSelected,
    required this.onOpenSettings,
  });

  final int index;
  final List<(IconData, IconData, String)> destinations;
  final ValueChanged<int> onSelected;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final sync = AppScope.syncOf(context);
    final settings = AppScope.settingsOf(context);

    return Container(
      width: 208,
      color: scheme.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Icons.fingerprint,
                    size: 19,
                    color: scheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    l.appTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (settings.hasPassword)
                  IconButton(
                    tooltip: l.lockApp,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.lock_outline, size: 18),
                    onPressed: settings.lock,
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                for (var i = 0; i < destinations.length; i++)
                  _NavItem(
                    icon: destinations[i].$1,
                    activeIcon: destinations[i].$2,
                    label: destinations[i].$3,
                    selected: i == index,
                    onTap: () => onSelected(i),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: AnimatedBuilder(
              animation: sync,
              builder: (context, _) {
                if (sync.relocating) {
                  return StatusPill(
                    label: l.searching,
                    color: AppTheme.warning,
                    icon: Icons.radar,
                  );
                }
                if (sync.busy) {
                  return StatusPill(
                    label: l.syncing,
                    color: scheme.primary,
                    icon: Icons.sync,
                  );
                }
                final err = sync.lastError;
                if (err != null) {
                  final auth = err is ApiException && err.isAuthFailure;
                  // Say why, and offer the one thing that fixes it. A bare
                  // "Not connected" left no way to tell a dead device from a
                  // wrong token.
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Tooltip(
                        message: err.toString(),
                        child: StatusPill(
                          label: auth ? l.tokenRejectedShort : l.disconnected,
                          color: AppTheme.danger,
                          icon: auth ? Icons.key_off : Icons.cloud_off,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              settings.host,
                              style: Theme.of(context).textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (auth)
                            IconButton(
                              tooltip: l.navSettings,
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.settings, size: 18),
                              onPressed: onOpenSettings,
                            )
                          else
                            IconButton(
                              tooltip: l.retry,
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.refresh, size: 18),
                              onPressed: sync.pull,
                            ),
                        ],
                      ),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusPill(label: l.connected, color: AppTheme.present),
                    const SizedBox(height: 8),
                    Text(
                      settings.host,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (sync.lastSync != null)
                      Text(
                        '${l.lastSync} ${_hhmm(sync.lastSync!)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.primary : scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(selected ? activeIcon : icon, size: 19, color: fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared scaffolding for a page that loads once and can be refreshed.
class AsyncPage<T> extends StatefulWidget {
  const AsyncPage({
    super.key,
    required this.title,
    required this.load,
    required this.builder,
    this.actions = const [],
    this.autoRefresh,
  });

  final String title;
  final Future<T> Function() load;
  final Widget Function(BuildContext, T, VoidCallback refresh) builder;
  final List<Widget> actions;
  final Duration? autoRefresh;

  @override
  State<AsyncPage<T>> createState() => _AsyncPageState<T>();
}

class _AsyncPageState<T> extends State<AsyncPage<T>> {
  late Future<T> _future;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
    if (widget.autoRefresh != null) _scheduleRefresh();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _scheduleRefresh() {
    Future.delayed(widget.autoRefresh!, () {
      if (_disposed) return;
      _refresh();
      _scheduleRefresh();
    });
  }

  void _refresh() {
    if (_disposed) return;
    setState(() {
      _future = widget.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          ...widget.actions,
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: l.refresh,
          ),
        ],
      ),
      body: FutureBuilder<T>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorView(error: snap.error!, onRetry: _refresh);
          }
          return widget.builder(context, snap.data as T, _refresh);
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final isAuth =
        error is ApiException && (error as ApiException).isAuthFailure;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 48, color: scheme.error),
              const SizedBox(height: 16),
              Text(
                l.connectionFailed,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                isAuth ? error.toString() : l.checkAddressAndToken,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(l.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
