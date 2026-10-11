/// Turns raw punches into a day's attendance figures.
///
/// This is the part that eventually touches someone's pay, so it is written to
/// be auditable rather than clever: every number it produces can be traced to
/// specific punches and one shift definition, and anything it cannot determine
/// is reported as such instead of guessed.
library;

/// How a shift decides what "on time" means.
enum ShiftKind {
  /// Fixed start and end times; lateness and early leave are meaningful.
  fixed,

  /// Only the total counts. No start time, so no such thing as late.
  flexible,
}

class Shift {
  const Shift({
    required this.id,
    required this.name,
    this.kind = ShiftKind.fixed,
    this.startMinute = 540, // 09:00
    this.endMinute = 1020, // 17:00
    this.breakMinutes = 0,
    this.graceInMinutes = 10,
    this.graceOutMinutes = 10,
    this.requiredMinutes = 480,
    this.daysMask = 0x3E, // Mon–Fri
  });

  final int id;
  final String name;
  final ShiftKind kind;

  /// Minutes from local midnight.
  final int startMinute;
  final int endMinute;

  final int breakMinutes;

  /// Arriving within this many minutes of the start is not late. Likewise
  /// leaving early. A grace period is a policy, not a rounding error.
  final int graceInMinutes;
  final int graceOutMinutes;

  /// Used when [kind] is flexible.
  final int requiredMinutes;

  /// Bit 0 = Sunday … bit 6 = Saturday. The weekend is simply the unset bits,
  /// which makes Fri/Sat and Sat/Sun the same mechanism rather than a special
  /// case (decision D8).
  final int daysMask;

  bool worksOn(DateTime day) => (daysMask & (1 << (day.weekday % 7))) != 0;

  /// Scheduled minutes, net of an unpaid break. An end before the start means
  /// the shift crosses midnight.
  int get scheduledMinutes {
    final span = endMinute >= startMinute
        ? endMinute - startMinute
        : (1440 - startMinute) + endMinute;
    return (span - breakMinutes).clamp(0, 1440);
  }

  bool get crossesMidnight => endMinute < startMinute;
}

/// A shift assigned to an employee over a date range.
class ShiftAssignment {
  const ShiftAssignment({
    required this.employeeId,
    required this.shift,
    required this.from,
    this.to,
  });

  final int employeeId;
  final Shift shift;
  final DateTime from;
  final DateTime? to;

  bool coversDay(DateTime day) {
    if (day.isBefore(_dateOnly(from))) return false;
    if (to != null && day.isAfter(_dateOnly(to!))) return false;
    return true;
  }
}

/// A specific date overriding the standing assignment — the rotating roster
/// case. A null [shift] means explicitly off that day.
class RosterEntry {
  const RosterEntry({required this.employeeId, required this.day, this.shift});

  final int employeeId;
  final DateTime day;
  final Shift? shift;
}

/// One punch, already in local time.
class Punch {
  const Punch({
    required this.at,
    required this.isOut,
    this.manual = false,
    this.provisionalTime = false,
  });

  final DateTime at;
  final bool isOut;
  final bool manual;

  /// The device could not verify its clock when this was recorded (D7).
  final bool provisionalTime;
}

enum DayStatus {
  /// Not scheduled to work.
  off,

  /// Scheduled and worked.
  present,

  /// Scheduled, no punches at all.
  absent,

  /// Punches exist but do not pair up — usually a missing OUT. The figures
  /// are reported but should be confirmed before they reach payroll.
  incomplete,

  /// Scheduled, but the day has not happened yet (or today, before anyone
  /// could be called absent). Counting these as absences made every current
  /// month report a pile of absences for days still to come.
  upcoming,
}

/// A worked interval, kept so a report can show its reasoning.
class WorkInterval {
  const WorkInterval(this.start, this.end);
  final DateTime start;
  final DateTime end;
  int get minutes => end.difference(start).inMinutes;
}

class DayResult {
  const DayResult({
    required this.day,
    required this.status,
    required this.shift,
    required this.intervals,
    required this.workedMinutes,
    required this.lateMinutes,
    required this.earlyLeaveMinutes,
    required this.overtimeMinutes,
    required this.firstIn,
    required this.lastOut,
    required this.unpairedPunches,
    required this.hasProvisionalTime,
    required this.hasManualPunch,
    this.inProgress = false,
  });

  /// Today, clocked in and not yet out. The missing OUT is expected, so it is
  /// not something to review.
  final bool inProgress;

  DayResult copyWith({DayStatus? status, bool? inProgress}) => DayResult(
    day: day,
    status: status ?? this.status,
    shift: shift,
    intervals: intervals,
    workedMinutes: workedMinutes,
    lateMinutes: lateMinutes,
    earlyLeaveMinutes: earlyLeaveMinutes,
    overtimeMinutes: overtimeMinutes,
    firstIn: firstIn,
    lastOut: lastOut,
    unpairedPunches: unpairedPunches,
    hasProvisionalTime: hasProvisionalTime,
    hasManualPunch: hasManualPunch,
    inProgress: inProgress ?? this.inProgress,
  );

  final DateTime day;
  final DayStatus status;
  final Shift? shift;
  final List<WorkInterval> intervals;

  final int workedMinutes;
  final int lateMinutes;
  final int earlyLeaveMinutes;
  final int overtimeMinutes;

  final DateTime? firstIn;
  final DateTime? lastOut;

  /// Punches that could not be paired. Non-zero means a human should look.
  final int unpairedPunches;

  final bool hasProvisionalTime;
  final bool hasManualPunch;

  /// True when any figure here rests on something unverified. Reports should
  /// mark these rather than fold them silently into a total.
  bool get needsReview =>
      !inProgress &&
      (status == DayStatus.incomplete ||
          unpairedPunches > 0 ||
          hasProvisionalTime);
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Resolves which shift applies, in the order laid down by decision D8:
/// a roster entry for that date, else the employee's standing assignment,
/// else the store default.
class ShiftResolver {
  ShiftResolver({
    this.storeDefault,
    List<ShiftAssignment> assignments = const [],
    List<RosterEntry> roster = const [],
  }) : _assignments = assignments,
       _roster = roster;

  final Shift? storeDefault;
  final List<ShiftAssignment> _assignments;
  final List<RosterEntry> _roster;

  /// Null means the employee is not scheduled that day.
  Shift? shiftFor(int employeeId, DateTime day) {
    final d = _dateOnly(day);

    for (final r in _roster) {
      if (r.employeeId == employeeId && _dateOnly(r.day) == d) {
        // A roster entry wins even when it says "off" — that is the point of
        // being able to override the standing pattern.
        return r.shift;
      }
    }

    // Latest applicable assignment wins, so a newer contract supersedes an
    // older one that has not been closed off.
    ShiftAssignment? best;
    for (final a in _assignments) {
      if (a.employeeId != employeeId || !a.coversDay(d)) continue;
      if (best == null || a.from.isAfter(best.from)) best = a;
    }
    if (best != null) {
      return best.shift.worksOn(d) ? best.shift : null;
    }

    final s = storeDefault;
    if (s == null) return null;
    return s.worksOn(d) ? s : null;
  }
}

class AttendanceCalculator {
  const AttendanceCalculator();

  /// Computes one day for one employee.
  ///
  /// [punches] should be that employee's punches for the day, in any order.
  /// For a shift crossing midnight, include the following morning's punches —
  /// the caller owns that window because only it knows the shift.
  DayResult computeDay({
    required DateTime day,
    required Shift? shift,
    required List<Punch> punches,
  }) {
    final d = _dateOnly(day);
    final sorted = [...punches]..sort((a, b) => a.at.compareTo(b.at));

    final provisional = sorted.any((p) => p.provisionalTime);
    final manual = sorted.any((p) => p.manual);

    if (shift == null) {
      // Not scheduled. Any punches still count as time worked -- someone came
      // in on their day off -- but nothing is late and nothing is missing.
      final (intervals, unpaired) = _pair(sorted);
      final worked = intervals.fold(0, (n, i) => n + i.minutes);
      return DayResult(
        day: d,
        status: DayStatus.off,
        shift: null,
        intervals: intervals,
        workedMinutes: worked,
        lateMinutes: 0,
        earlyLeaveMinutes: 0,
        overtimeMinutes: worked,
        firstIn: intervals.isEmpty ? null : intervals.first.start,
        lastOut: intervals.isEmpty ? null : intervals.last.end,
        unpairedPunches: unpaired,
        hasProvisionalTime: provisional,
        hasManualPunch: manual,
      );
    }

    if (sorted.isEmpty) {
      return DayResult(
        day: d,
        status: DayStatus.absent,
        shift: shift,
        intervals: const [],
        workedMinutes: 0,
        lateMinutes: 0,
        earlyLeaveMinutes: 0,
        overtimeMinutes: 0,
        firstIn: null,
        lastOut: null,
        unpairedPunches: 0,
        hasProvisionalTime: false,
        hasManualPunch: false,
      );
    }

    final (intervals, unpaired) = _pair(sorted);
    final worked = intervals.fold(0, (n, i) => n + i.minutes);

    // Arrival and departure are the actual punches, not the paired intervals.
    // Taking them from intervals meant anyone who forgot to clock out had no
    // arrival time at all -- blank in the report, and never counted late.
    // Worked minutes still come only from pairs; nothing is invented.
    final firstIn = sorted.where((p) => !p.isOut).firstOrNull?.at;
    final lastOut = sorted.where((p) => p.isOut).lastOrNull?.at;

    var late = 0;
    var earlyLeave = 0;
    var overtime = 0;

    if (shift.kind == ShiftKind.flexible) {
      // No start time, so only the total matters.
      overtime = (worked - shift.requiredMinutes).clamp(0, 1440);
    } else {
      final start = d.add(Duration(minutes: shift.startMinute));
      final end = shift.crossesMidnight
          ? d.add(Duration(days: 1, minutes: shift.endMinute))
          : d.add(Duration(minutes: shift.endMinute));

      if (firstIn != null) {
        final over = firstIn.difference(start).inMinutes;
        // Grace is all-or-nothing: inside it, not late at all.
        if (over > shift.graceInMinutes) late = over;
      }
      if (lastOut != null) {
        final short = end.difference(lastOut).inMinutes;
        if (short > shift.graceOutMinutes) earlyLeave = short;
      }

      overtime = (worked - shift.scheduledMinutes).clamp(0, 1440);
    }

    final status = unpaired > 0 ? DayStatus.incomplete : DayStatus.present;

    return DayResult(
      day: d,
      status: status,
      shift: shift,
      intervals: intervals,
      workedMinutes: worked,
      lateMinutes: late,
      earlyLeaveMinutes: earlyLeave,
      overtimeMinutes: overtime,
      firstIn: firstIn,
      lastOut: lastOut,
      unpairedPunches: unpaired,
      hasProvisionalTime: provisional,
      hasManualPunch: manual,
    );
  }

  /// Pairs each IN with the next OUT, returning the worked intervals and how
  /// many punches could not be paired.
  ///
  /// Deliberately does not invent a missing OUT. Someone who forgot to clock
  /// out should show up as needing review, not be silently credited to the end
  /// of their shift — inventing minutes here would be inventing pay.
  (List<WorkInterval>, int) _pair(List<Punch> sorted) {
    final intervals = <WorkInterval>[];
    var unpaired = 0;
    DateTime? openIn;

    for (final p in sorted) {
      if (!p.isOut) {
        // Two INs in a row: the first is dangling.
        if (openIn != null) unpaired++;
        openIn = p.at;
      } else {
        if (openIn == null) {
          unpaired++; // OUT with no matching IN
        } else {
          if (p.at.isAfter(openIn)) {
            intervals.add(WorkInterval(openIn, p.at));
          }
          openIn = null;
        }
      }
    }
    if (openIn != null) unpaired++; // never clocked out

    return (intervals, unpaired);
  }
}
