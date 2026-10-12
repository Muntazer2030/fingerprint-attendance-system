/// Turns a month's timesheet into pay.
///
/// Same split as the timesheet: [Payroll.compute] is pure and takes plain data,
/// [PayrollRepository] reads and writes the database. Every amount on a payslip
/// can be traced to a timesheet figure, a wage, a rule, or a manager's edit --
/// and a manager's edit always keeps the clock figure beside it.
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../data/database.dart';
import 'attendance_rules.dart';
import 'timesheet.dart';

enum WageKind { monthly, daily, hourly }

class Wage {
  const Wage({required this.kind, required this.amount});

  final WageKind kind;

  /// In whole currency units: the month's salary, the day's wage, or the
  /// hour's rate, depending on [kind].
  final double amount;
}

/// Store-wide pay policy. Multipliers apply to the employee's hourly rate.
class PayRules {
  const PayRules({
    this.overtimeRate = 1.5,
    this.dayOffRate = 2.0,
    this.lateRate = 1.0,
    this.earlyLeaveRate = 1.0,
    this.deductAbsence = true,
    this.minOvertimeMinutes = 0,
  });

  /// Overtime on a scheduled day.
  final double overtimeRate;

  /// Any time worked on a day the employee was not scheduled.
  final double dayOffRate;

  /// Each late minute costs this many minutes of pay. Zero turns it off. The
  /// shift's grace period already decides whether a day counts as late at all.
  final double lateRate;
  final double earlyLeaveRate;

  /// Monthly staff lose a day's wage per unexcused absence.
  final bool deductAbsence;

  /// Overtime shorter than this on a given day is not counted as overtime --
  /// leaving three minutes after closing should not add up to a pay rise.
  final int minOvertimeMinutes;

  /// A monthly salary divided by this gives the day wage, whatever the length
  /// of the month (decision D13).
  static const monthDays = 30;

  Map<String, Object?> toJson() => {
    'overtimeRate': overtimeRate,
    'dayOffRate': dayOffRate,
    'lateRate': lateRate,
    'earlyLeaveRate': earlyLeaveRate,
    'deductAbsence': deductAbsence,
    'minOvertimeMinutes': minOvertimeMinutes,
  };

  factory PayRules.fromJson(Map<String, Object?> j) => PayRules(
    overtimeRate: (j['overtimeRate'] as num).toDouble(),
    dayOffRate: (j['dayOffRate'] as num).toDouble(),
    lateRate: (j['lateRate'] as num).toDouble(),
    earlyLeaveRate: (j['earlyLeaveRate'] as num).toDouble(),
    deductAbsence: j['deductAbsence'] as bool,
    minOvertimeMinutes: j['minOvertimeMinutes'] as int,
  );
}

enum AdjustmentKind { bonus, deduction, advance }

/// A one-off amount for one employee in one month, entered by the manager.
class PayAdjustment {
  const PayAdjustment({
    this.id,
    required this.kind,
    required this.amount,
    required this.note,
  });

  final int? id;
  final AdjustmentKind kind;

  /// Always positive; [kind] says which way it goes.
  final double amount;
  final String note;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'amount': amount,
    'note': note,
  };

  factory PayAdjustment.fromJson(Map<String, Object?> j) => PayAdjustment(
    kind: AdjustmentKind.values.byName(j['kind'] as String),
    amount: (j['amount'] as num).toDouble(),
    note: j['note'] as String,
  );
}

/// The figures pay is calculated from. Kept twice on every payslip: as the
/// clock measured them, and as actually paid after the manager's edits.
class PayFigures {
  const PayFigures({
    required this.overtimeMinutes,
    required this.dayOffMinutes,
    required this.lateMinutes,
    required this.earlyLeaveMinutes,
    required this.absentDays,
  });

  final int overtimeMinutes;
  final int dayOffMinutes;
  final int lateMinutes;
  final int earlyLeaveMinutes;
  final int absentDays;

  Map<String, Object?> toJson() => {
    'overtimeMinutes': overtimeMinutes,
    'dayOffMinutes': dayOffMinutes,
    'lateMinutes': lateMinutes,
    'earlyLeaveMinutes': earlyLeaveMinutes,
    'absentDays': absentDays,
  };

  factory PayFigures.fromJson(Map<String, Object?> j) => PayFigures(
    overtimeMinutes: j['overtimeMinutes'] as int,
    dayOffMinutes: j['dayOffMinutes'] as int,
    lateMinutes: j['lateMinutes'] as int,
    earlyLeaveMinutes: j['earlyLeaveMinutes'] as int,
    absentDays: j['absentDays'] as int,
  );
}

/// A manager's replacement for clock figures. Null keeps the clock's value.
class PayOverrides {
  const PayOverrides({
    this.overtimeMinutes,
    this.dayOffMinutes,
    this.lateMinutes,
    this.earlyLeaveMinutes,
    this.absentDays,
  });

  static const none = PayOverrides();

  final int? overtimeMinutes;
  final int? dayOffMinutes;
  final int? lateMinutes;
  final int? earlyLeaveMinutes;

  /// Lower than the clock's count to excuse an absence (sick leave, say).
  final int? absentDays;

  PayFigures applyTo(PayFigures clock) => PayFigures(
    overtimeMinutes: overtimeMinutes ?? clock.overtimeMinutes,
    dayOffMinutes: dayOffMinutes ?? clock.dayOffMinutes,
    lateMinutes: lateMinutes ?? clock.lateMinutes,
    earlyLeaveMinutes: earlyLeaveMinutes ?? clock.earlyLeaveMinutes,
    absentDays: absentDays ?? clock.absentDays,
  );
}

class Payslip {
  const Payslip({
    required this.employeeId,
    required this.name,
    required this.wage,
    required this.dayRate,
    required this.hourRate,
    required this.standardDayMinutes,
    required this.daysWorked,
    required this.regularMinutes,
    required this.clock,
    required this.paid,
    required this.basePay,
    required this.overtimePay,
    required this.dayOffPay,
    required this.lateDeduction,
    required this.earlyLeaveDeduction,
    required this.absenceDeduction,
    required this.adjustments,
    required this.daysNeedingReview,
  });

  final int employeeId;
  final String name;

  /// Null when no wage has been set; every amount is then zero.
  final Wage? wage;

  final double dayRate;
  final double hourRate;

  /// The usual length of this employee's working day, used to turn a day
  /// wage into an hourly rate.
  final int standardDayMinutes;

  final int daysWorked;

  /// Hourly staff: the ordinary (non-overtime) minutes they are paid for.
  final int regularMinutes;

  final PayFigures clock;
  final PayFigures paid;

  final double basePay;
  final double overtimePay;
  final double dayOffPay;
  final double lateDeduction;
  final double earlyLeaveDeduction;
  final double absenceDeduction;
  final List<PayAdjustment> adjustments;

  final int daysNeedingReview;

  double _sum(AdjustmentKind k) => _round(
    adjustments.where((a) => a.kind == k).fold(0.0, (n, a) => n + a.amount),
  );

  double get bonuses => _sum(AdjustmentKind.bonus);
  double get deductions => _sum(AdjustmentKind.deduction);
  double get advances => _sum(AdjustmentKind.advance);

  double get additions => _round(overtimePay + dayOffPay + bonuses);
  double get cuts => _round(
    lateDeduction +
        earlyLeaveDeduction +
        absenceDeduction +
        deductions +
        advances,
  );

  double get net => _round(basePay + additions - cuts);

  bool get hasWage => wage != null;

  /// True when the manager changed any clock figure.
  bool get edited =>
      clock.overtimeMinutes != paid.overtimeMinutes ||
      clock.dayOffMinutes != paid.dayOffMinutes ||
      clock.lateMinutes != paid.lateMinutes ||
      clock.earlyLeaveMinutes != paid.earlyLeaveMinutes ||
      clock.absentDays != paid.absentDays;

  Map<String, Object?> toJson() => {
    'employeeId': employeeId,
    'name': name,
    'wageKind': wage?.kind.name,
    'wageAmount': wage?.amount,
    'dayRate': dayRate,
    'hourRate': hourRate,
    'standardDayMinutes': standardDayMinutes,
    'daysWorked': daysWorked,
    'regularMinutes': regularMinutes,
    'clock': clock.toJson(),
    'paid': paid.toJson(),
    'basePay': basePay,
    'overtimePay': overtimePay,
    'dayOffPay': dayOffPay,
    'lateDeduction': lateDeduction,
    'earlyLeaveDeduction': earlyLeaveDeduction,
    'absenceDeduction': absenceDeduction,
    'adjustments': [for (final a in adjustments) a.toJson()],
    'daysNeedingReview': daysNeedingReview,
  };

  factory Payslip.fromJson(Map<String, Object?> j) {
    double d(String k) => (j[k] as num).toDouble();
    final kind = j['wageKind'] as String?;
    return Payslip(
      employeeId: j['employeeId'] as int,
      name: j['name'] as String,
      wage: kind == null
          ? null
          : Wage(kind: WageKind.values.byName(kind), amount: d('wageAmount')),
      dayRate: d('dayRate'),
      hourRate: d('hourRate'),
      standardDayMinutes: j['standardDayMinutes'] as int,
      daysWorked: j['daysWorked'] as int,
      regularMinutes: j['regularMinutes'] as int,
      clock: PayFigures.fromJson(j['clock'] as Map<String, Object?>),
      paid: PayFigures.fromJson(j['paid'] as Map<String, Object?>),
      basePay: d('basePay'),
      overtimePay: d('overtimePay'),
      dayOffPay: d('dayOffPay'),
      lateDeduction: d('lateDeduction'),
      earlyLeaveDeduction: d('earlyLeaveDeduction'),
      absenceDeduction: d('absenceDeduction'),
      adjustments: [
        for (final a in j['adjustments'] as List)
          PayAdjustment.fromJson(a as Map<String, Object?>),
      ],
      daysNeedingReview: j['daysNeedingReview'] as int,
    );
  }
}

/// Money to two decimal places. Each line is rounded on its own and the net
/// is the sum of rounded lines, so the payslip always adds up on paper.
double _round(double v) => (v * 100).roundToDouble() / 100;

class Payroll {
  const Payroll._();

  /// Fallback working day when the employee has no scheduled day in the month.
  static const defaultDayMinutes = 480;

  static Payslip compute({
    required EmployeeTimesheet sheet,
    required Wage? wage,
    required PayRules rules,
    PayOverrides overrides = PayOverrides.none,
    List<PayAdjustment> adjustments = const [],
  }) {
    final dayMinutes = standardDayMinutes(sheet.days);

    var overtime = 0;
    var dayOff = 0;
    var regular = 0;
    var daysWorked = 0;

    for (final d in sheet.days) {
      final counts = d.overtimeMinutes >= rules.minOvertimeMinutes;
      if (d.shift == null) {
        // Unscheduled: every minute is day-off work, unless too short to count,
        // in which case an hourly worker is still paid for it as ordinary time.
        if (counts) {
          dayOff += d.workedMinutes;
        } else {
          regular += d.workedMinutes;
        }
        continue;
      }
      if (d.status == DayStatus.present || d.status == DayStatus.incomplete) {
        daysWorked++;
      }
      final ot = counts ? d.overtimeMinutes : 0;
      overtime += ot;
      regular += d.workedMinutes - ot;
    }

    final clock = PayFigures(
      overtimeMinutes: overtime,
      dayOffMinutes: dayOff,
      lateMinutes: sheet.lateMinutes,
      earlyLeaveMinutes: sheet.earlyLeaveMinutes,
      absentDays: sheet.daysAbsent,
    );
    final paid = overrides.applyTo(clock);

    if (wage == null) {
      return Payslip(
        employeeId: sheet.employeeId,
        name: sheet.name,
        wage: null,
        dayRate: 0,
        hourRate: 0,
        standardDayMinutes: dayMinutes,
        daysWorked: daysWorked,
        regularMinutes: regular,
        clock: clock,
        paid: paid,
        basePay: 0,
        overtimePay: 0,
        dayOffPay: 0,
        lateDeduction: 0,
        earlyLeaveDeduction: 0,
        absenceDeduction: 0,
        adjustments: adjustments,
        daysNeedingReview: sheet.daysNeedingReview,
      );
    }

    final hours = dayMinutes / 60;
    final (dayRate, hourRate) = switch (wage.kind) {
      WageKind.monthly => (
        wage.amount / PayRules.monthDays,
        wage.amount / PayRules.monthDays / hours,
      ),
      WageKind.daily => (wage.amount, wage.amount / hours),
      WageKind.hourly => (wage.amount * hours, wage.amount),
    };
    final minuteRate = hourRate / 60;

    late double base;
    var late = 0.0;
    var early = 0.0;
    var absence = 0.0;

    switch (wage.kind) {
      case WageKind.monthly:
        base = wage.amount;
        late = paid.lateMinutes * minuteRate * rules.lateRate;
        early = paid.earlyLeaveMinutes * minuteRate * rules.earlyLeaveRate;
        if (rules.deductAbsence) {
          // A month of absences cannot cost more than the month's salary.
          absence = (paid.absentDays * dayRate).clamp(0, base);
          // Salary / 30 pays the weekends too, so someone absent on every
          // working day would still be owed them. Nobody gets paid for a
          // finished month they never came in -- unless the manager excused
          // some of it.
          final monthOver = sheet.days.every(
            (d) => d.status != DayStatus.upcoming,
          );
          if (monthOver &&
              daysWorked == 0 &&
              clock.absentDays > 0 &&
              paid.absentDays >= clock.absentDays) {
            absence = base;
          }
        }
      case WageKind.daily:
        // Paid per scheduled day attended. Excusing an absence (paid figure
        // below the clock's) pays that day as well.
        final excused = (clock.absentDays - paid.absentDays).clamp(0, 1 << 30);
        base = dayRate * (daysWorked + excused);
        late = paid.lateMinutes * minuteRate * rules.lateRate;
        early = paid.earlyLeaveMinutes * minuteRate * rules.earlyLeaveRate;
      case WageKind.hourly:
        // Minutes not worked were never paid, so there is nothing to deduct
        // for lateness or absence -- doing so would charge for them twice.
        base = regular * minuteRate;
    }

    return Payslip(
      employeeId: sheet.employeeId,
      name: sheet.name,
      wage: wage,
      dayRate: _round(dayRate),
      hourRate: _round(hourRate),
      standardDayMinutes: dayMinutes,
      daysWorked: daysWorked,
      regularMinutes: regular,
      clock: clock,
      paid: paid,
      basePay: _round(base),
      overtimePay: _round(
        paid.overtimeMinutes * minuteRate * rules.overtimeRate,
      ),
      dayOffPay: _round(paid.dayOffMinutes * minuteRate * rules.dayOffRate),
      lateDeduction: _round(late),
      earlyLeaveDeduction: _round(early),
      absenceDeduction: _round(absence),
      adjustments: adjustments,
      daysNeedingReview: sheet.daysNeedingReview,
    );
  }

  /// The most common scheduled day length in the month. Someone mostly on an
  /// eight-hour shift with the odd short day is still an eight-hour worker.
  static int standardDayMinutes(List<DayResult> days) {
    final counts = <int, int>{};
    for (final d in days) {
      final s = d.shift;
      if (s == null) continue;
      final m = s.kind == ShiftKind.flexible
          ? s.requiredMinutes
          : s.scheduledMinutes;
      if (m <= 0) continue;
      counts[m] = (counts[m] ?? 0) + 1;
    }
    if (counts.isEmpty) return defaultDayMinutes;
    return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }
}

/// One month's payroll, either live or as frozen when it was marked paid.
class PayrollMonth {
  const PayrollMonth({
    required this.month,
    required this.slips,
    required this.rules,
    this.paidAt,
    this.currency,
  });

  final DateTime month;
  final List<Payslip> slips;
  final PayRules rules;

  /// Set once the month is marked paid; its figures are then a snapshot.
  final DateTime? paidAt;

  /// The currency label at the time of payment. Null for a live month.
  final String? currency;

  bool get isPaid => paidAt != null;

  double _total(double Function(Payslip) f) =>
      _round(slips.fold(0.0, (n, s) => n + f(s)));

  double get totalNet => _total((s) => s.net);
  double get totalBase => _total((s) => s.basePay);
  double get totalAdditions => _total((s) => s.additions);
  double get totalCuts => _total((s) => s.cuts);
  int get withoutWage => slips.where((s) => !s.hasWage).length;
  int get daysNeedingReview => slips.fold(0, (n, s) => n + s.daysNeedingReview);

  String toSnapshot(String currency) => jsonEncode({
    'version': 1,
    'currency': currency,
    'rules': rules.toJson(),
    'slips': [for (final s in slips) s.toJson()],
  });

  factory PayrollMonth.fromSnapshot(
    DateTime month,
    DateTime paidAt,
    String json,
  ) {
    final j = jsonDecode(json) as Map<String, Object?>;
    return PayrollMonth(
      month: month,
      paidAt: paidAt,
      currency: j['currency'] as String,
      rules: PayRules.fromJson(j['rules'] as Map<String, Object?>),
      slips: [
        for (final s in j['slips'] as List)
          Payslip.fromJson(s as Map<String, Object?>),
      ],
    );
  }
}

/// Raised when something tries to change a month that has been paid.
class MonthClosedException implements Exception {
  const MonthClosedException();
  @override
  String toString() => 'This month has been paid. Reopen it to make changes.';
}

/// Loads and saves everything payroll needs.
class PayrollRepository {
  PayrollRepository(this.db);

  final AppDatabase db;

  /// yyyymm.
  static int monthKey(DateTime m) => m.year * 100 + m.month;

  static int _cents(double v) => (v * 100).round();
  static double _units(int cents) => cents / 100;

  // --- rules ---------------------------------------------------------------

  // Stored as hundredths in Meta, which only holds integers.
  static const _kOt = 'pay.overtime_rate_x100';
  static const _kOff = 'pay.dayoff_rate_x100';
  static const _kLate = 'pay.late_rate_x100';
  static const _kEarly = 'pay.early_rate_x100';
  static const _kAbsence = 'pay.deduct_absence';
  static const _kMinOt = 'pay.min_overtime_minutes';

  Future<PayRules> rules() async {
    const d = PayRules();
    Future<double> rate(String k, double fallback) async {
      final v = await db.metaInt(k);
      return v == null ? fallback : v / 100;
    }

    return PayRules(
      overtimeRate: await rate(_kOt, d.overtimeRate),
      dayOffRate: await rate(_kOff, d.dayOffRate),
      lateRate: await rate(_kLate, d.lateRate),
      earlyLeaveRate: await rate(_kEarly, d.earlyLeaveRate),
      deductAbsence: (await db.metaInt(_kAbsence) ?? 1) != 0,
      minOvertimeMinutes: await db.metaInt(_kMinOt) ?? d.minOvertimeMinutes,
    );
  }

  Future<void> saveRules(PayRules r) async {
    await db.transaction(() async {
      await db.setMetaInt(_kOt, _cents(r.overtimeRate));
      await db.setMetaInt(_kOff, _cents(r.dayOffRate));
      await db.setMetaInt(_kLate, _cents(r.lateRate));
      await db.setMetaInt(_kEarly, _cents(r.earlyLeaveRate));
      await db.setMetaInt(_kAbsence, r.deductAbsence ? 1 : 0);
      await db.setMetaInt(_kMinOt, r.minOvertimeMinutes);
    });
    await db.audit('pay_rules', detail: jsonEncode(r.toJson()));
  }

  // --- the month -------------------------------------------------------------

  Future<PayrollMonth> load(DateTime month, {DateTime? now}) async {
    final key = monthKey(month);
    final run = await db.payrollRun(key);
    if (run != null) {
      return PayrollMonth.fromSnapshot(
        month,
        DateTime.fromMillisecondsSinceEpoch(run.paidEpoch * 1000),
        run.snapshot,
      );
    }

    final timesheets = TimesheetRepository(db);
    await timesheets.ensureDefaultShift();
    final sheets = await timesheets.build(
      from: DateTime(month.year, month.month, 1),
      to: DateTime(month.year, month.month + 1, 0),
    );

    final rules = await this.rules();
    final wages = await db.allWages();
    final overrides = {
      for (final o in await db.payEditsFor(key)) o.employeeId: o,
    };
    final adjustments = <int, List<PayAdjustment>>{};
    for (final a in await db.payAdjustmentsFor(key)) {
      adjustments
          .putIfAbsent(a.employeeId, () => [])
          .add(
            PayAdjustment(
              id: a.id,
              kind: AdjustmentKind.values[a.kind],
              amount: _units(a.amountCents),
              note: a.note,
            ),
          );
    }

    return PayrollMonth(
      month: month,
      rules: rules,
      slips: [
        for (final s in sheets)
          Payroll.compute(
            sheet: s,
            wage: wageFor(wages, s.employeeId, key),
            rules: rules,
            overrides: _toOverrides(overrides[s.employeeId]),
            adjustments: adjustments[s.employeeId] ?? const [],
          ),
      ],
    );
  }

  /// The wage in force for [monthKey]: the latest one starting on or before it.
  static Wage? wageFor(List<WageRow> all, int employeeId, int monthKey) {
    WageRow? best;
    for (final w in all) {
      if (w.employeeId != employeeId || w.fromMonth > monthKey) continue;
      if (best == null || w.fromMonth > best.fromMonth) best = w;
    }
    if (best == null) return null;
    return Wage(
      kind: WageKind.values[best.kind],
      amount: _units(best.amountCents),
    );
  }

  static PayOverrides _toOverrides(PayEditRow? r) => r == null
      ? PayOverrides.none
      : PayOverrides(
          overtimeMinutes: r.overtimeMinutes,
          dayOffMinutes: r.dayOffMinutes,
          lateMinutes: r.lateMinutes,
          earlyLeaveMinutes: r.earlyLeaveMinutes,
          absentDays: r.absentDays,
        );

  Future<void> _ensureOpen(int key) async {
    if (await db.payrollRun(key) != null) throw const MonthClosedException();
  }

  // --- edits -----------------------------------------------------------------

  /// Sets a wage from [month] onward. Earlier months keep the wage they had.
  Future<void> setWage(int employeeId, DateTime month, Wage wage) async {
    final key = monthKey(month);
    await _ensureOpen(key);
    await db.setWage(
      WagesCompanion.insert(
        employeeId: employeeId,
        fromMonth: key,
        kind: wage.kind.index,
        amountCents: _cents(wage.amount),
      ),
    );
    await db.audit(
      'wage_set',
      employeeId: employeeId,
      detail: 'from $key: ${wage.kind.name} ${wage.amount}',
    );
  }

  Future<void> setOverrides(
    int employeeId,
    DateTime month,
    PayOverrides o,
  ) async {
    final key = monthKey(month);
    await _ensureOpen(key);
    await db.setPayEdit(
      PayEditsCompanion.insert(
        employeeId: employeeId,
        monthKey: key,
        overtimeMinutes: Value(o.overtimeMinutes),
        dayOffMinutes: Value(o.dayOffMinutes),
        lateMinutes: Value(o.lateMinutes),
        earlyLeaveMinutes: Value(o.earlyLeaveMinutes),
        absentDays: Value(o.absentDays),
      ),
    );
    await db.audit(
      'pay_override',
      employeeId: employeeId,
      detail:
          '$key: ot=${o.overtimeMinutes} off=${o.dayOffMinutes} '
          'late=${o.lateMinutes} early=${o.earlyLeaveMinutes} '
          'absent=${o.absentDays}',
    );
  }

  Future<void> addAdjustment(
    int employeeId,
    DateTime month,
    PayAdjustment a,
  ) async {
    final key = monthKey(month);
    await _ensureOpen(key);
    await db.addPayAdjustment(
      PayAdjustmentsCompanion.insert(
        employeeId: employeeId,
        monthKey: key,
        kind: a.kind.index,
        amountCents: _cents(a.amount),
        note: Value(a.note),
        atEpoch: DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
      ),
    );
    await db.audit(
      'pay_adjustment_add',
      employeeId: employeeId,
      detail: '$key: ${a.kind.name} ${a.amount} ${a.note}',
    );
  }

  Future<void> removeAdjustment(
    int employeeId,
    DateTime month,
    PayAdjustment a,
  ) async {
    final key = monthKey(month);
    await _ensureOpen(key);
    if (a.id == null) return;
    await db.deletePayAdjustment(a.id!);
    await db.audit(
      'pay_adjustment_remove',
      employeeId: employeeId,
      detail: '$key: ${a.kind.name} ${a.amount} ${a.note}',
    );
  }

  // --- closing ---------------------------------------------------------------

  /// Freezes the month as computed now. Later corrections to punches, wages or
  /// rules no longer change what these people were paid.
  Future<void> markPaid(PayrollMonth m, String currency) async {
    final key = monthKey(m.month);
    await _ensureOpen(key);
    await db.savePayrollRun(
      PayrollRunsCompanion.insert(
        monthKey: Value(key),
        paidEpoch: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        snapshot: m.toSnapshot(currency),
      ),
    );
    await db.audit('payroll_paid', detail: '$key net ${m.totalNet}');
  }

  /// Unfreezes a paid month. The month is recomputed live from then on.
  Future<void> reopen(DateTime month) async {
    final key = monthKey(month);
    await db.deletePayrollRun(key);
    await db.audit('payroll_reopened', detail: '$key');
  }
}
