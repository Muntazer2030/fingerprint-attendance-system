import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_admin/data/database.dart';
import 'package:attendance_admin/domain/attendance_rules.dart';
import 'package:attendance_admin/domain/timesheet.dart';

/// Things that must not change what an already-finished month says.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  int epoch(DateTime d) => d.toUtc().millisecondsSinceEpoch ~/ 1000;

  Future<int> shift(String name, {int start = 540, int end = 1020}) =>
      db.insertShift(
        ShiftsCompanion.insert(
          name: name,
          startMinute: Value(start),
          endMinute: Value(end),
          daysMask: const Value(0x7F),
        ),
      );

  group('changing shift members from today on', () {
    test('does not rewrite the past for people already on the shift', () async {
      final night = await shift('Night', start: 22 * 60, end: 6 * 60);
      await db.assignShift(
        EmployeeShiftsCompanion.insert(
          employeeId: 1,
          shiftId: night,
          effectiveFrom: epoch(DateTime(2026, 1, 1)),
        ),
      );

      // Add a second person today. Person 1 must keep their January start.
      await db.setShiftMembers(night, {1, 2}, DateTime(2026, 9, 15));

      final rows = await db.allEmployeeShifts();
      final one = rows.where((a) => a.employeeId == 1).single;
      expect(
        one.effectiveFrom,
        epoch(DateTime(2026, 1, 1)),
        reason: 'history rewritten: their start date moved to today',
      );
      expect(one.effectiveTo, isNull);
      expect(
        rows.where((a) => a.employeeId == 2).single.effectiveFrom,
        epoch(DateTime(2026, 9, 15)),
      );
    });

    test(
      'someone taken off a shift keeps it for the days they worked it',
      () async {
        final night = await shift('Night', start: 22 * 60, end: 6 * 60);
        await db.assignShift(
          EmployeeShiftsCompanion.insert(
            employeeId: 1,
            shiftId: night,
            effectiveFrom: epoch(DateTime(2026, 1, 1)),
          ),
        );

        await db.setShiftMembers(night, {}, DateTime(2026, 9, 15));

        final a = (await db.allEmployeeShifts()).single;
        expect(
          a.effectiveTo,
          epoch(DateTime(2026, 9, 14)),
          reason: 'assignment deleted instead of closed at yesterday',
        );
      },
    );

    test('moving someone to another shift ends their old one', () async {
      final early = await shift('Early', start: 360, end: 840);
      final late = await shift('Late', start: 840, end: 1320);
      await db.assignShift(
        EmployeeShiftsCompanion.insert(
          employeeId: 1,
          shiftId: early,
          effectiveFrom: epoch(DateTime(2026, 1, 1)),
        ),
      );

      await db.setShiftMembers(late, {1}, DateTime(2026, 9, 15));

      final repo = TimesheetRepository(db);
      final resolver = await repo.loadResolver(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
      );
      expect(resolver.shiftFor(1, DateTime(2026, 9, 10))?.name, 'Early');
      expect(
        resolver.shiftFor(1, DateTime(2026, 9, 20))?.name,
        'Late',
        reason: 'both shifts open from the same day -- ambiguous',
      );
      expect(await db.currentMembers(early, DateTime(2026, 9, 15)), isEmpty);
    });
  });

  group('the current month, against the clock', () {
    const dayShift = Shift(id: 1, name: 'Day', daysMask: 0x7F);
    final resolver = ShiftResolver(storeDefault: dayShift);

    test('days still to come are not absences', () {
      final sheet = Timesheet.build(
        employeeId: 1,
        name: 'A',
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
        resolver: resolver,
        punches: const [],
        now: DateTime(2026, 9, 10, 12),
      );
      expect(sheet.daysAbsent, 9, reason: 'the 1st to the 9th only');
      expect(
        sheet.days.where((d) => d.status == DayStatus.upcoming).length,
        21,
      );
    });

    test('today is not an absence before the shift has ended', () {
      final sheet = Timesheet.build(
        employeeId: 1,
        name: 'A',
        from: DateTime(2026, 9, 10),
        to: DateTime(2026, 9, 10),
        resolver: resolver,
        punches: const [],
        now: DateTime(2026, 9, 10, 8),
      );
      expect(sheet.days.single.status, DayStatus.upcoming);
    });

    test('clocked in and still at work today is not flagged for review', () {
      final sheet = Timesheet.build(
        employeeId: 1,
        name: 'A',
        from: DateTime(2026, 9, 10),
        to: DateTime(2026, 9, 10),
        resolver: resolver,
        punches: [Punch(at: DateTime(2026, 9, 10, 9, 20), isOut: false)],
        now: DateTime(2026, 9, 10, 13),
      );
      final d = sheet.days.single;
      expect(d.inProgress, isTrue);
      expect(d.needsReview, isFalse);
      expect(d.lateMinutes, 20, reason: 'arrival still counts');
    });

    test('a missing OUT on a past day still needs review', () {
      final sheet = Timesheet.build(
        employeeId: 1,
        name: 'A',
        from: DateTime(2026, 9, 9),
        to: DateTime(2026, 9, 9),
        resolver: resolver,
        punches: [Punch(at: DateTime(2026, 9, 9, 9, 20), isOut: false)],
        now: DateTime(2026, 9, 10, 13),
      );
      final d = sheet.days.single;
      expect(d.status, DayStatus.incomplete);
      expect(d.needsReview, isTrue);
      expect(
        d.firstIn,
        DateTime(2026, 9, 9, 9, 20),
        reason: 'arrival time dropped because there was no OUT',
      );
      expect(d.workedMinutes, 0, reason: 'no minutes are invented');
    });
  });

  test('a removed employee still appears for months they worked', () async {
    await db.upsertEmployee(
      const EmployeesCompanion(
        id: Value(1),
        name: Value('Left in August'),
        removed: Value(true),
      ),
    );
    await db.storePunches([
      PunchesCompanion.insert(
        seq: const Value(1),
        deviceEpoch: epoch(DateTime(2026, 8, 3, 9)),
        employeeId: 1,
        direction: 0,
      ),
    ]);
    final repo = TimesheetRepository(db);
    await repo.ensureDefaultShift();

    final aug = await repo.build(
      from: DateTime(2026, 8, 1),
      to: DateTime(2026, 8, 31),
    );
    final sep = await repo.build(
      from: DateTime(2026, 9, 1),
      to: DateTime(2026, 9, 30),
    );
    expect(aug.map((s) => s.name), ['Left in August']);
    expect(sep, isEmpty);
  });

  test('a corrected punch is found by its corrected time', () async {
    // Recorded on the 1st with a bad clock, corrected to the 20th.
    await db.storePunches([
      PunchesCompanion.insert(
        seq: const Value(1),
        deviceEpoch: epoch(DateTime(2026, 7, 1, 9)),
        employeeId: 1,
        direction: 0,
        correctedEpoch: Value(epoch(DateTime(2026, 9, 20, 9))),
      ),
    ]);
    final rows = await db.punchesBetween(
      epoch(DateTime(2026, 9, 1)),
      epoch(DateTime(2026, 9, 30)),
    );
    expect(rows, hasLength(1));
  });
}
