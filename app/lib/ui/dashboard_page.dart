import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/database.dart';
import '../data/models.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import 'names.dart';
import 'shell.dart';
import 'theme.dart';

class _Overview {
  _Overview(this.info, this.health, this.employees, this.recent, this.names);
  final DeviceInfo info;
  final Health health;
  final List<Employee> employees;
  final List<PunchEvent> recent;
  final NameBook names;
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.api});

  final ApiClient api;

  Future<_Overview> _load(AppDatabase db) async {
    final info = await api.info();
    final health = await api.health();
    final employees = await api.employees();
    // Tail of the log: ask for everything after (head - 20).
    final from = (info.events.head - 20).clamp(0, info.events.head);
    final recent = await api.events(since: from, limit: 20);
    return _Overview(
      info,
      health,
      employees,
      recent.reversed.toList(),
      await NameBook.load(db),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final db = AppScope.dbOf(context);

    return AsyncPage<_Overview>(
      title: l.navDashboard,
      load: () => _load(db),
      autoRefresh: const Duration(seconds: 10),
      builder: (context, d, refresh) {
        final present = d.employees.where((e) => e.isPresent).length;
        final degrading = d.employees.where((e) => e.failCount >= 3).toList();

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (d.info.events.overflow)
              _Banner(
                icon: Icons.warning_amber,
                text: l.bufferFull,
                tone: AppTheme.danger.withValues(alpha: 0.14),
              ),
            if (!d.info.timeSynced)
              _Banner(
                icon: Icons.schedule,
                text: '${l.clock}: ${_clockLabel(l, d.info.timeSource)}',
                tone: AppTheme.warning.withValues(alpha: 0.16),
                action: TextButton(
                  onPressed: () async {
                    try {
                      await api.syncClock();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.toString()),
                            backgroundColor: AppTheme.danger,
                          ),
                        );
                      }
                    }
                    refresh();
                  },
                  child: Text(l.syncClock),
                ),
              ),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _Stat(
                  label: l.statusOnline,
                  value: '$present / ${d.employees.length}',
                  icon: Icons.how_to_reg,
                ),
                _Stat(
                  label: l.eventsStored,
                  value: '${d.info.events.head}',
                  icon: Icons.inventory_2_outlined,
                ),
                _Stat(
                  label: l.eventsPending,
                  value: '${d.info.events.pending}',
                  icon: Icons.sync,
                  // Pending only matters relative to the ring size; show the
                  // proportion consumed so a stalled sync is visible early.
                  caption:
                      '${(d.info.events.fillRatio * 100).toStringAsFixed(1)}% '
                      '${l.ofTotal} ${d.info.events.capacity}',
                ),
                _Stat(
                  label: l.freeMemory,
                  value: '${(d.health.heapFree / 1024).round()} KB',
                  icon: Icons.memory,
                  caption:
                      '${l.lowest} ${(d.health.heapMin / 1024).round()} KB',
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (degrading.isNotEmpty) ...[
              Text(
                l.failedReads,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    for (final e in degrading)
                      ListTile(
                        leading: const Icon(Icons.fingerprint),
                        title: Text(d.names.label(context, e.id)),
                        trailing: Chip(label: Text('${e.failCount}')),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            Text(l.navEvents, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: d.recent.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: Text(l.noEvents)),
                    )
                  : Column(
                      children: [
                        for (final e in d.recent)
                          EventTile(
                            event: e,
                            name: d.names.label(context, e.employeeId),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: DefaultTextStyle(
                  style: Theme.of(context).textTheme.bodySmall!,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kv(l.board, '${d.info.board} / ${d.info.eth}'),
                      _kv(l.firmware, '${d.info.firmware} (${d.info.idf})'),
                      _kv(l.uptime, _uptime(l, d.info.uptimeSeconds)),
                      _kv(l.clock, _clockLabel(l, d.info.timeSource)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        SizedBox(width: 140, child: Text(k)),
        Expanded(child: Text(v)),
      ],
    ),
  );

  static String _uptime(AppLocalizations l, int seconds) {
    final d = Duration(seconds: seconds);
    if (d.inDays > 0) {
      return '${d.inDays}${l.daysAbbr} ${d.inHours % 24}${l.hoursAbbr}';
    }
    if (d.inHours > 0) {
      return '${d.inHours}${l.hoursAbbr} ${d.inMinutes % 60}${l.minutesAbbr}';
    }
    return '${d.inMinutes}${l.minutesAbbr}';
  }

  static String _clockLabel(AppLocalizations l, String source) =>
      switch (source) {
        'ntp' => l.clockSourceNtp,
        'pc' => l.clockSourcePc,
        'restored' => l.clockSourceRestored,
        _ => l.clockUnset,
      };
}

class EventTile extends StatelessWidget {
  const EventTile({super.key, required this.event, required this.name});

  final PunchEvent event;
  final String name;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isIn = event.direction == PunchDirection.inbound;
    final scheme = Theme.of(context).colorScheme;
    final t = event.timestamp;

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        backgroundColor: (isIn ? AppTheme.present : AppTheme.absent).withValues(
          alpha: 0.15,
        ),
        child: Icon(
          isIn ? Icons.login : Icons.logout,
          size: 18,
          color: isIn ? AppTheme.present : AppTheme.absent,
        ),
      ),
      title: Text(name),
      subtitle: Text(
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}  ·  '
        '${isIn ? l.directionIn : l.directionOut}'
        '${event.manual ? '  ·  ${l.methodManual}' : ''}',
      ),
      trailing: event.provisionalTime
          ? Tooltip(
              message: l.provisionalTime,
              child: Icon(Icons.help_outline, size: 18, color: scheme.tertiary),
            )
          : Text('#${event.seq}', style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
    this.caption,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
              if (caption != null)
                Text(caption!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.text,
    required this.tone,
    this.action,
  });

  final IconData icon;
  final String text;
  final Color tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
          if (action != null) action!,
        ],
      ),
    );
  }
}
