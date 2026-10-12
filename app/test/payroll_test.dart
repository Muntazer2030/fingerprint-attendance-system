import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_admin/data/database.dart';
import 'package:attendance_admin/domain/attendance_rules.dart';
import 'package:attendance_admin/domain/payroll.dart';
import 'package:attendance_admin/domain/timesheet.dart';

/// June 2026 starts on a Monday and has 22 Mon-Fri working days. Saturday the
/// 6th is a day off under the default shift.
void main() {
  const std = Shift(id: 1, name: 'Store', startMinute: 540, endMinute: 1020);

  /// A punch pair on every weekday of June 2026, 09:00-17:00, except the days
  /// in [skip]. [times] replaces the in/out minutes for given days, and can
  /// add days that are not weekdays.
  List<Punch> june({
    Set<int> skip = const {},
    Map<int, (int, int)> times = const {},
  }) {
    final out = <Punch>[];
    for (var day = 1; day <= 30; day++) {
      final d = DateTime(2026, 6, day);
      final weekday = d.weekday <= 5;
      if (skip.contains(day)) continue;
      if (!weekday && !times.containsKey(day)) continue;
      final (a, b) = times[day] ?? (540, 1020);
      out
        ..add(Punch(at: d.add(Duration(minutes: a)), isOut: false))
        ..add(Punch(at: d.add(Duration(minutes: b)), isOut: true));
    }
    return out;
  }

  EmployeeTimesheet sheet(List<Punch> punches, {Shift shift = std}) =>
      Timesheet.build(
        employeeId: 1,
        name: 'Sara',
        from: DateTime(2026, 6, 1),
        to: DateTime(2026, 6, 30),
        resolver: ShiftResolver(storeDefault: shift),
        punches: punches,
        now: DateTime(2026, 7, 15),
      );

  const monthly = Wage(kind: WageKind.monthly, amount: 3000);
  const rules = PayRules();

  group('monthly salary', () {
    test('a clean month pays the salary exactly', () {
      final p = Payroll.compute(
        sheet: sheet(june()),
        wage: monthly,
        rules: rules,
      );
      expect(p.dayRate, 100); // 3000 / 30
      expect(p.hourRate, 12.5); // 100 / 8h
      expect(p.net, 3000);
      expect(p.daysWorked, 22);
    });

    test('day wage is salary / 30 whatever the month length', () {
      final p = Payroll.compute(
        sheet: sheet(june(skip: {10})),
        wage: monthly,
        rules: rules,
      );
      expect(p.absenceDeduction, 100);
      expect(p.net, 2900);
    });

    test('late minutes are cut per minute at the hourly rate', () {
      // 09:30 arrival: 30 minutes late, past the 10-minute grace.
      final p = Payroll.compute(
        sheet: sheet(june(times: {3: (570, 1020)})),
        wage: monthly,
        rules: rules,
      );
      expect(p.paid.lateMinutes, 30);
      expect(p.lateDeduction, 6.25); // 30 * 12.5 / 60
      expect(p.net, 2993.75);
    });

    test('arriving inside the grace period costs nothing', () {
      final p = Payroll.compute(
        sheet: sheet(june(times: {3: (548, 1020)})),
        wage: monthly,
        rules: rules,
      );
      expect(p.lateDeduction, 0);
    });

    test('the late multiplier scales the cut, and zero turns it off', () {
      final s = sheet(june(times: {3: (570, 1020)}));
      final double2 = Payroll.compute(
        sheet: s,
        wage: monthly,
        rules: const PayRules(lateRate: 2),
      );
      expect(double2.lateDeduction, 12.5);
      final off = Payroll.compute(
        sheet: s,
        wage: monthly,
        rules: const PayRules(lateRate: 0),
      );
      expect(off.lateDeduction, 0);
    });

    test('early leave is cut the same way', () {
      final p = Payroll.compute(
        sheet: sheet(june(times: {4: (540, 960)})), // left at 16:00
        wage: monthly,
        rules: rules,
      );
      expect(p.paid.earlyLeaveMinutes, 60);
      expect(p.earlyLeaveDeduction, 12.5);
    });

    test('overtime is paid at the overtime rate', () {
      final p = Payroll.compute(
        sheet: sheet(june(times: {5: (540, 1080)})), // stayed to 18:00
        wage: monthly,
        rules: rules,
      );
      expect(p.paid.overtimeMinutes, 60);
      expect(p.overtimePay, 18.75); // 1h * 12.5 * 1.5
      expect(p.net, 3018.75);
    });

    test('work on a day off is paid at the day-off rate', () {
      final p = Payroll.compute(
        sheet: sheet(june(times: {6: (600, 720)})), // Saturday, 2 hours
        wage: monthly,
        rules: rules,
      );
      expect(p.paid.dayOffMinutes, 120);
      expect(p.paid.overtimeMinutes, 0);
      expect(p.dayOffPay, 50); // 2h * 12.5 * 2
    });

    test('overtime shorter than the daily minimum is not counted', () {
      final s = sheet(june(times: {5: (540, 1030)})); // 10 minutes over
      final p = Payroll.compute(
        sheet: s,
        wage: monthly,
        rules: const PayRules(minOvertimeMinutes: 15),
      );
      expect(p.paid.overtimeMinutes, 0);
      expect(p.overtimePay, 0);
    });

    test('absences cannot cost more than the salary', () {
      final p = Payroll.compute(
        sheet: sheet(const []),
        wage: monthly,
        rules: rules,
      );
      expect(p.clock.absentDays, 22);
      expect(p.absenceDeduction, 3000);
      expect(p.net, 0);
    });

    test('absences are not cut when the rule is off', () {
      final p = Payroll.compute(
        sheet: sheet(june(skip: {10})),
        wage: monthly,
        rules: const PayRules(deductAbsence: false),
      );
      expect(p.absenceDeduction, 0);
    });
  });

  group('manager edits', () {
    test('excusing an absence removes its cut but keeps the clock figure', () {
      final p = Payroll.compute(
        sheet: sheet(june(skip: {10})),
        wage: monthly,
        rules: rules,
        overrides: const PayOverrides(absentDays: 0),
      );
      expect(p.clock.absentDays, 1);
      expect(p.paid.absentDays, 0);
      expect(p.absenceDeduction, 0);
      expect(p.edited, isTrue);
    });

    test('overtime hours can be replaced', () {
      final p = Payroll.compute(
        sheet: sheet(june(times: {5: (540, 1080)})),
        wage: monthly,
        rules: rules,
        overrides: const PayOverrides(overtimeMinutes: 120),
      );
      expect(p.clock.overtimeMinutes, 60);
      expect(p.overtimePay, 37.5);
    });

    test('bonuses add, deductions and advances subtract', () {
      final p = Payroll.compute(
        sheet: sheet(june()),
        wage: monthly,
        rules: rules,
        adjustments: const [
          PayAdjustment(kind: AdjustmentKind.bonus, amount: 200, note: 'Eid'),
          PayAdjustment(kind: AdjustmentKind.deduction, amount: 50, note: 'x'),
          PayAdjustment(kind: AdjustmentKind.advance, amount: 500, note: 'y'),
        ],
      );
      expect(p.bonuses, 200);
      expect(p.deductions, 50);
      expect(p.advances, 500);
      expect(p.net, 2650);
    });
  });

  group('daily and hourly wages', () {
    test('daily staff are paid per scheduled day attended', () {
      final p = Payroll.compute(
        sheet: sheet(june(skip: {10, 11})),
        wage: const Wage(kind: WageKind.daily, amount: 120),
        rules: rules,
      );
      expect(p.daysWorked, 20);
      expect(p.basePay, 2400);
      expect(p.absenceDeduction, 0, reason: 'unpaid already, not cut twice');
    });

    test('excusing a daily worker\'s absence pays that day', () {
      final p = Payroll.compute(
        sheet: sheet(june(skip: {10, 11})),
        wage: const Wage(kind: WageKind.daily, amount: 120),
        rules: rules,
        overrides: const PayOverrides(absentDays: 1),
      );
      expect(p.basePay, 2520);
    });

    test('hourly staff are paid for minutes worked, with no late cut', () {
      final p = Payroll.compute(
        sheet: sheet(june(times: {3: (600, 1020), 5: (540, 1080)})),
        wage: const Wage(kind: WageKind.hourly, amount: 10),
        rules: rules,
      );
      // 22 days * 8h, minus 1h late on the 3rd; the extra hour on the 5th is
      // overtime and paid separately.
      expect(p.regularMinutes, 22 * 480 - 60);
      expect(p.basePay, 1750);
      expect(p.lateDeduction, 0);
      expect(p.overtimePay, 15);
    });
  });

  test('no wage set pays nothing but still shows the figures', () {
    final p = Payroll.compute(
      sheet: sheet(june(skip: {10})),
      wage: null,
      rules: rules,
    );
    expect(p.hasWage, isFalse);
    expect(p.net, 0);
    expect(p.clock.absentDays, 1);
  });

  test('the usual day length comes from the most common shift', () {
    const short = Shift(id: 2, name: 'Short', startMinute: 540, endMinute: 900);
    final p = Payroll.compute(
      sheet: sheet(june(), shift: short),
      wage: monthly,
      rules: rules,
    );
    expect(p.standardDayMinutes, 360);
    expect(p.hourRate, 16.67);
  });

  test('a payslip survives the snapshot round trip unchanged', () {
    final p = Payroll.compute(
      sheet: sheet(june(skip: {10}, times: {3: (570, 1080)})),
      wage: monthly,
      rules: rules,
      overrides: const PayOverrides(lateMinutes: 0),
      adjustments: const [
        PayAdjustment(kind: AdjustmentKind.bonus, amount: 75.5, note: 'شكرا'),
      ],
    );
    final m = PayrollMonth(month: DateTime(2026, 6), slips: [p], rules: rules);
    final back = PayrollMonth.fromSnapshot(
      DateTime(2026, 6),
      DateTime(2026, 7, 1),
      m.toSnapshot('EGP'),
    );
    final q = back.slips.single;
    expect(back.currency, 'EGP');
    expect(q.net, p.net);
    expect(q.toJson(), p.toJson());
  });

  group('stored payroll', () {
    late AppDatabase db;
    late PayrollRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = PayrollRepository(db);
    });
    tearDown(() => db.close());

    int epoch(DateTime d) => d.toUtc().millisecondsSinceEpoch ~/ 1000;

    Future<void> seed() async {
      await db.upsertEmployee(
        EmployeesCompanion.insert(
          id: const Value(1),
          name: const Value('Sara'),
        ),
      );
      await db.insertShift(
        ShiftsCompanion.insert(name: 'Store', isDefault: const Value(true)),
      );
      var seq = 1;
      await db.storePunches([
        for (final p in june())
          PunchesCompanion.insert(
            seq: Value(seq++),
            deviceEpoch: epoch(p.at),
            employeeId: 1,
            direction: p.isOut ? 1 : 0,
          ),
      ]);
    }

    test('a raise applies from its month on, not before', () async {
      await seed();
      await repo.setWage(1, DateTime(2026, 6), monthly);
      await repo.setWage(
        1,
        DateTime(2026, 8),
        const Wage(kind: WageKind.monthly, amount: 3600),
      );
      final wages = await db.allWages();
      expect(PayrollRepository.wageFor(wages, 1, 202605), isNull);
      expect(PayrollRepository.wageFor(wages, 1, 202607)!.amount, 3000);
      expect(PayrollRepository.wageFor(wages, 1, 202609)!.amount, 3600);
    });

    test('rules round-trip through storage', () async {
      const r = PayRules(
        overtimeRate: 1.35,
        dayOffRate: 1.7,
        lateRate: 0,
        earlyLeaveRate: 0.5,
        deductAbsence: false,
        minOvertimeMinutes: 15,
      );
      await repo.saveRules(r);
      expect((await repo.rules()).toJson(), r.toJson());
    });

    test('a paid month is frozen against later corrections', () async {
      await seed();
      await repo.setWage(1, DateTime(2026, 6), monthly);
      final before = await repo.load(DateTime(2026, 6));
      expect(before.slips.single.net, 3000);
      await repo.markPaid(before, 'EGP');

      // Delete a day's punches and change the wage after paying.
      final rows = await db.punchesBetween(
        epoch(DateTime(2026, 6, 10)),
        epoch(DateTime(2026, 6, 11)),
      );
      for (final r in rows) {
        await (db.delete(db.punches)..where((t) => t.seq.equals(r.seq))).go();
      }

      final after = await repo.load(DateTime(2026, 6));
      expect(after.isPaid, isTrue);
      expect(after.slips.single.net, 3000);

      // Reopened, it recomputes from current data.
      await repo.reopen(DateTime(2026, 6));
      final live = await repo.load(DateTime(2026, 6));
      expect(live.isPaid, isFalse);
      expect(live.slips.single.net, 2900);
    });

    test('a paid month refuses edits', () async {
      await seed();
      await repo.setWage(1, DateTime(2026, 6), monthly);
      await repo.markPaid(await repo.load(DateTime(2026, 6)), 'EGP');
      expect(
        () => repo.addAdjustment(
          1,
          DateTime(2026, 6),
          const PayAdjustment(
            kind: AdjustmentKind.bonus,
            amount: 1,
            note: 'late',
          ),
        ),
        throwsA(isA<MonthClosedException>()),
      );
      expect(
        () => repo.setWage(1, DateTime(2026, 6), monthly),
        throwsA(isA<MonthClosedException>()),
      );
    });

    test('edits and adjustments are loaded into the month', () async {
      await seed();
      await repo.setWage(1, DateTime(2026, 6), monthly);
      await repo.setOverrides(
        1,
        DateTime(2026, 6),
        const PayOverrides(overtimeMinutes: 60),
      );
      await repo.addAdjustment(
        1,
        DateTime(2026, 6),
        const PayAdjustment(
          kind: AdjustmentKind.advance,
          amount: 250,
          note: 'advance',
        ),
      );
      final m = await repo.load(DateTime(2026, 6));
      final s = m.slips.single;
      expect(s.overtimePay, 18.75);
      expect(s.advances, 250);
      expect(s.net, 2768.75);

      final adj = s.adjustments.single;
      await repo.removeAdjustment(1, DateTime(2026, 6), adj);
      expect((await repo.load(DateTime(2026, 6))).slips.single.advances, 0);
    });
  });
}
