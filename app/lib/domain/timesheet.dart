/// Turns stored punches into a timesheet for a date range.
///
/// Split deliberately in two: [Timesheet.build] is pure and takes plain data,
/// while [TimesheetRepository] does the database reading. Payroll arithmetic
/// should be testable without a database standing behind it.
library;

import 'package:drift/drift.dart' show Value;

import '../data/database.dart';
import 'attendance_rules.dart';

class EmployeeTimesheet {
  const EmployeeTimesheet({
    required this.employeeId,
    required this.name,
    required this.days,
  });

  final int employeeId;
  final String name;
  final List<DayResult> days;

  int get workedMinutes => days.fold(0, (n, d) => n + d.workedMinutes);
  int get lateMinutes => days.fold(0, (n, d) => n + d.lateMinutes);
  int get earlyLeaveMinutes => days.fold(0, (n, d) => n + d.earlyLeaveMinutes);
  int get overtimeMinutes => days.fold(0, (n, d) => n + d.overtimeMinutes);

  int get daysPresent =>
      days.where((d) => d.status == DayStatus.present).length;
  int get daysAbsent => days.where((d) => d.status == DayStatus.absent).length;
  int get daysIncomplete =>
      days.where((d) => d.status == DayStatus.incomplete).length;

  /// Days whose figures rest on something unverified. A report that folds
  /// these into a total without saying so is misleading.
  int get daysNeedingReview => days.where((d) => d.needsReview).length;

  int get lateOccasions => days.where((d) => d.lateMinutes > 0).length;
}

class Timesheet {
  const Timesheet._();

  /// Builds one employee's sheet over [from]..[to] inclusive.
  ///
  /// [punches] must cover the range plus any spill from a night shift; the
  /// repository widens the query for exactly that reason.
  static EmployeeTimesheet build({
    required int employeeId,
    required String name,
    required DateTime from,
    required DateTime to,
    required ShiftResolver resolver,
    required List<Punch> punches,
    AttendanceCalculator calculator = const AttendanceCalculator(),
    DateTime? now,
  }) {
    final days = <DayResult>[];
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    final clock = now ?? DateTime.now();
    final today = DateTime(clock.year, clock.month, clock.day);

    for (
      var d = start;
      !d.isAfter(end);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      final shift = resolver.shiftFor(employeeId, d);
      final dayPunches = _punchesForDay(d, shift, punches);
      final result = calculator.computeDay(
        day: d,
        shift: shift,
        punches: dayPunches,
      );
      days.add(_againstClock(result, dayPunches, today, clock));
    }

    return EmployeeTimesheet(employeeId: employeeId, name: name, days: days);
  }

  /// Which punches belong to a given working day.
  ///
  /// Normally that is the calendar day. A shift crossing midnight is the
  /// exception: the hours after midnight belong to the day the shift started,
  /// so the window extends into the next morning. The cut-off is the shift end
  /// plus a margin, which keeps the following day's early arrivals out of it.
  static List<Punch> _punchesForDay(
    DateTime day,
    Shift? shift,
    List<Punch> all,
  ) {
    final dayStart = DateTime(day.year, day.month, day.day);
    late final DateTime dayEnd;

    if (shift != null && shift.crossesMidnight) {
      dayEnd = dayStart.add(
        Duration(days: 1, minutes: shift.endMinute + _nightSpillMinutes),
      );
    } else {
      dayEnd = dayStart.add(const Duration(days: 1));
    }

    return all
        .where((p) => !p.at.isBefore(dayStart) && p.at.isBefore(dayEnd))
        .toList();
  }

  /// How far past a night shift's end to keep looking for its clock-out.
  static const _nightSpillMinutes = 120;

  /// A day's figures only mean "absent" or "missing OUT" once the day is
  /// over. The calculator knows nothing of the present, so this adjusts:
  ///   - a scheduled day in the future is upcoming, not an absence;
  ///   - today, with nobody in yet, is upcoming until the shift has ended;
  ///   - today, clocked in and not yet out, is in progress, not a mistake.
  static DayResult _againstClock(
    DayResult r,
    List<Punch> punches,
    DateTime today,
    DateTime now,
  ) {
    if (r.day.isAfter(today)) {
      if (r.status == DayStatus.absent) {
        return r.copyWith(status: DayStatus.upcoming);
      }
      return r;
    }
    if (r.day != today) return r;

    final shift = r.shift;
    if (r.status == DayStatus.absent && shift != null) {
      final endsAt = shift.kind == ShiftKind.flexible
          ? today.add(const Duration(days: 1))
          : today.add(
              Duration(
                days: shift.crossesMidnight ? 1 : 0,
                minutes: shift.endMinute,
              ),
            );
      if (now.isBefore(endsAt)) return r.copyWith(status: DayStatus.upcoming);
    }
    // Exactly one loose punch, and it is the latest punch of the day and an
    // IN: they are at work right now.
    if (r.unpairedPunches == 1 && punches.isNotEmpty) {
      final last = punches.reduce((a, b) => b.at.isAfter(a.at) ? b : a);
      if (!last.isOut) {
        return r.copyWith(
          status: r.shift == null ? DayStatus.off : DayStatus.present,
          inProgress: true,
        );
      }
    }
    return r;
  }
}

/// Loads what the calculation needs out of drift and hands it to [Timesheet].
class TimesheetRepository {
  TimesheetRepository(this.db);

  final AppDatabase db;

  /// Builds sheets for every employee (or one) across the range.
  Future<List<EmployeeTimesheet>> build({
    required DateTime from,
    required DateTime to,
    int? employeeId,
  }) async {
    final employees = await db.allEmployees();
    final wanted = employeeId == null
        ? employees
        : employees.where((e) => e.id == employeeId).toList();
    if (wanted.isEmpty) return const [];

    final resolver = await loadResolver(from: from, to: to);

    // Widen the query so a night shift's clock-out on the following morning is
    // still found, and so nothing is missed at the boundaries.
    final fromEpoch =
        DateTime(
          from.year,
          from.month,
          from.day,
        ).subtract(const Duration(days: 1)).toUtc().millisecondsSinceEpoch ~/
        1000;
    final toEpoch =
        DateTime(
          to.year,
          to.month,
          to.day,
        ).add(const Duration(days: 2)).toUtc().millisecondsSinceEpoch ~/
        1000;

    final rows = await db.punchesBetween(fromEpoch, toEpoch);

    final byEmployee = <int, List<Punch>>{};
    for (final r in rows) {
      byEmployee.putIfAbsent(r.employeeId, () => []).add(toPunch(r));
    }

    // Someone who has left still appears for months they worked -- that is the
    // point of keeping them -- but not in months after they left.
    final visible = wanted.where(
      (e) => !e.removed || (byEmployee[e.id]?.isNotEmpty ?? false),
    );

    return [
      for (final e in visible)
        Timesheet.build(
          employeeId: e.id,
          name: e.name.isEmpty ? 'ID ${e.id}' : e.name,
          from: from,
          to: to,
          resolver: resolver,
          punches: byEmployee[e.id] ?? const [],
        ),
    ];
  }

  /// A corrected timestamp supersedes the recorded one, but the original is
  /// never overwritten in storage -- only preferred here.
  static Punch toPunch(PunchRow r) {
    final epoch = r.correctedEpoch ?? r.deviceEpoch;
    return Punch(
      at: DateTime.fromMillisecondsSinceEpoch(
        epoch * 1000,
        isUtc: true,
      ).toLocal(),
      isOut: r.direction == 1,
      manual: r.method == 1,
      // A correction resolves the uncertainty, so it clears the flag.
      provisionalTime: r.provisionalTime && r.correctedEpoch == null,
    );
  }

  Future<ShiftResolver> loadResolver({
    required DateTime from,
    required DateTime to,
  }) async {
    final shiftRows = await db.allShifts();
    final shifts = {for (final s in shiftRows) s.id: toShift(s)};

    final assignments = <ShiftAssignment>[];
    for (final a in await db.allEmployeeShifts()) {
      final s = shifts[a.shiftId];
      if (s == null) continue;
      assignments.add(
        ShiftAssignment(
          employeeId: a.employeeId,
          shift: s,
          from: _fromEpoch(a.effectiveFrom),
          to: a.effectiveTo == null ? null : _fromEpoch(a.effectiveTo!),
        ),
      );
    }

    final roster = <RosterEntry>[];
    for (final r in await db.rosterBetween(_dateKey(from), _dateKey(to))) {
      roster.add(
        RosterEntry(
          employeeId: r.employeeId,
          day: _fromDateKey(r.dateKey),
          shift: r.shiftId == null ? null : shifts[r.shiftId!],
        ),
      );
    }

    // Explicitly flagged, not guessed. Falling back to the first shift keeps
    // a database that predates the flag working.
    final defaultRow =
        shiftRows.where((s) => s.isDefault).firstOrNull ??
        (shiftRows.isEmpty ? null : shiftRows.first);

    return ShiftResolver(
      storeDefault: defaultRow == null ? null : toShift(defaultRow),
      assignments: assignments,
      roster: roster,
    );
  }

  static Shift toShift(ShiftRow r) => Shift(
    id: r.id,
    name: r.name,
    kind: r.kind == 1 ? ShiftKind.flexible : ShiftKind.fixed,
    startMinute: r.startMinute,
    endMinute: r.endMinute,
    breakMinutes: r.breakMinutes,
    graceInMinutes: r.graceInMinutes,
    graceOutMinutes: r.graceOutMinutes,
    requiredMinutes: r.requiredMinutes,
    daysMask: r.daysMask,
  );

  /// Local calendar date as yyyymmdd, so day lookups never trip over
  /// timezone arithmetic.
  static int _dateKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  static DateTime _fromDateKey(int key) =>
      DateTime(key ~/ 10000, (key ~/ 100) % 100, key % 100);

  static DateTime _fromEpoch(int seconds) =>
      DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000,
        isUtc: true,
      ).toLocal();

  /// Seeds a single store-wide shift for a fresh install, so the app has
  /// something sensible to calculate against before anyone configures rosters.
  Future<void> ensureDefaultShift() async {
    if ((await db.allShifts()).isNotEmpty) return;
    await db.insertShift(
      ShiftsCompanion.insert(
        name: 'Store hours',
        startMinute: const Value(9 * 60),
        endMinute: const Value(17 * 60),
        isDefault: const Value(true),
      ),
    );
  }
}
