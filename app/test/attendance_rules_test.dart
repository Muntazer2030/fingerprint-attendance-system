import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_admin/domain/attendance_rules.dart';

/// These figures can end up in someone's pay, so the edge cases matter more
/// than the happy path.
void main() {
  final day = DateTime(2026, 8, 24); // a Monday

  DateTime at(int h, int m) => DateTime(2026, 8, 24, h, m);

  const nineToFive = Shift(
    id: 1,
    name: '09:00-17:00',
    startMinute: 9 * 60,
    endMinute: 17 * 60,
    graceInMinutes: 10,
    graceOutMinutes: 10,
    daysMask: 0x3E, // Mon-Fri
  );

  const calc = AttendanceCalculator();

  group('pairing punches', () {
    test('a straightforward day', () {
      final r = calc.computeDay(day: day, shift: nineToFive, punches: [
        Punch(at: at(8, 58), isOut: false),
        Punch(at: at(17, 2), isOut: true),
      ]);

      expect(r.status, DayStatus.present);
      expect(r.workedMinutes, 484);
      expect(r.lateMinutes, 0);
      expect(r.earlyLeaveMinutes, 0);
      expect(r.needsReview, isFalse);
    });

    test('a lunch break splits into two intervals and is not counted', () {
      final r = calc.computeDay(day: day, shift: nineToFive, punches: [
        Punch(at: at(9, 0), isOut: false),
        Punch(at: at(13, 0), isOut: true),
        Punch(at: at(14, 0), isOut: false),
        Punch(at: at(17, 0), isOut: true),
      ]);

      expect(r.intervals.length, 2);
      expect(r.workedMinutes, 7 * 60); // the hour out is not worked
      expect(r.status, DayStatus.present);
    });

    test('forgetting to clock out is flagged, not invented', () {
      // Crediting the missing OUT to the shift end would be inventing pay.
      final r = calc.computeDay(day: day, shift: nineToFive, punches: [
        Punch(at: at(9, 0), isOut: false),
      ]);

      expect(r.status, DayStatus.incomplete);
      expect(r.unpairedPunches, 1);
      expect(r.workedMinutes, 0);
      expect(r.needsReview, isTrue);
    });

    test('an OUT with no IN is unpaired rather than negative time', () {
      final r = calc.computeDay(day: day, shift: nineToFive, punches: [
        Punch(at: at(17, 0), isOut: true),
      ]);

      expect(r.unpairedPunches, 1);
      expect(r.workedMinutes, 0);
      expect(r.status, DayStatus.incomplete);
    });

    test('two INs in a row leave the first dangling', () {
      final r = calc.computeDay(day: day, shift: nineToFive, punches: [
        Punch(at: at(9, 0), isOut: false),
        Punch(at: at(9, 5), isOut: false),
        Punch(at: at(17, 0), isOut: true),
      ]);

      expect(r.unpairedPunches, 1);
      expect(r.intervals.length, 1);
      expect(r.intervals.single.start, at(9, 5));
      expect(r.status, DayStatus.incomplete);
    });

    test('punches out of order are still paired correctly', () {
      final r = calc.computeDay(day: day, shift: nineToFive, punches: [
        Punch(at: at(17, 0), isOut: true),
        Punch(at: at(9, 0), isOut: false),
      ]);
      expect(r.workedMinutes, 8 * 60);
      expect(r.unpairedPunches, 0);
    });
  });

  group('lateness and grace', () {
    test('inside the grace period is not late at all', () {
      final r = calc.computeDay(day: day, shift: nineToFive, punches: [
        Punch(at: at(9, 9), isOut: false),
        Punch(at: at(17, 0), isOut: true),
      ]);
      expect(r.lateMinutes, 0);
    });

    test('past the grace period counts from the scheduled start, not the grace',
        () {
      // 09:25 with a 10-minute grace is 25 minutes late, not 15. Grace forgives
      // or it does not; it is not a discount.
      final r = calc.computeDay(day: day, shift: nineToFive, punches: [
        Punch(at: at(9, 25), isOut: false),
        Punch(at: at(17, 0), isOut: true),
      ]);
      expect(r.lateMinutes, 25);
    });

    test('leaving early past grace is counted', () {
      final r = calc.computeDay(day: day, shift: nineToFive, punches: [
        Punch(at: at(9, 0), isOut: false),
        Punch(at: at(16, 30), isOut: true),
      ]);
      expect(r.earlyLeaveMinutes, 30);
    });

    test('arriving early does not produce negative lateness', () {
      final r = calc.computeDay(day: day, shift: nineToFive, punches: [
        Punch(at: at(8, 0), isOut: false),
        Punch(at: at(17, 0), isOut: true),
      ]);
      expect(r.lateMinutes, 0);
      expect(r.overtimeMinutes, 60);
    });
  });

  group('scheduling', () {
    test('a day off with no punches is off, not absent', () {
      final r = calc.computeDay(day: day, shift: null, punches: []);
      expect(r.status, DayStatus.off);
      expect(r.workedMinutes, 0);
    });

    test('working on a day off counts entirely as overtime', () {
      final r = calc.computeDay(day: day, shift: null, punches: [
        Punch(at: at(10, 0), isOut: false),
        Punch(at: at(14, 0), isOut: true),
      ]);
      expect(r.status, DayStatus.off);
      expect(r.workedMinutes, 4 * 60);
      expect(r.overtimeMinutes, 4 * 60);
      expect(r.lateMinutes, 0);
    });

    test('scheduled with no punches is absent', () {
      final r = calc.computeDay(day: day, shift: nineToFive, punches: []);
      expect(r.status, DayStatus.absent);
      expect(r.needsReview, isFalse);
    });

    test('an unpaid break reduces scheduled minutes, so overtime starts later',
        () {
      const withBreak = Shift(
        id: 2,
        name: 'with break',
        startMinute: 9 * 60,
        endMinute: 18 * 60,
        breakMinutes: 60,
      );
      expect(withBreak.scheduledMinutes, 8 * 60);

      final r = calc.computeDay(day: day, shift: withBreak, punches: [
        Punch(at: at(9, 0), isOut: false),
        Punch(at: at(18, 0), isOut: true),
      ]);
      expect(r.workedMinutes, 9 * 60);
      expect(r.overtimeMinutes, 60);
    });

    test('a night shift crossing midnight measures the right span', () {
      const night = Shift(
        id: 3,
        name: '22:00-06:00',
        startMinute: 22 * 60,
        endMinute: 6 * 60,
      );
      expect(night.crossesMidnight, isTrue);
      expect(night.scheduledMinutes, 8 * 60);

      final r = calc.computeDay(day: day, shift: night, punches: [
        Punch(at: at(22, 0), isOut: false),
        Punch(at: DateTime(2026, 8, 25, 6, 0), isOut: true),
      ]);
      expect(r.workedMinutes, 8 * 60);
      expect(r.lateMinutes, 0);
      expect(r.earlyLeaveMinutes, 0);
    });
  });

  group('flexible hours', () {
    const flexible = Shift(
      id: 4,
      name: 'hours only',
      kind: ShiftKind.flexible,
      requiredMinutes: 8 * 60,
    );

    test('there is no such thing as late', () {
      final r = calc.computeDay(day: day, shift: flexible, punches: [
        Punch(at: at(13, 0), isOut: false),
        Punch(at: at(21, 0), isOut: true),
      ]);
      expect(r.lateMinutes, 0);
      expect(r.earlyLeaveMinutes, 0);
      expect(r.workedMinutes, 8 * 60);
      expect(r.overtimeMinutes, 0);
    });

    test('overtime is measured against the required total', () {
      final r = calc.computeDay(day: day, shift: flexible, punches: [
        Punch(at: at(8, 0), isOut: false),
        Punch(at: at(18, 0), isOut: true),
      ]);
      expect(r.overtimeMinutes, 2 * 60);
    });
  });

  group('review flags', () {
    test('a provisional timestamp marks the day for review', () {
      final r = calc.computeDay(day: day, shift: nineToFive, punches: [
        Punch(at: at(9, 0), isOut: false, provisionalTime: true),
        Punch(at: at(17, 0), isOut: true),
      ]);
      expect(r.status, DayStatus.present);
      expect(r.hasProvisionalTime, isTrue);
      expect(r.needsReview, isTrue);
    });

    test('a manual punch is recorded but does not by itself demand review', () {
      final r = calc.computeDay(day: day, shift: nineToFive, punches: [
        Punch(at: at(9, 0), isOut: false, manual: true),
        Punch(at: at(17, 0), isOut: true),
      ]);
      expect(r.hasManualPunch, isTrue);
      expect(r.needsReview, isFalse);
    });
  });

  group('shift resolution order', () {
    const other = Shift(id: 9, name: 'evening', startMinute: 14 * 60, endMinute: 22 * 60);

    test('roster entry beats the standing assignment', () {
      final resolver = ShiftResolver(
        assignments: [
          ShiftAssignment(employeeId: 1, shift: nineToFive, from: DateTime(2026, 1, 1)),
        ],
        roster: [RosterEntry(employeeId: 1, day: day, shift: other)],
      );
      expect(resolver.shiftFor(1, day)?.id, other.id);
    });

    test('a roster entry can say "off" and override a working day', () {
      final resolver = ShiftResolver(
        assignments: [
          ShiftAssignment(employeeId: 1, shift: nineToFive, from: DateTime(2026, 1, 1)),
        ],
        roster: [RosterEntry(employeeId: 1, day: day)],
      );
      expect(resolver.shiftFor(1, day), isNull);
    });

    test('assignment beats the store default', () {
      final resolver = ShiftResolver(
        storeDefault: other,
        assignments: [
          ShiftAssignment(employeeId: 1, shift: nineToFive, from: DateTime(2026, 1, 1)),
        ],
      );
      expect(resolver.shiftFor(1, day)?.id, nineToFive.id);
    });

    test('the newest applicable assignment wins', () {
      final resolver = ShiftResolver(assignments: [
        ShiftAssignment(employeeId: 1, shift: nineToFive, from: DateTime(2026, 1, 1)),
        ShiftAssignment(employeeId: 1, shift: other, from: DateTime(2026, 6, 1)),
      ]);
      expect(resolver.shiftFor(1, day)?.id, other.id);
    });

    test('an expired assignment falls through to the store default', () {
      final resolver = ShiftResolver(
        storeDefault: other,
        assignments: [
          ShiftAssignment(
            employeeId: 1,
            shift: nineToFive,
            from: DateTime(2026, 1, 1),
            to: DateTime(2026, 3, 1),
          ),
        ],
      );
      expect(resolver.shiftFor(1, day)?.id, other.id);
    });

    test('the weekend is just unset day bits, so Fri/Sat works like Sat/Sun',
        () {
      // Friday+Saturday weekend: Sunday..Thursday set.
      const friSatWeekend = Shift(id: 5, name: 'gulf week', daysMask: 0x1F);
      final resolver = ShiftResolver(storeDefault: friSatWeekend);

      expect(resolver.shiftFor(1, DateTime(2026, 8, 27)), isNotNull); // Thu
      expect(resolver.shiftFor(1, DateTime(2026, 8, 28)), isNull); // Fri
      expect(resolver.shiftFor(1, DateTime(2026, 8, 29)), isNull); // Sat
      expect(resolver.shiftFor(1, DateTime(2026, 8, 30)), isNotNull); // Sun
    });

    test('nothing configured at all means nobody is scheduled', () {
      expect(ShiftResolver().shiftFor(1, day), isNull);
    });
  });
}
