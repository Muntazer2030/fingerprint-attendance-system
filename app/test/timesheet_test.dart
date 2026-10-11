import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_admin/domain/attendance_rules.dart';
import 'package:attendance_admin/domain/timesheet.dart';

void main() {
  const nineToFive = Shift(
    id: 1,
    name: '09:00-17:00',
    startMinute: 9 * 60,
    endMinute: 17 * 60,
    daysMask: 0x3E, // Mon-Fri
  );

  Punch inAt(DateTime t) => Punch(at: t, isOut: false);
  Punch outAt(DateTime t) => Punch(at: t, isOut: true);

  EmployeeTimesheet build({
    required DateTime from,
    required DateTime to,
    required List<Punch> punches,
    ShiftResolver? resolver,
  }) =>
      Timesheet.build(
        employeeId: 1,
        name: 'Ahmed',
        from: from,
        to: to,
        resolver: resolver ?? ShiftResolver(storeDefault: nineToFive),
        punches: punches,
      );

  test('covers every day in the range, including weekends', () {
    // Mon 24 Aug .. Sun 30 Aug 2026
    final sheet = build(
      from: DateTime(2026, 8, 24),
      to: DateTime(2026, 8, 30),
      punches: const [],
    );

    expect(sheet.days.length, 7);
    expect(sheet.days.where((d) => d.status == DayStatus.off).length, 2);
    expect(sheet.daysAbsent, 5);
  });

  test('totals across a working week', () {
    final punches = <Punch>[];
    for (var i = 0; i < 5; i++) {
      final d = DateTime(2026, 8, 24 + i);
      punches.add(inAt(DateTime(d.year, d.month, d.day, 9, 0)));
      punches.add(outAt(DateTime(d.year, d.month, d.day, 17, 0)));
    }

    final sheet = build(
      from: DateTime(2026, 8, 24),
      to: DateTime(2026, 8, 28),
      punches: punches,
    );

    expect(sheet.daysPresent, 5);
    expect(sheet.workedMinutes, 5 * 8 * 60);
    expect(sheet.lateMinutes, 0);
    expect(sheet.daysNeedingReview, 0);
  });

  test('lateness is summed and counted separately from occasions', () {
    final punches = [
      // Mon: 30 late. Tue: on time. Wed: 15 late.
      inAt(DateTime(2026, 8, 24, 9, 30)),
      outAt(DateTime(2026, 8, 24, 17, 0)),
      inAt(DateTime(2026, 8, 25, 9, 0)),
      outAt(DateTime(2026, 8, 25, 17, 0)),
      inAt(DateTime(2026, 8, 26, 9, 15)),
      outAt(DateTime(2026, 8, 26, 17, 0)),
    ];

    final sheet = build(
      from: DateTime(2026, 8, 24),
      to: DateTime(2026, 8, 26),
      punches: punches,
    );

    expect(sheet.lateMinutes, 45);
    expect(sheet.lateOccasions, 2);
  });

  test('punches are attributed to their own day, not leaked between days', () {
    final punches = [
      inAt(DateTime(2026, 8, 24, 9, 0)),
      outAt(DateTime(2026, 8, 24, 17, 0)),
      inAt(DateTime(2026, 8, 25, 9, 0)),
      outAt(DateTime(2026, 8, 25, 17, 0)),
    ];

    final sheet = build(
      from: DateTime(2026, 8, 24),
      to: DateTime(2026, 8, 25),
      punches: punches,
    );

    expect(sheet.days[0].workedMinutes, 8 * 60);
    expect(sheet.days[1].workedMinutes, 8 * 60);
    expect(sheet.days[0].unpairedPunches, 0);
    expect(sheet.days[1].unpairedPunches, 0);
  });

  test('a night shift keeps its clock-out on the day it started', () {
    const night = Shift(
      id: 2,
      name: '22:00-06:00',
      startMinute: 22 * 60,
      endMinute: 6 * 60,
      daysMask: 0x7F, // every day
    );

    final sheet = build(
      from: DateTime(2026, 8, 24),
      to: DateTime(2026, 8, 24),
      resolver: ShiftResolver(storeDefault: night),
      punches: [
        inAt(DateTime(2026, 8, 24, 22, 0)),
        outAt(DateTime(2026, 8, 25, 6, 0)), // next morning
      ],
    );

    // Without the night-spill window this would be an unpaired IN on the 24th
    // and an orphan OUT on the 25th -- two broken days instead of one good one.
    expect(sheet.days.single.workedMinutes, 8 * 60);
    expect(sheet.days.single.status, DayStatus.present);
  });

  test('a missing clock-out marks the day for review without inventing time',
      () {
    final sheet = build(
      from: DateTime(2026, 8, 24),
      to: DateTime(2026, 8, 24),
      punches: [inAt(DateTime(2026, 8, 24, 9, 0))],
    );

    expect(sheet.daysIncomplete, 1);
    expect(sheet.daysNeedingReview, 1);
    expect(sheet.workedMinutes, 0);
  });

  test('provisional timestamps propagate to the review count', () {
    final sheet = build(
      from: DateTime(2026, 8, 24),
      to: DateTime(2026, 8, 24),
      punches: [
        Punch(at: DateTime(2026, 8, 24, 9, 0), isOut: false, provisionalTime: true),
        outAt(DateTime(2026, 8, 24, 17, 0)),
      ],
    );

    expect(sheet.daysPresent, 1);
    expect(sheet.daysNeedingReview, 1);
  });

  test('a roster override applies on exactly the day it names', () {
    const evening =
        Shift(id: 3, name: 'evening', startMinute: 14 * 60, endMinute: 22 * 60);

    final resolver = ShiftResolver(
      storeDefault: nineToFive,
      roster: [
        RosterEntry(employeeId: 1, day: DateTime(2026, 8, 25), shift: evening),
      ],
    );

    final sheet = build(
      from: DateTime(2026, 8, 24),
      to: DateTime(2026, 8, 26),
      resolver: resolver,
      punches: [
        // Tuesday worked 14:00-22:00, which is on time for the evening shift
        // and would otherwise read as five hours late.
        inAt(DateTime(2026, 8, 25, 14, 0)),
        outAt(DateTime(2026, 8, 25, 22, 0)),
      ],
    );

    expect(sheet.days[1].shift?.id, evening.id);
    expect(sheet.days[1].lateMinutes, 0);
    expect(sheet.days[1].workedMinutes, 8 * 60);
  });

  test('a single day range produces exactly one day', () {
    final sheet = build(
      from: DateTime(2026, 8, 24),
      to: DateTime(2026, 8, 24),
      punches: const [],
    );
    expect(sheet.days.length, 1);
  });

  test('a month boundary is walked correctly', () {
    final sheet = build(
      from: DateTime(2026, 8, 30),
      to: DateTime(2026, 9, 2),
      punches: const [],
    );
    expect(sheet.days.length, 4);
    expect(sheet.days.first.day, DateTime(2026, 8, 30));
    expect(sheet.days.last.day, DateTime(2026, 9, 2));
  });

  test('a blank name falls back to the id so a row is never nameless', () {
    final sheet = Timesheet.build(
      employeeId: 7,
      name: 'ID 7',
      from: DateTime(2026, 8, 24),
      to: DateTime(2026, 8, 24),
      resolver: ShiftResolver(storeDefault: nineToFive),
      punches: const [],
    );
    expect(sheet.name, 'ID 7');
  });
}
