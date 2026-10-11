import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../data/sync_service.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import 'names.dart';
import 'theme.dart';

/// Every punch on record, with the tools to fix mistakes.
///
/// Reads the local database, not the terminal. The database is the system of
/// record: it has names, manual punches, corrections, and history the
/// terminal reclaimed long ago. The old page asked the terminal for its last
/// 200 events, so it went blank when offline and could never show a manual
/// punch -- and there was no way to enter or correct one anywhere in the app.
class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _Data {
  _Data(this.rows, this.names, this.employees);
  final List<PunchRow> rows;
  final NameBook names;
  final List<EmployeeRow> employees;
}

class _EventsPageState extends State<EventsPage> {
  Future<_Data>? _future;
  SyncService? _sync;
  int _seenRevision = -1;

  int? _employee; // null = everyone
  DateTime? _day; // null = most recent

  static const _limit = 500;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sync = AppScope.syncOf(context);
    if (!identical(sync, _sync)) {
      _sync?.removeListener(_onSync);
      _sync = sync..addListener(_onSync);
      _seenRevision = sync.revision;
    }
    _future ??= _load();
  }

  @override
  void dispose() {
    _sync?.removeListener(_onSync);
    super.dispose();
  }

  void _onSync() {
    if (!mounted) return;
    final rev = _sync!.revision;
    if (rev != _seenRevision) {
      _seenRevision = rev;
      _refresh();
    } else {
      setState(() {}); // busy indicator
    }
  }

  Future<_Data> _load() async {
    final db = AppScope.dbOf(context);
    int? from, to;
    if (_day != null) {
      final d = DateTime(_day!.year, _day!.month, _day!.day);
      from = d.toUtc().millisecondsSinceEpoch ~/ 1000;
      to =
          DateTime(d.year, d.month, d.day + 1).toUtc().millisecondsSinceEpoch ~/
              1000 -
          1;
    }
    final rows = await db.recentPunches(
      limit: _limit,
      employeeId: _employee,
      fromEpoch: from,
      toEpoch: to,
    );
    final employees = await db.allEmployees();
    return _Data(rows, NameBook(employees), employees);
  }

  void _refresh() => setState(() {
    _future = _load();
  });

  static DateTime _when(PunchRow r) => DateTime.fromMillisecondsSinceEpoch(
    (r.correctedEpoch ?? r.deviceEpoch) * 1000,
    isUtc: true,
  ).toLocal();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final sync = AppScope.syncOf(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.navEvents),
        actions: [
          IconButton(
            tooltip: l.syncNow,
            onPressed: sync.busy ? null : sync.pull,
            icon: sync.busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final data = await _future;
          if (data != null && mounted) _addManual(data);
        },
        icon: const Icon(Icons.more_time),
        label: Text(l.addPunch),
      ),
      body: FutureBuilder<_Data>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return snap.hasError
                ? Center(child: Text(snap.error.toString()))
                : const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!;

          final groups = <DateTime, List<PunchRow>>{};
          for (final r in data.rows) {
            final t = _when(r);
            groups
                .putIfAbsent(DateTime(t.year, t.month, t.day), () => [])
                .add(r);
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
            children: [
              _filters(context, data),
              const SizedBox(height: 8),
              if (data.rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: Text(l.noEvents)),
                ),
              for (final entry in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Text(
                    DateFormat.yMMMMEEEEd(locale).format(entry.key),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Card(
                  child: Column(
                    children: [
                      for (final r in entry.value)
                        _PunchTile(
                          row: r,
                          name: data.names.label(context, r.employeeId),
                          onTap: () => _openPunch(r, data),
                        ),
                    ],
                  ),
                ),
              ],
              if (data.rows.length == _limit)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l.showingLatest(_limit),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _filters(BuildContext context, _Data data) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final people = [...data.employees]
      ..sort(
        (a, b) => data.names
            .label(context, a.id)
            .compareTo(data.names.label(context, b.id)),
      );

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 240,
          child: DropdownButtonFormField<int?>(
            // Keyed so "clear filters" resets it; a form field otherwise keeps
            // its own copy of the value and ignores the new initialValue.
            key: ValueKey(_employee),
            initialValue: _employee,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.employee, isDense: true),
            items: [
              DropdownMenuItem(value: null, child: Text(l.allEmployees)),
              for (final e in people)
                DropdownMenuItem(
                  value: e.id,
                  child: Text(data.names.label(context, e.id)),
                ),
            ],
            onChanged: (v) {
              _employee = v;
              _refresh();
            },
          ),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today, size: 18),
          label: Text(
            _day == null ? l.anyDate : DateFormat.yMMMd(locale).format(_day!),
          ),
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _day ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 1)),
            );
            if (picked == null) return;
            _day = picked;
            _refresh();
          },
        ),
        if (_day != null || _employee != null)
          TextButton.icon(
            icon: const Icon(Icons.clear, size: 18),
            label: Text(l.clearFilters),
            onPressed: () {
              _day = null;
              _employee = null;
              _refresh();
            },
          ),
      ],
    );
  }

  Future<void> _addManual(_Data data) async {
    final l = AppLocalizations.of(context)!;
    final active = data.employees.where((e) => !e.removed).toList();
    if (active.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.noEmployees)));
      return;
    }
    final result = await showDialog<_ManualPunch>(
      context: context,
      builder: (_) => _ManualPunchDialog(
        employees: active,
        names: data.names,
        initialEmployee: _employee,
        initialDay: _day,
      ),
    );
    if (result == null || !mounted) return;
    await AppScope.syncOf(context).addManualPunch(
      employeeId: result.employeeId,
      at: result.at,
      isOut: result.isOut,
      reason: result.reason,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l.punchAdded)));
  }

  Future<void> _openPunch(PunchRow r, _Data data) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _PunchDialog(
        row: r,
        name: data.names.label(context, r.employeeId),
        sync: AppScope.syncOf(context),
      ),
    );
  }
}

class _PunchTile extends StatelessWidget {
  const _PunchTile({
    required this.row,
    required this.name,
    required this.onTap,
  });

  final PunchRow row;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final isIn = row.direction == 0;
    final t = _EventsPageState._when(row);
    final manual = row.method == 1;
    final corrected = row.correctedEpoch != null;
    final provisional = row.provisionalTime && !corrected;

    return ListTile(
      dense: true,
      onTap: onTap,
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
        '${_two(t.hour)}:${_two(t.minute)}  ·  '
        '${isIn ? l.directionIn : l.directionOut}',
      ),
      trailing: Wrap(
        spacing: 6,
        children: [
          if (manual) _Badge(l.methodManual, scheme.tertiary),
          if (corrected) _Badge(l.corrected, AppTheme.warning),
          if (provisional)
            Tooltip(
              message: l.provisionalTime,
              child: Icon(
                Icons.help_outline,
                size: 18,
                color: AppTheme.warning,
              ),
            ),
        ],
      ),
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11.5,
        color: color,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _ManualPunch {
  _ManualPunch(this.employeeId, this.at, this.isOut, this.reason);
  final int employeeId;
  final DateTime at;
  final bool isOut;
  final String reason;
}

/// Picks a date and time together, with the pickers the platform provides.
class _DateTimeField extends StatelessWidget {
  const _DateTimeField({required this.value, required this.onChanged});
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(DateFormat.yMMMd(locale).format(value)),
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: value,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (d != null) {
                onChanged(
                  DateTime(d.year, d.month, d.day, value.hour, value.minute),
                );
              }
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.schedule, size: 18),
            label: Text(DateFormat.Hm(locale).format(value)),
            onPressed: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(value),
              );
              if (t != null) {
                onChanged(
                  DateTime(
                    value.year,
                    value.month,
                    value.day,
                    t.hour,
                    t.minute,
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }
}

class _ManualPunchDialog extends StatefulWidget {
  const _ManualPunchDialog({
    required this.employees,
    required this.names,
    this.initialEmployee,
    this.initialDay,
  });

  final List<EmployeeRow> employees;
  final NameBook names;
  final int? initialEmployee;
  final DateTime? initialDay;

  @override
  State<_ManualPunchDialog> createState() => _ManualPunchDialogState();
}

class _ManualPunchDialogState extends State<_ManualPunchDialog> {
  int? _employee;
  bool _isOut = false;
  late DateTime _at;
  final _reason = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    final ids = widget.employees.map((e) => e.id).toSet();
    _employee = ids.contains(widget.initialEmployee)
        ? widget.initialEmployee
        : widget.employees.first.id;
    final now = DateTime.now();
    final d = widget.initialDay ?? now;
    _at = DateTime(d.year, d.month, d.day, now.hour, now.minute);
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    final l = AppLocalizations.of(context)!;
    if (_reason.text.trim().isEmpty) {
      setState(() => _error = l.reasonRequired);
      return;
    }
    if (_at.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      setState(() => _error = l.futureNotAllowed);
      return;
    }
    Navigator.pop(
      context,
      _ManualPunch(_employee!, _at, _isOut, _reason.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l.addPunch),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.manualPunchHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _employee,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.employee),
              items: [
                for (final e in widget.employees)
                  DropdownMenuItem(
                    value: e.id,
                    child: Text(widget.names.label(context, e.id)),
                  ),
              ],
              onChanged: (v) => setState(() => _employee = v),
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.login),
                  label: Text(l.directionIn),
                ),
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.logout),
                  label: Text(l.directionOut),
                ),
              ],
              selected: {_isOut},
              onSelectionChanged: (s) => setState(() => _isOut = s.first),
            ),
            const SizedBox(height: 16),
            _DateTimeField(
              value: _at,
              onChanged: (v) => setState(() => _at = v),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reason,
              decoration: InputDecoration(
                labelText: l.reason,
                hintText: l.reasonHint,
                errorText: _error,
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l.add)),
      ],
    );
  }
}

/// Details of one punch, and the corrections allowed on it.
///
/// A device punch is evidence: its recorded time is kept forever and only a
/// correction is layered on top. A manual punch was typed in, so it can be
/// deleted outright. Every change asks for a reason, which goes to the audit
/// log.
class _PunchDialog extends StatefulWidget {
  const _PunchDialog({
    required this.row,
    required this.name,
    required this.sync,
  });
  final PunchRow row;
  final String name;
  final SyncService sync;

  @override
  State<_PunchDialog> createState() => _PunchDialogState();
}

class _PunchDialogState extends State<_PunchDialog> {
  late DateTime _at = _EventsPageState._when(widget.row);
  final _reason = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool _needReason() {
    if (_reason.text.trim().isNotEmpty) return true;
    setState(() => _error = AppLocalizations.of(context)!.reasonRequired);
    return false;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (!_needReason()) return;
    setState(() => _busy = true);
    await action();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final r = widget.row;
    final recorded = DateTime.fromMillisecondsSinceEpoch(
      r.deviceEpoch * 1000,
      isUtc: true,
    ).toLocal();
    final manual = r.method == 1;
    final corrected = r.correctedEpoch != null;
    final fmt = DateFormat.yMMMd(locale).add_Hm();

    return AlertDialog(
      title: Text(widget.name),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kv(
              context,
              l.direction,
              r.direction == 0 ? l.directionIn : l.directionOut,
            ),
            _kv(context, l.method, manual ? l.methodManual : l.methodFinger),
            _kv(context, l.recordedTime, fmt.format(recorded)),
            if (corrected)
              _kv(context, l.corrected, fmt.format(_EventsPageState._when(r))),
            if (r.provisionalTime && !corrected)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l.provisionalExplained,
                  style: TextStyle(color: AppTheme.warning),
                ),
              ),
            const Divider(height: 28),
            Text(
              manual ? l.changeTime : l.correctTime,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 10),
            _DateTimeField(
              value: _at,
              onChanged: (v) => setState(() => _at = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              decoration: InputDecoration(
                labelText: l.reason,
                hintText: l.reasonHint,
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (manual)
          TextButton(
            onPressed: _busy
                ? null
                : () => _run(
                    () => widget.sync.deleteManualPunch(
                      r.seq,
                      reason: _reason.text.trim(),
                    ),
                  ),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: Text(l.delete),
          )
        else if (corrected)
          TextButton(
            onPressed: _busy
                ? null
                : () => _run(
                    () => widget.sync.correctPunch(
                      seq: r.seq,
                      at: null,
                      reason: _reason.text.trim(),
                    ),
                  ),
            child: Text(l.removeCorrection),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: _busy
              ? null
              : () => _run(
                  () => widget.sync.correctPunch(
                    seq: r.seq,
                    at: _at,
                    reason: _reason.text.trim(),
                  ),
                ),
          child: Text(l.save),
        ),
      ],
    );
  }

  static Widget _kv(BuildContext context, String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(k, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(child: Text(v)),
      ],
    ),
  );
}
