import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/attendance_rules.dart';
import '../data/file_save.dart';
import '../data/sync_service.dart';
import '../domain/timesheet.dart';
import '../domain/timesheet_report.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import 'shifts_page.dart';
import 'theme.dart';

/// Monthly timesheet, computed locally from stored punches.
///
/// Everything here comes out of the local database, so it works with the
/// terminal switched off. Anything the calculation could not determine is
/// marked rather than folded into a total.
class TimesheetPage extends StatefulWidget {
  const TimesheetPage({super.key});

  @override
  State<TimesheetPage> createState() => _TimesheetPageState();
}

class _TimesheetPageState extends State<TimesheetPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  int? _expanded;
  Future<List<EmployeeTimesheet>>? _future;
  List<EmployeeTimesheet> _lastSheets = const [];

  SyncService? _sync;
  int _seenRevision = -1;

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

  /// New punches or a correction change the figures; recompute rather than
  /// show numbers from before they arrived.
  void _onSync() {
    final rev = _sync!.revision;
    if (rev == _seenRevision || !mounted) return;
    _seenRevision = rev;
    setState(() {
      _future = _load();
    });
  }

  Future<List<EmployeeTimesheet>> _load() async {
    final repo = TimesheetRepository(AppScope.dbOf(context));
    // A fresh install has no shifts, so nothing would be "scheduled" and every
    // day would read as a day off. Seed one so the numbers mean something.
    await repo.ensureDefaultShift();

    final from = DateTime(_month.year, _month.month, 1);
    final to = DateTime(_month.year, _month.month + 1, 0); // last of month
    final sheets = await repo.build(from: from, to: to);
    // The export button sits in the AppBar, outside the FutureBuilder,
    // so it has to be told the figures exist.
    if (mounted) setState(() => _lastSheets = sheets);
    return sheets;
  }

  bool _exporting = false;

  Future<void> _export(List<EmployeeTimesheet> sheets) async {
    final l = AppLocalizations.of(context)!;
    final lang = AppScope.settingsOf(context).locale.languageCode;
    setState(() => _exporting = true);
    try {
      final bytes = TimesheetReport.build(
        sheets: sheets,
        month: _month,
        lang: lang,
      );
      final path = await saveFile(
        TimesheetReport.fileName(_month, lang),
        bytes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(path == null ? l.exported : '${l.exported}: $path'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _expanded = null;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.navTimesheet),
        actions: [
          IconButton(
            tooltip: l.exportXlsx,
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined),
            onPressed: (_exporting || _lastSheets.isEmpty)
                ? null
                : () => _export(_lastSheets),
          ),
          IconButton(
            tooltip: l.schedules,
            icon: const Icon(Icons.tune),
            onPressed: () async {
              await Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ShiftsPage()));
              // Rules may have changed, so the figures must be recomputed.
              if (mounted) {
                setState(() {
                  _future = _load();
                });
              }
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: l.previousMonth,
            onPressed: () => _shiftMonth(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              // Localised: the month name was hard-coded English.
              child: Text(
                DateFormat.yMMMM(
                  Localizations.localeOf(context).toLanguageTag(),
                ).format(_month),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          IconButton(
            tooltip: l.nextMonth,
            onPressed: () => _shiftMonth(1),
            icon: const Icon(Icons.chevron_right),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<EmployeeTimesheet>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text(snap.error.toString()));
          }
          final sheets = snap.data ?? const <EmployeeTimesheet>[];
          if (sheets.isEmpty) {
            return Center(child: Text(l.noTimesheetData));
          }

          final expanded = _expanded == null
              ? null
              : sheets.firstWhere(
                  (s) => s.employeeId == _expanded,
                  orElse: () => sheets.first,
                );

          return expanded != null
              ? _DayDetail(
                  sheet: expanded,
                  onBack: () => setState(() => _expanded = null),
                )
              : _Overview(
                  sheets: sheets,
                  onOpen: (id) => setState(() => _expanded = id),
                );
        },
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.sheets, required this.onOpen});

  final List<EmployeeTimesheet> sheets;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    final worked = sheets.fold(0, (n, s) => n + s.workedMinutes);
    final late = sheets.fold(0, (n, s) => n + s.lateOccasions);
    final absent = sheets.fold(0, (n, s) => n + s.daysAbsent);
    final review = sheets.fold(0, (n, s) => n + s.daysNeedingReview);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (review > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(l.reviewHint)),
              ],
            ),
          ),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _Stat(l.hoursWorked, hm(context, worked), Icons.schedule),
            _Stat(l.lateOccasions, '$late', Icons.running_with_errors),
            _Stat(l.absences, '$absent', Icons.event_busy),
            _Stat(
              l.needsReview,
              '$review',
              Icons.fact_check_outlined,
              tint: review > 0 ? AppTheme.warning : null,
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text(l.perEmployee, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              for (final s in sheets) ...[
                if (s != sheets.first) const Divider(height: 1),
                ListTile(
                  onTap: () => onOpen(s.employeeId),
                  title: Text(s.name),
                  subtitle: Text(
                    '${s.daysPresent} ${l.daysPresent}'
                    '${s.daysAbsent > 0 ? '  ·  ${s.daysAbsent} ${l.absences}' : ''}'
                    '${s.lateOccasions > 0 ? '  ·  ${s.lateOccasions} ${l.lateOccasions}' : ''}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (s.daysNeedingReview > 0) ...[
                        StatusPill(
                          label: '${s.daysNeedingReview}',
                          color: AppTheme.warning,
                          icon: Icons.error_outline,
                        ),
                        const SizedBox(width: 12),
                      ],
                      Text(
                        hm(context, s.workedMinutes),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, size: 20),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DayDetail extends StatelessWidget {
  const _DayDetail({required this.sheet, required this.onBack});

  final EmployeeTimesheet sheet;
  final VoidCallback onBack;

  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _clock(DateTime? t) =>
      t == null ? '—' : '${_two(t.hour)}:${_two(t.minute)}';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    String statusText(DayStatus s) => switch (s) {
      DayStatus.present => l.statusPresent,
      DayStatus.absent => l.statusAbsent,
      DayStatus.incomplete => l.statusIncomplete,
      DayStatus.off => l.statusOff,
      DayStatus.upcoming => l.statusUpcoming,
    };

    Color statusColor(DayStatus s) => switch (s) {
      DayStatus.present => AppTheme.present,
      DayStatus.absent => AppTheme.danger,
      DayStatus.incomplete => AppTheme.warning,
      DayStatus.off => AppTheme.absent,
      DayStatus.upcoming => AppTheme.absent,
    };

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
            const SizedBox(width: 4),
            Text(sheet.name, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _Stat(
              l.hoursWorked,
              hm(context, sheet.workedMinutes),
              Icons.schedule,
            ),
            _Stat(
              l.overtime,
              hm(context, sheet.overtimeMinutes),
              Icons.more_time,
            ),
            _Stat(
              l.lateOccasions,
              '${sheet.lateOccasions}',
              Icons.running_with_errors,
            ),
            _Stat(
              l.earlyLeave,
              hm(context, sheet.earlyLeaveMinutes),
              Icons.logout,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          child: Column(
            children: [
              for (final d in sheet.days) ...[
                if (d != sheet.days.first) const Divider(height: 1),
                ListTile(
                  dense: true,
                  leading: SizedBox(
                    width: 52,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${d.day.day}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          DateFormat.E(
                            Localizations.localeOf(context).toLanguageTag(),
                          ).format(d.day),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  title: Row(
                    children: [
                      StatusPill(
                        label: d.inProgress
                            ? l.statusAtWork
                            : statusText(d.status),
                        color: statusColor(d.status),
                      ),
                      if (d.needsReview) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.error_outline,
                          size: 16,
                          color: AppTheme.warning,
                        ),
                      ],
                    ],
                  ),
                  subtitle: d.firstIn == null && d.lastOut == null
                      ? null
                      : Text(
                          '${_clock(d.firstIn)} → ${_clock(d.lastOut)}'
                          '${d.lateMinutes > 0 ? '   ·   +${hm(context, d.lateMinutes)} ${l.lateOccasions}' : ''}',
                        ),
                  trailing: Text(
                    d.workedMinutes == 0 ? '—' : hm(context, d.workedMinutes),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.icon, {this.tint});

  final String label;
  final String value;
  final IconData icon;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 200,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: tint ?? scheme.primary),
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
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(color: tint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hours and minutes in the UI language ("7h 35m" read oddly in Arabic).
String hm(BuildContext context, int minutes) {
  final l = AppLocalizations.of(context)!;
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (m == 0) return '$h${l.hoursAbbr}';
  return '$h${l.hoursAbbr} $m${l.minutesAbbr}';
}
