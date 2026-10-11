import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import 'theme.dart';

/// Sunday-first short weekday names in the UI language. Hard-coded
/// S M T W T F S was ambiguous (two S, two T) and English-only.
List<String> weekdayLetters(BuildContext context) {
  final names = DateFormat.E(
    Localizations.localeOf(context).toLanguageTag(),
  ).dateSymbols.STANDALONENARROWWEEKDAYS;
  final short = DateFormat.E(
    Localizations.localeOf(context).toLanguageTag(),
  ).dateSymbols.STANDALONESHORTWEEKDAYS;
  // Narrow names repeat letters in English; short ones are unambiguous.
  return names.toSet().length == 7 ? names : short;
}

/// Shift definitions and who works them.
///
/// The timesheet is only as truthful as the schedule behind it, so this is
/// where "late" and "absent" actually get their meaning.
class ShiftsPage extends StatefulWidget {
  const ShiftsPage({super.key});

  @override
  State<ShiftsPage> createState() => _ShiftsPageState();
}

class _ShiftsPageState extends State<ShiftsPage> {
  Future<(List<ShiftRow>, List<EmployeeRow>, List<EmployeeShiftRow>)>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<(List<ShiftRow>, List<EmployeeRow>, List<EmployeeShiftRow>)>
  _load() async {
    final db = AppScope.dbOf(context);
    return (
      await db.allShifts(),
      await db.allEmployees(),
      await db.allEmployeeShifts(),
    );
  }

  void _refresh() => setState(() {
    _future = _load();
  });

  /// People on the shift now; closed-off assignments are history, not members.
  static int _openCount(List<EmployeeShiftRow> all, int shiftId) {
    final t = DateTime.now();
    final today =
        DateTime(t.year, t.month, t.day).toUtc().millisecondsSinceEpoch ~/ 1000;
    return all
        .where(
          (a) =>
              a.shiftId == shiftId &&
              (a.effectiveTo == null || a.effectiveTo! >= today),
        )
        .map((a) => a.employeeId)
        .toSet()
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l.schedules)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(null),
        icon: const Icon(Icons.add),
        label: Text(l.addShift),
      ),
      body:
          FutureBuilder<
            (List<ShiftRow>, List<EmployeeRow>, List<EmployeeShiftRow>)
          >(
            future: _future,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final (shifts, employees, assignments) = snap.data!;

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
                children: [
                  Text(
                    l.shiftsHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  for (final s in shifts)
                    _ShiftCard(
                      shift: s,
                      assignedCount: _openCount(assignments, s.id),
                      onEdit: () => _edit(s),
                      onMakeDefault: () async {
                        await AppScope.dbOf(context).setDefaultShift(s.id);
                        _refresh();
                      },
                      onDelete: () => _delete(s, shifts.length),
                      onAssign: () => _assign(s, employees, assignments),
                    ),
                ],
              );
            },
          ),
    );
  }

  Future<void> _edit(ShiftRow? existing) async {
    final saved = await showDialog<ShiftsCompanion>(
      context: context,
      builder: (_) => _ShiftDialog(existing: existing),
    );
    if (saved == null || !mounted) return;

    final db = AppScope.dbOf(context);
    await db.upsertShift(saved);
    // A first shift with nothing marked default would leave everyone
    // unscheduled, which reads as "day off" for the entire month.
    if ((await db.defaultShift()) == null) {
      final all = await db.allShifts();
      if (all.isNotEmpty) await db.setDefaultShift(all.first.id);
    }
    _refresh();
  }

  Future<void> _delete(ShiftRow s, int total) async {
    final l = AppLocalizations.of(context)!;
    if (total <= 1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.cannotDeleteLastShift)));
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${l.delete} "${s.name}"?'),
        content: Text(l.deleteShiftHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final db = AppScope.dbOf(context);
    // Assignments pointing at a deleted shift would resolve to nothing and
    // silently mark those people unscheduled.
    await db.clearAssignmentsFor(s.id);
    await db.deleteShift(s.id);
    if ((await db.defaultShift()) == null) {
      final all = await db.allShifts();
      if (all.isNotEmpty) await db.setDefaultShift(all.first.id);
    }
    _refresh();
  }

  Future<void> _assign(
    ShiftRow shift,
    List<EmployeeRow> employees,
    List<EmployeeShiftRow> assignments,
  ) async {
    final l = AppLocalizations.of(context)!;
    if (employees.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.noEmployees)));
      return;
    }

    final db = AppScope.dbOf(context);
    final today = DateTime.now();
    final assignedHere = await db.currentMembers(shift.id, today);
    if (!mounted) return;

    final chosen = await showDialog<Set<int>>(
      context: context,
      builder: (ctx) => _AssignDialog(
        shiftName: shift.name,
        employees: employees.where((e) => !e.removed).toList(),
        initiallySelected: assignedHere,
      ),
    );
    if (chosen == null || !mounted) return;

    // From today on only. This used to delete the shift's assignments and
    // re-insert them effective today, which rewrote everyone's past: last
    // month's timesheet silently recalculated against the default shift.
    await db.setShiftMembers(shift.id, chosen, today);
    _refresh();
  }
}

class _ShiftCard extends StatelessWidget {
  const _ShiftCard({
    required this.shift,
    required this.assignedCount,
    required this.onEdit,
    required this.onMakeDefault,
    required this.onDelete,
    required this.onAssign,
  });

  final ShiftRow shift;
  final int assignedCount;
  final VoidCallback onEdit;
  final VoidCallback onMakeDefault;
  final VoidCallback onDelete;
  final VoidCallback onAssign;

  static String _hhmm(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final flexible = shift.kind == 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    shift.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (shift.isDefault)
                  StatusPill(label: l.defaultShift, color: scheme.primary),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              flexible
                  ? '${l.flexibleHours} · ${shift.requiredMinutes ~/ 60}h ${l.perDay}'
                  : '${_hhmm(shift.startMinute)} – ${_hhmm(shift.endMinute)}'
                        '${shift.breakMinutes > 0 ? '  ·  ${shift.breakMinutes}m ${l.breakLabel}' : ''}'
                        '  ·  ${l.grace} ${shift.graceInMinutes}m',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 24),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: (shift.daysMask & (1 << i)) != 0
                            ? scheme.primary.withValues(alpha: 0.15)
                            : Colors.transparent,
                        border: Border.all(color: scheme.outlineVariant),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        weekdayLetters(context)[i],
                        style: TextStyle(
                          fontSize: 11,
                          color: (shift.daysMask & (1 << i)) != 0
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onAssign,
                  icon: const Icon(Icons.people_outline, size: 18),
                  label: Text('$assignedCount'),
                ),
                if (!shift.isDefault)
                  TextButton(
                    onPressed: onMakeDefault,
                    child: Text(l.makeDefault),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShiftDialog extends StatefulWidget {
  const _ShiftDialog({this.existing});
  final ShiftRow? existing;

  @override
  State<_ShiftDialog> createState() => _ShiftDialogState();
}

class _ShiftDialogState extends State<_ShiftDialog> {
  late TextEditingController _name;
  late bool _flexible;
  late int _start, _end, _breakM, _graceIn, _graceOut, _required, _days;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _flexible = e?.kind == 1;
    _start = e?.startMinute ?? 9 * 60;
    _end = e?.endMinute ?? 17 * 60;
    _breakM = e?.breakMinutes ?? 0;
    _graceIn = e?.graceInMinutes ?? 10;
    _graceOut = e?.graceOutMinutes ?? 10;
    _required = e?.requiredMinutes ?? 480;
    _days = e?.daysMask ?? 0x3E;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isStart) async {
    final current = isStart ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null) return;
    setState(() {
      final v = picked.hour * 60 + picked.minute;
      if (isStart) {
        _start = v;
      } else {
        _end = v;
      }
    });
  }

  static String _hhmm(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final letters = weekdayLetters(context);

    return AlertDialog(
      title: Text(widget.existing == null ? l.addShift : l.editShift),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                decoration: InputDecoration(labelText: l.shiftName),
              ),
              const SizedBox(height: 20),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(l.fixedHours)),
                  ButtonSegment(value: true, label: Text(l.flexibleHours)),
                ],
                selected: {_flexible},
                onSelectionChanged: (s) => setState(() => _flexible = s.first),
              ),
              const SizedBox(height: 8),
              Text(
                _flexible ? l.flexibleHint : l.fixedHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),

              if (_flexible)
                _NumberRow(
                  label: l.requiredPerDay,
                  value: _required,
                  suffix: l.minutesShort,
                  step: 30,
                  max: 16 * 60,
                  onChanged: (v) => setState(() => _required = v),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickTime(true),
                        child: Text('${l.startTime}  ${_hhmm(_start)}'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickTime(false),
                        child: Text('${l.endTime}  ${_hhmm(_end)}'),
                      ),
                    ),
                  ],
                ),
                if (_end < _start) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.nightlight_outlined, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l.crossesMidnight,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                _NumberRow(
                  label: l.breakLabel,
                  value: _breakM,
                  suffix: l.minutesShort,
                  step: 15,
                  max: 240,
                  onChanged: (v) => setState(() => _breakM = v),
                ),
                _NumberRow(
                  label: l.graceIn,
                  value: _graceIn,
                  suffix: l.minutesShort,
                  step: 5,
                  max: 60,
                  onChanged: (v) => setState(() => _graceIn = v),
                ),
                _NumberRow(
                  label: l.graceOut,
                  value: _graceOut,
                  suffix: l.minutesShort,
                  step: 5,
                  max: 60,
                  onChanged: (v) => setState(() => _graceOut = v),
                ),
              ],

              const SizedBox(height: 16),
              Text(
                l.workingDays,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              // Wrap, not Row: seven chips overflow a 420px dialog.
              Wrap(
                children: [
                  for (var i = 0; i < 7; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 6, bottom: 6),
                      child: FilterChip(
                        label: Text(letters[i]),
                        selected: (_days & (1 << i)) != 0,
                        onSelected: (on) => setState(() {
                          _days = on ? _days | (1 << i) : _days & ~(1 << i);
                        }),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(l.weekendHint, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(
              context,
              ShiftsCompanion(
                id: widget.existing == null
                    ? const Value.absent()
                    : Value(widget.existing!.id),
                name: Value(name),
                kind: Value(_flexible ? 1 : 0),
                startMinute: Value(_start),
                endMinute: Value(_end),
                breakMinutes: Value(_breakM),
                graceInMinutes: Value(_graceIn),
                graceOutMinutes: Value(_graceOut),
                requiredMinutes: Value(_required),
                daysMask: Value(_days),
                isDefault: widget.existing == null
                    ? const Value.absent()
                    : Value(widget.existing!.isDefault),
              ),
            );
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}

class _NumberRow extends StatelessWidget {
  const _NumberRow({
    required this.label,
    required this.value,
    required this.suffix,
    required this.step,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final String suffix;
  final int step;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          IconButton(
            onPressed: value - step >= 0 ? () => onChanged(value - step) : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 64,
            child: Text('$value $suffix', textAlign: TextAlign.center),
          ),
          IconButton(
            onPressed: value + step <= max
                ? () => onChanged(value + step)
                : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}

class _AssignDialog extends StatefulWidget {
  const _AssignDialog({
    required this.shiftName,
    required this.employees,
    required this.initiallySelected,
  });

  final String shiftName;
  final List<EmployeeRow> employees;
  final Set<int> initiallySelected;

  @override
  State<_AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends State<_AssignDialog> {
  late final Set<int> _selected = {...widget.initiallySelected};

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text('${l.assignTo} "${widget.shiftName}"'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.assignHint, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              for (final e in widget.employees)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _selected.contains(e.id),
                  title: Text(e.name.isEmpty ? 'ID ${e.id}' : e.name),
                  onChanged: (on) => setState(() {
                    if (on == true) {
                      _selected.add(e.id);
                    } else {
                      _selected.remove(e.id);
                    }
                  }),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: Text(l.save),
        ),
      ],
    );
  }
}
