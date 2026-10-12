import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/file_save.dart';
import '../data/sync_service.dart';
import '../domain/payroll.dart';
import '../domain/payroll_report.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import 'theme.dart';
import 'timesheet_page.dart' show hm;

/// Monthly salaries, built on the timesheet.
///
/// A live month recalculates whenever punches arrive. Marking it paid freezes
/// the payslips as they stand, so nothing done afterwards changes a salary
/// that was already handed over.
class PayrollPage extends StatefulWidget {
  const PayrollPage({super.key});

  @override
  State<PayrollPage> createState() => _PayrollPageState();
}

class _PayrollPageState extends State<PayrollPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  int? _open;
  Future<PayrollMonth>? _future;
  PayrollMonth? _last;
  bool _busy = false;

  SyncService? _sync;
  int _seenRevision = -1;

  PayrollRepository get _repo => PayrollRepository(AppScope.dbOf(context));

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
    final rev = _sync!.revision;
    if (rev == _seenRevision || !mounted) return;
    _seenRevision = rev;
    _reload();
  }

  Future<PayrollMonth> _load() async {
    final m = await _repo.load(_month);
    if (mounted) setState(() => _last = m);
    return m;
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = _load();
    });
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _open = null;
      _future = _load();
    });
  }

  String get _locale => Localizations.localeOf(context).toLanguageTag();

  String _monthName(DateTime m) => DateFormat.yMMMM(_locale).format(m);

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  /// Runs an edit, then recomputes. A paid month refuses edits in the
  /// repository as well as in the UI; say so rather than failing quietly.
  Future<void> _edit(Future<void> Function() action) async {
    final l = AppLocalizations.of(context)!;
    try {
      await action();
    } on MonthClosedException {
      if (mounted) _snack(l.monthClosed);
    }
    _reload();
  }

  // --- actions ---------------------------------------------------------------

  Future<void> _export(PayrollMonth m) async {
    final l = AppLocalizations.of(context)!;
    final settings = AppScope.settingsOf(context);
    final lang = settings.locale.languageCode;
    setState(() => _busy = true);
    try {
      final bytes = PayrollReport.build(
        payroll: m,
        currency: m.currency ?? settings.currency,
        lang: lang,
      );
      final path = await saveFile(PayrollReport.fileName(_month, lang), bytes);
      if (mounted) {
        _snack(path == null ? l.exported : '${l.exported}: $path');
      }
    } catch (e) {
      if (mounted) _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editRules() async {
    final settings = AppScope.settingsOf(context);
    final current = await _repo.rules();
    if (!mounted) return;
    final result = await showDialog<(PayRules, String)>(
      context: context,
      builder: (_) => _RulesDialog(rules: current, currency: settings.currency),
    );
    if (result == null || !mounted) return;
    await _repo.saveRules(result.$1);
    await settings.setCurrency(result.$2);
    _reload();
  }

  Future<void> _markPaid(PayrollMonth m) async {
    final l = AppLocalizations.of(context)!;
    final notOver = DateTime.now().isBefore(
      DateTime(_month.year, _month.month + 1),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.markPaidTitle(_monthName(_month))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.markPaidBody),
            if (notOver || m.daysNeedingReview > 0 || m.withoutWage > 0)
              const SizedBox(height: 12),
            if (notOver) _Warning(l.monthNotOver),
            if (m.daysNeedingReview > 0) _Warning(l.reviewHint),
            if (m.withoutWage > 0) _Warning(l.noWageHint(m.withoutWage)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.markPaid),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final currency = AppScope.settingsOf(context).currency;
    await _edit(() async {
      // Recompute rather than trust what is on screen: a sync may have
      // landed since it was drawn.
      final fresh = await _repo.load(_month);
      await _repo.markPaid(fresh, currency);
    });
  }

  Future<void> _reopen() async {
    final l = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${l.reopen} ${_monthName(_month)}?'),
        content: Text(l.reopenBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.warning),
            child: Text(l.reopen),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _repo.reopen(_month);
    _reload();
  }

  Future<void> _setWage(Payslip p) async {
    final wage = await showDialog<Wage>(
      context: context,
      builder: (_) =>
          _WageDialog(existing: p.wage, monthName: _monthName(_month)),
    );
    if (wage == null || !mounted) return;
    await _edit(() => _repo.setWage(p.employeeId, _month, wage));
  }

  Future<void> _editFigure(Payslip p, _Figure f) async {
    final result = await showDialog<_FigureResult>(
      context: context,
      builder: (_) => _FigureDialog(
        figure: f,
        clock: f.read(p.clock),
        current: f.read(p.paid),
      ),
    );
    if (result == null || !mounted) return;

    // Carry the other edits over; only this figure changes.
    int? keep(_Figure x) {
      if (x == f) return result.reset ? null : result.value;
      final paid = x.read(p.paid);
      return paid == x.read(p.clock) ? null : paid;
    }

    await _edit(
      () => _repo.setOverrides(
        p.employeeId,
        _month,
        PayOverrides(
          overtimeMinutes: keep(_Figure.overtime),
          dayOffMinutes: keep(_Figure.dayOff),
          lateMinutes: keep(_Figure.late),
          earlyLeaveMinutes: keep(_Figure.early),
          absentDays: keep(_Figure.absent),
        ),
      ),
    );
  }

  Future<void> _addAdjustment(Payslip p) async {
    final a = await showDialog<PayAdjustment>(
      context: context,
      builder: (_) => const _AdjustmentDialog(),
    );
    if (a == null || !mounted) return;
    await _edit(() => _repo.addAdjustment(p.employeeId, _month, a));
  }

  Future<void> _removeAdjustment(Payslip p, PayAdjustment a) =>
      _edit(() => _repo.removeAdjustment(p.employeeId, _month, a));

  // --- build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final last = _last;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.navPayroll),
        actions: [
          IconButton(
            tooltip: l.exportXlsx,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined),
            onPressed: (_busy || last == null || last.slips.isEmpty)
                ? null
                : () => _export(last),
          ),
          IconButton(
            tooltip: l.payRules,
            icon: const Icon(Icons.tune),
            onPressed: _editRules,
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
              child: Text(
                _monthName(_month),
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
      body: FutureBuilder<PayrollMonth>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text(snap.error.toString()));
          }
          final m = snap.data!;
          if (m.slips.isEmpty) {
            return Center(child: Text(l.noTimesheetData));
          }
          final money = _Money(
            m.currency ?? AppScope.settingsOf(context).currency,
          );

          final open = _open == null
              ? null
              : m.slips.where((s) => s.employeeId == _open).firstOrNull;
          if (open != null) {
            return _PayslipView(
              slip: open,
              month: m,
              money: money,
              onBack: () => setState(() => _open = null),
              onSetWage: () => _setWage(open),
              onEditFigure: (f) => _editFigure(open, f),
              onAddAdjustment: () => _addAdjustment(open),
              onRemoveAdjustment: (a) => _removeAdjustment(open, a),
            );
          }
          return _Overview(
            month: m,
            money: money,
            paidOn: m.paidAt == null
                ? null
                : DateFormat.yMMMd(_locale).format(m.paidAt!),
            onOpen: (id) => setState(() => _open = id),
            onMarkPaid: () => _markPaid(m),
            onReopen: _reopen,
          );
        },
      ),
    );
  }
}

/// Amounts with two decimals and the store's currency label. Latin digits in
/// both languages, matching the rest of the app's figures.
///
/// Each amount is wrapped in a left-to-right isolate. Without it, Arabic text
/// around "−400.00 EGP" reorders the sign, number and label, and a row of
/// amounts reads in a scrambled order.
class _Money {
  _Money(this.currency);

  final String currency;
  static final _f = NumberFormat('#,##0.00', 'en');

  String call(double v, {String sign = ''}) {
    final n = '$sign${_f.format(v)}';
    // A no-break space: the isolate makes the text engine underestimate the
    // width, and an ordinary space then wraps the label onto its own line.
    return '\u2066${currency.isEmpty ? n : '$n\u00a0$currency'}\u2069';
  }
}

String _wageText(AppLocalizations l, Wage? w, _Money money) {
  if (w == null) return l.noWageSet;
  final kind = switch (w.kind) {
    WageKind.monthly => l.wageMonthly,
    WageKind.daily => l.wageDaily,
    WageKind.hourly => l.wageHourly,
  };
  return '$kind · ${money(w.amount)}';
}

// --- overview ---------------------------------------------------------------

class _Overview extends StatelessWidget {
  const _Overview({
    required this.month,
    required this.money,
    required this.paidOn,
    required this.onOpen,
    required this.onMarkPaid,
    required this.onReopen,
  });

  final PayrollMonth month;
  final _Money money;
  final String? paidOn;
  final ValueChanged<int> onOpen;
  final VoidCallback onMarkPaid;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final m = month;
    final notOver = DateTime.now().isBefore(
      DateTime(m.month.year, m.month.month + 1),
    );

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (m.isPaid)
          _Banner(
            color: AppTheme.present,
            icon: Icons.lock_outline,
            text: l.paidBanner(paidOn!),
            action: TextButton(onPressed: onReopen, child: Text(l.reopen)),
          )
        else ...[
          if (notOver)
            _Banner(
              color: AppTheme.absent,
              icon: Icons.info_outline,
              text: l.monthNotOver,
            ),
          if (m.withoutWage > 0)
            _Banner(
              color: AppTheme.warning,
              icon: Icons.payments_outlined,
              text: l.noWageHint(m.withoutWage),
            ),
          if (m.daysNeedingReview > 0)
            _Banner(
              color: AppTheme.warning,
              icon: Icons.error_outline,
              text: l.reviewHint,
            ),
        ],
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _Stat(l.totalNet, money(m.totalNet), Icons.account_balance_wallet),
            _Stat(
              l.additionsLabel,
              money(m.totalAdditions),
              Icons.add_circle_outline,
              tint: AppTheme.present,
            ),
            _Stat(
              l.cutsLabel,
              money(m.totalCuts),
              Icons.remove_circle_outline,
              tint: AppTheme.danger,
            ),
            _Stat(
              l.withoutWage,
              '${m.withoutWage}',
              Icons.person_off_outlined,
              tint: m.withoutWage > 0 ? AppTheme.warning : null,
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text(l.perEmployee, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              for (final s in m.slips) ...[
                if (s != m.slips.first) const Divider(height: 1),
                ListTile(
                  onTap: () => onOpen(s.employeeId),
                  title: Text(s.name),
                  subtitle: Text(
                    [
                      _wageText(l, s.wage, money),
                      if (s.additions > 0) money(s.additions, sign: '+'),
                      if (s.cuts > 0) money(s.cuts, sign: '−'),
                    ].join('   ·   '),
                    style: s.hasWage
                        ? null
                        : const TextStyle(color: AppTheme.warning),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (s.edited) ...[
                        StatusPill(
                          label: l.editedPill,
                          color: Theme.of(context).colorScheme.primary,
                          icon: Icons.edit_outlined,
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (s.daysNeedingReview > 0) ...[
                        StatusPill(
                          label: '${s.daysNeedingReview}',
                          color: AppTheme.warning,
                          icon: Icons.error_outline,
                        ),
                        const SizedBox(width: 12),
                      ],
                      Text(
                        money(s.net),
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
        if (!m.isPaid) ...[
          const SizedBox(height: 20),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.icon(
              onPressed: onMarkPaid,
              icon: const Icon(Icons.task_alt),
              label: Text(l.markPaid),
            ),
          ),
        ],
      ],
    );
  }
}

// --- one employee -----------------------------------------------------------

/// The clock figures a manager can replace, and how each reads and displays.
enum _Figure {
  overtime,
  dayOff,
  late,
  early,
  absent;

  int read(PayFigures f) => switch (this) {
    _Figure.overtime => f.overtimeMinutes,
    _Figure.dayOff => f.dayOffMinutes,
    _Figure.late => f.lateMinutes,
    _Figure.early => f.earlyLeaveMinutes,
    _Figure.absent => f.absentDays,
  };

  bool get isDays => this == _Figure.absent;

  /// Overtime is thought of in hours; lateness in minutes.
  bool get isHours => this == _Figure.overtime || this == _Figure.dayOff;

  String label(AppLocalizations l) => switch (this) {
    _Figure.overtime => l.overtimePay,
    _Figure.dayOff => l.dayOffPay,
    _Figure.late => l.lateCut,
    _Figure.early => l.earlyCut,
    _Figure.absent => l.absenceCut,
  };

  String show(BuildContext context, int v) {
    final l = AppLocalizations.of(context)!;
    return isDays ? '$v ${l.daysUnit}' : hm(context, v);
  }
}

class _PayslipView extends StatelessWidget {
  const _PayslipView({
    required this.slip,
    required this.month,
    required this.money,
    required this.onBack,
    required this.onSetWage,
    required this.onEditFigure,
    required this.onAddAdjustment,
    required this.onRemoveAdjustment,
  });

  final Payslip slip;
  final PayrollMonth month;
  final _Money money;
  final VoidCallback onBack;
  final VoidCallback onSetWage;
  final ValueChanged<_Figure> onEditFigure;
  final VoidCallback onAddAdjustment;
  final ValueChanged<PayAdjustment> onRemoveAdjustment;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final s = slip;
    final locked = month.isPaid;
    final kind = s.wage?.kind;
    final hourly = kind == WageKind.hourly;

    Widget figure(_Figure f, double amount, {required bool add}) => _Line(
      label: f.label(l),
      quantity: f.show(context, f.read(s.paid)),
      amount: amount,
      add: add,
      money: money,
      clock: f.read(s.paid) == f.read(s.clock)
          ? null
          : l.clockFigure(f.show(context, f.read(s.clock))),
      onEdit: locked || !s.hasWage ? null : () => onEditFigure(f),
    );

    final baseQty = switch (kind) {
      WageKind.daily => '${s.daysWorked} ${l.daysUnit}',
      WageKind.hourly => hm(context, s.regularMinutes),
      _ => '',
    };

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                s.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: Icon(
              Icons.payments_outlined,
              color: s.hasWage ? null : AppTheme.warning,
            ),
            title: Text(_wageText(l, s.wage, money)),
            subtitle: s.hasWage
                ? Text(
                    '${l.dayRate} ${money(s.dayRate)}   ·   '
                    '${l.hourRate} ${money(s.hourRate)}',
                  )
                : null,
            trailing: locked
                ? null
                : TextButton.icon(
                    onPressed: onSetWage,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(l.setWage),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                _Line(
                  label: l.basePay,
                  quantity: baseQty,
                  amount: s.basePay,
                  add: true,
                  money: money,
                ),
                figure(_Figure.overtime, s.overtimePay, add: true),
                figure(_Figure.dayOff, s.dayOffPay, add: true),
                if (!hourly) ...[
                  figure(_Figure.late, s.lateDeduction, add: false),
                  figure(_Figure.early, s.earlyLeaveDeduction, add: false),
                ],
                figure(_Figure.absent, s.absenceDeduction, add: false),
                if (s.bonuses > 0)
                  _Line(
                    label: l.bonus,
                    amount: s.bonuses,
                    add: true,
                    money: money,
                  ),
                if (s.deductions > 0)
                  _Line(
                    label: l.deduction,
                    amount: s.deductions,
                    add: false,
                    money: money,
                  ),
                if (s.advances > 0)
                  _Line(
                    label: l.advance,
                    amount: s.advances,
                    add: false,
                    money: money,
                  ),
                const Divider(height: 17),
                ListTile(
                  title: Text(
                    l.netPay,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  trailing: Text(
                    money(s.net),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (kind != null && kind != WageKind.monthly) ...[
          const SizedBox(height: 8),
          Text(
            hourly ? l.hourlyNoCuts : l.dailyAbsenceNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                l.adjustmentsTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (!locked)
              TextButton.icon(
                onPressed: onAddAdjustment,
                icon: const Icon(Icons.add),
                label: Text(l.add),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: s.adjustments.isEmpty
              ? ListTile(title: Text(l.noAdjustments))
              : Column(
                  children: [
                    for (final a in s.adjustments) ...[
                      if (a != s.adjustments.first) const Divider(height: 1),
                      ListTile(
                        title: Text(switch (a.kind) {
                          AdjustmentKind.bonus => l.bonus,
                          AdjustmentKind.deduction => l.deduction,
                          AdjustmentKind.advance => l.advance,
                        }),
                        subtitle: a.note.isEmpty ? null : Text(a.note),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              money(
                                a.amount,
                                sign: a.kind == AdjustmentKind.bonus
                                    ? '+'
                                    : '−',
                              ),
                              style: TextStyle(
                                color: a.kind == AdjustmentKind.bonus
                                    ? AppTheme.present
                                    : AppTheme.danger,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (!locked)
                              IconButton(
                                tooltip: l.delete,
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => onRemoveAdjustment(a),
                              ),
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

/// One payslip line: what it is, how much of it, and what it adds or takes.
class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    this.quantity = '',
    required this.amount,
    required this.add,
    required this.money,
    this.clock,
    this.onEdit,
  });

  final String label;
  final String quantity;
  final double amount;
  final bool add;
  final _Money money;

  /// Set when the manager replaced the clock figure; shows what it was.
  final String? clock;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final zero = amount == 0;
    final color = zero
        ? scheme.onSurfaceVariant
        : (add ? null : AppTheme.danger);

    return ListTile(
      dense: true,
      title: Row(
        children: [
          Flexible(child: Text(label)),
          if (clock != null) ...[
            const SizedBox(width: 8),
            StatusPill(
              label: l.editedPill,
              color: scheme.primary,
              icon: Icons.edit_outlined,
            ),
          ],
        ],
      ),
      subtitle: clock == null && quantity.isEmpty
          ? null
          : Text([quantity, ?clock].where((t) => t.isNotEmpty).join('   ·   ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            zero ? '—' : money(amount, sign: add ? '' : '−'),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          if (onEdit != null)
            IconButton(
              tooltip: l.editFigure,
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: onEdit,
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}

// --- dialogs ----------------------------------------------------------------

/// Parses what people type for money: "3000", "3,000", "3000.5".
double? _parseAmount(String raw) =>
    double.tryParse(raw.trim().replaceAll(',', ''));

class _WageDialog extends StatefulWidget {
  const _WageDialog({required this.existing, required this.monthName});

  final Wage? existing;
  final String monthName;

  @override
  State<_WageDialog> createState() => _WageDialogState();
}

class _WageDialogState extends State<_WageDialog> {
  late WageKind _kind = widget.existing?.kind ?? WageKind.monthly;
  late final _amount = TextEditingController(
    text: widget.existing == null ? '' : _plain(widget.existing!.amount),
  );
  String? _error;

  static String _plain(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    final l = AppLocalizations.of(context)!;
    final v = _parseAmount(_amount.text);
    if (v == null || v <= 0) {
      setState(() => _error = l.invalidAmount);
      return;
    }
    Navigator.pop(context, Wage(kind: _kind, amount: v));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l.setWage),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<WageKind>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: WageKind.monthly,
                  label: Text(l.wageMonthly),
                ),
                ButtonSegment(value: WageKind.daily, label: Text(l.wageDaily)),
                ButtonSegment(
                  value: WageKind.hourly,
                  label: Text(l.wageHourly),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: l.amount,
                errorText: _error,
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            Text(
              l.wageFromMonth(widget.monthName),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_kind == WageKind.monthly) ...[
              const SizedBox(height: 6),
              Text(
                l.payRulesHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(onPressed: _save, child: Text(l.save)),
      ],
    );
  }
}

class _FigureResult {
  const _FigureResult({this.value, this.reset = false});
  final int? value;
  final bool reset;
}

class _FigureDialog extends StatefulWidget {
  const _FigureDialog({
    required this.figure,
    required this.clock,
    required this.current,
  });

  final _Figure figure;
  final int clock;
  final int current;

  @override
  State<_FigureDialog> createState() => _FigureDialogState();
}

class _FigureDialogState extends State<_FigureDialog> {
  late final _value = TextEditingController(text: _toText(widget.current));
  String? _error;

  /// Overtime is edited in hours (1.5 = 1h 30m); the rest in whole units.
  String _toText(int v) {
    if (!widget.figure.isHours) return '$v';
    final h = v / 60;
    return h == h.roundToDouble() ? h.toStringAsFixed(0) : h.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  void _save() {
    final l = AppLocalizations.of(context)!;
    final v = _parseAmount(_value.text);
    if (v == null || v < 0) {
      setState(() => _error = l.invalidAmount);
      return;
    }
    final stored = widget.figure.isHours ? (v * 60).round() : v.round();
    Navigator.pop(context, _FigureResult(value: stored));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final f = widget.figure;
    final unit = f.isDays ? l.daysUnit : (f.isHours ? l.hoursUnit : l.minutes);

    return AlertDialog(
      title: Text(f.label(l)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _value,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: unit,
                errorText: _error,
                helperText: l.clockFigure(f.show(context, widget.clock)),
              ),
              onSubmitted: (_) => _save(),
            ),
            if (f.isDays) ...[
              const SizedBox(height: 12),
              Text(l.excuseHint, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
      actions: [
        if (widget.current != widget.clock)
          TextButton(
            onPressed: () =>
                Navigator.pop(context, const _FigureResult(reset: true)),
            child: Text(l.useClockFigure),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(onPressed: _save, child: Text(l.save)),
      ],
    );
  }
}

class _AdjustmentDialog extends StatefulWidget {
  const _AdjustmentDialog();

  @override
  State<_AdjustmentDialog> createState() => _AdjustmentDialogState();
}

class _AdjustmentDialogState extends State<_AdjustmentDialog> {
  AdjustmentKind _kind = AdjustmentKind.bonus;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _amountError;
  String? _noteError;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final l = AppLocalizations.of(context)!;
    final v = _parseAmount(_amount.text);
    final note = _note.text.trim();
    setState(() {
      _amountError = (v == null || v <= 0) ? l.invalidAmount : null;
      _noteError = note.isEmpty ? l.noteRequired : null;
    });
    if (_amountError != null || _noteError != null) return;
    Navigator.pop(context, PayAdjustment(kind: _kind, amount: v!, note: note));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l.adjustmentsTitle),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<AdjustmentKind>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: AdjustmentKind.bonus,
                  label: Text(l.bonus),
                ),
                ButtonSegment(
                  value: AdjustmentKind.deduction,
                  label: Text(l.deduction),
                ),
                ButtonSegment(
                  value: AdjustmentKind.advance,
                  label: Text(l.advance),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: l.amount,
                errorText: _amountError,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: InputDecoration(
                labelText: l.note,
                errorText: _noteError,
              ),
              onSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(onPressed: _save, child: Text(l.add)),
      ],
    );
  }
}

class _RulesDialog extends StatefulWidget {
  const _RulesDialog({required this.rules, required this.currency});

  final PayRules rules;
  final String currency;

  @override
  State<_RulesDialog> createState() => _RulesDialogState();
}

class _RulesDialogState extends State<_RulesDialog> {
  late final _ot = TextEditingController(text: '${widget.rules.overtimeRate}');
  late final _off = TextEditingController(text: '${widget.rules.dayOffRate}');
  late final _late = TextEditingController(text: '${widget.rules.lateRate}');
  late final _early = TextEditingController(
    text: '${widget.rules.earlyLeaveRate}',
  );
  late final _minOt = TextEditingController(
    text: '${widget.rules.minOvertimeMinutes}',
  );
  late final _currency = TextEditingController(text: widget.currency);
  late bool _absence = widget.rules.deductAbsence;
  bool _invalid = false;

  @override
  void dispose() {
    for (final c in [_ot, _off, _late, _early, _minOt, _currency]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final ot = _parseAmount(_ot.text);
    final off = _parseAmount(_off.text);
    final late = _parseAmount(_late.text);
    final early = _parseAmount(_early.text);
    final minOt = int.tryParse(_minOt.text.trim());
    final values = [ot, off, late, early];
    if (values.any((v) => v == null || v < 0) || minOt == null || minOt < 0) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.pop(context, (
      PayRules(
        overtimeRate: ot!,
        dayOffRate: off!,
        lateRate: late!,
        earlyLeaveRate: early!,
        deductAbsence: _absence,
        minOvertimeMinutes: minOt,
      ),
      _currency.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    Widget rate(TextEditingController c, String label) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          prefixText: '× ',
          errorText: _invalid && (_parseAmount(c.text) ?? -1) < 0
              ? l.invalidAmount
              : null,
        ),
      ),
    );

    return AlertDialog(
      title: Text(l.payRules),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.payRulesHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              rate(_ot, l.overtimeRate),
              rate(_off, l.dayOffRate),
              rate(_late, l.lateRate),
              rate(_early, l.earlyRate),
              Text(l.rateHint, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.deductAbsence),
                value: _absence,
                onChanged: (v) => setState(() => _absence = v),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _minOt,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l.minOvertime,
                  suffixText: l.minutesShort,
                  errorText:
                      _invalid && (int.tryParse(_minOt.text.trim()) ?? -1) < 0
                      ? l.invalidAmount
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _currency,
                decoration: InputDecoration(
                  labelText: l.currency,
                  hintText: l.currencyHint,
                ),
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
        FilledButton(onPressed: _save, child: Text(l.save)),
      ],
    );
  }
}

// --- small pieces -----------------------------------------------------------

class _Banner extends StatelessWidget {
  const _Banner({
    required this.color,
    required this.icon,
    required this.text,
    this.action,
  });

  final Color color;
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
        ?action,
      ],
    ),
  );
}

class _Warning extends StatelessWidget {
  const _Warning(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, size: 18, color: AppTheme.warning),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );
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
      width: 220,
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
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
