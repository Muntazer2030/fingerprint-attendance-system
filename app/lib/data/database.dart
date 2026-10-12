import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Local durable store. Once a punch is committed here and acked, the device
/// is free to reclaim the space -- so this file is the system of record for
/// attendance history, not the terminal.

@DataClassName('EmployeeRow')
class Employees extends Table {
  IntColumn get id => integer()();

  /// Real Arabic (or Latin) name. The 1bpp bitmap pushed to the device is
  /// rendered from this; the device itself never stores text.
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get jobTitle => text().withDefault(const Constant(''))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  /// Cached from the device so the roster renders without a round trip.
  IntColumn get fingers => integer().withDefault(const Constant(0))();
  IntColumn get failCount => integer().withDefault(const Constant(0))();

  /// Removed from the terminal, but kept here. Deleting the row outright took
  /// the person's history out of every past timesheet with it -- payroll for
  /// a month someone worked must not depend on whether they still work here.
  BoolColumn get removed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Small integer settings that must live beside the punches rather than in
/// preferences, because they decide how punch rows are numbered.
@DataClassName('MetaRow')
class Meta extends Table {
  TextColumn get key => text()();
  IntColumn get value => integer()();

  @override
  Set<Column> get primaryKey => {key};
}

@DataClassName('PunchRow')
class Punches extends Table {
  /// Device sequence number. Monotonic and never reused, which makes it a
  /// natural primary key and gives us idempotent re-imports for free: pulling
  /// an already-stored range simply overwrites identical rows.
  IntColumn get seq => integer()();

  IntColumn get deviceEpoch => integer()();
  IntColumn get employeeId => integer()();
  IntColumn get slot => integer().withDefault(const Constant(0))();

  /// 0 = in, 1 = out.
  IntColumn get direction => integer()();

  /// 0 = finger, 1 = manual, 2 = pin.
  IntColumn get method => integer().withDefault(const Constant(0))();

  /// The device could not verify its clock (D7). Kept as recorded; corrections
  /// go in [correctedEpoch] so the original is never overwritten.
  BoolColumn get provisionalTime =>
      boolean().withDefault(const Constant(false))();
  IntColumn get correctedEpoch => integer().nullable()();

  @override
  Set<Column> get primaryKey => {seq};
}

/// Every manual change to attendance data. If this ever feeds payroll, being
/// able to say who altered what and when is not optional.
@DataClassName('AuditRow')
class AuditLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get atEpoch => integer()();
  TextColumn get action => text()();
  IntColumn get employeeId => integer().nullable()();
  TextColumn get detail => text().withDefault(const Constant(''))();
}

/// Shift definitions covering all four scheduling modes (D8):
/// fixed store hours, per-employee fixed, rotating roster, and hours-only.
@DataClassName('ShiftRow')
class Shifts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// 0 = fixed times, 1 = flexible (count hours only).
  IntColumn get kind => integer().withDefault(const Constant(0))();

  /// Minutes from midnight. Ignored when [kind] is flexible.
  IntColumn get startMinute => integer().withDefault(const Constant(540))();
  IntColumn get endMinute => integer().withDefault(const Constant(1020))();
  IntColumn get breakMinutes => integer().withDefault(const Constant(0))();
  IntColumn get graceInMinutes => integer().withDefault(const Constant(10))();
  IntColumn get graceOutMinutes => integer().withDefault(const Constant(10))();

  /// Required minutes per day when [kind] is flexible.
  IntColumn get requiredMinutes => integer().withDefault(const Constant(480))();

  /// Bit 0 = Sunday .. bit 6 = Saturday. Weekend is simply the unset bits,
  /// which keeps Fri/Sat and Sat/Sun weekends the same mechanism.
  IntColumn get daysMask => integer().withDefault(const Constant(0x3E))();

  /// The shift applied to anyone without their own assignment.
  ///
  /// Explicit rather than inferred. This used to be "whichever shift nobody is
  /// assigned to", which happens to work with one shift and silently picks the
  /// wrong one as soon as there are several.
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
}

/// An employee's standing shift over a date range.
@DataClassName('EmployeeShiftRow')
class EmployeeShifts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get employeeId => integer()();
  IntColumn get shiftId => integer()();
  IntColumn get effectiveFrom => integer()();
  IntColumn get effectiveTo => integer().nullable()();
}

/// A specific date overriding the standing shift -- the rotating-roster case.
/// Resolution order is RosterEntry > EmployeeShift > store default (D8).
@DataClassName('RosterRow')
class RosterEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get employeeId => integer()();

  /// Local calendar date as yyyymmdd, so day lookups never trip over
  /// timezone arithmetic.
  IntColumn get dateKey => integer()();

  /// Null means explicitly off that day.
  IntColumn get shiftId => integer().nullable()();
}

/// An employee's wage from a month onward. A raise is a new row, so months
/// before it keep the wage they were worked at.
@DataClassName('WageRow')
class Wages extends Table {
  IntColumn get employeeId => integer()();

  /// yyyymm the wage starts.
  IntColumn get fromMonth => integer()();

  /// 0 = monthly salary, 1 = per day, 2 = per hour.
  IntColumn get kind => integer()();

  /// Hundredths of the currency unit, so money never passes through a float
  /// in storage.
  IntColumn get amountCents => integer()();

  @override
  Set<Column> get primaryKey => {employeeId, fromMonth};
}

/// Bonuses, deductions and salary advances entered by the manager.
@DataClassName('PayAdjustmentRow')
class PayAdjustments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get employeeId => integer()();
  IntColumn get monthKey => integer()();

  /// 0 = bonus, 1 = deduction, 2 = advance.
  IntColumn get kind => integer()();
  IntColumn get amountCents => integer()();
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get atEpoch => integer()();
}

/// The manager's replacements for clock figures in one month. Null keeps the
/// clock's value; the clock's figure itself is never altered.
@DataClassName('PayEditRow')
class PayEdits extends Table {
  IntColumn get employeeId => integer()();
  IntColumn get monthKey => integer()();
  IntColumn get overtimeMinutes => integer().nullable()();
  IntColumn get dayOffMinutes => integer().nullable()();
  IntColumn get lateMinutes => integer().nullable()();
  IntColumn get earlyLeaveMinutes => integer().nullable()();
  IntColumn get absentDays => integer().nullable()();

  @override
  Set<Column> get primaryKey => {employeeId, monthKey};
}

/// A month marked paid, with the payslips frozen as JSON. Recomputing a paid
/// month from current data would let a later punch correction silently change
/// a salary already handed over.
@DataClassName('PayrollRunRow')
class PayrollRuns extends Table {
  IntColumn get monthKey => integer()();
  IntColumn get paidEpoch => integer()();
  TextColumn get snapshot => text()();

  @override
  Set<Column> get primaryKey => {monthKey};
}

@DriftDatabase(
  tables: [
    Employees,
    Punches,
    AuditLog,
    Shifts,
    EmployeeShifts,
    RosterEntries,
    Meta,
    Wages,
    PayAdjustments,
    PayEdits,
    PayrollRuns,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  /// On native platforms this lands in a real `attendance.sqlite` file. On the
  /// web it needs to be told where the WASM assets live; both are served from
  /// `web/`, so relative URIs are correct.
  ///
  /// The `web` options are required even in a native build, because whether
  /// they are used is a runtime decision the analyzer cannot see - omitting
  /// them compiles fine and then throws on first launch in the browser.
  static QueryExecutor _open() {
    return driftDatabase(
      name: 'attendance',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      // v2 made the store-default shift an explicit flag.
      if (from < 2) {
        await m.addColumn(shifts, shifts.isDefault);
      }
      // v3: soft-deleted employees, and the device sequence offset.
      if (from < 3) {
        await m.addColumn(employees, employees.removed);
        await m.createTable(meta);
      }
      // v4: payroll.
      if (from < 4) {
        await m.createTable(wages);
        await m.createTable(payAdjustments);
        await m.createTable(payEdits);
        await m.createTable(payrollRuns);
      }
    },
  );

  // --- punches -----------------------------------------------------------

  /// Manual punches are numbered from here up, so they can never collide with
  /// a sequence number the device hands out.
  static const manualSeqBase = 0x40000000;

  /// Highest *device* sequence stored locally, in local numbering. This, not
  /// the device, decides where the next pull starts.
  ///
  /// Manual rows are excluded. Including them was a real bug: the first manual
  /// punch raised this to 0x40000000, every later pull asked the device for
  /// events after that, and no fingerprint punch was ever imported again.
  Future<int> highWaterSeq() async {
    final q = selectOnly(punches)
      ..addColumns([punches.seq.max()])
      ..where(punches.seq.isSmallerThanValue(manualSeqBase));
    final row = await q.getSingleOrNull();
    return row?.read(punches.seq.max()) ?? 0;
  }

  /// Next free number in the manual range.
  Future<int> nextManualSeq() async {
    final q = selectOnly(punches)
      ..addColumns([punches.seq.max()])
      ..where(punches.seq.isBiggerOrEqualValue(manualSeqBase));
    final row = await q.getSingleOrNull();
    final top = row?.read(punches.seq.max());
    return top == null ? manualSeqBase : top + 1;
  }

  Future<PunchRow?> punch(int seq) =>
      (select(punches)..where((t) => t.seq.equals(seq))).getSingleOrNull();

  /// Inserts a batch atomically. Re-importing an overlapping range is safe:
  /// seq is the primary key and rows are identical, so it is a no-op.
  Future<void> storePunches(Iterable<PunchesCompanion> rows) {
    return batch(
      (b) =>
          b.insertAll(punches, rows.toList(), mode: InsertMode.insertOrReplace),
    );
  }

  /// Newest first, by when the punch happened -- not by sequence, which put
  /// every manual entry at the top regardless of its date.
  Future<List<PunchRow>> recentPunches({
    int limit = 200,
    int? employeeId,
    int? fromEpoch,
    int? toEpoch,
  }) {
    final q = select(punches);
    q.where((t) {
      Expression<bool> e = const Constant(true);
      if (employeeId != null) e = e & t.employeeId.equals(employeeId);
      final when = coalesce([t.correctedEpoch, t.deviceEpoch]);
      if (fromEpoch != null) e = e & when.isBiggerOrEqualValue(fromEpoch);
      if (toEpoch != null) e = e & when.isSmallerOrEqualValue(toEpoch);
      return e;
    });
    q
      ..orderBy([
        (t) => OrderingTerm.desc(coalesce([t.correctedEpoch, t.deviceEpoch])),
        (t) => OrderingTerm.desc(t.seq),
      ])
      ..limit(limit);
    return q.get();
  }

  /// Punches whose effective time falls in the range. A corrected punch is
  /// found by its corrected time, which is the one the timesheet uses.
  Future<List<PunchRow>> punchesBetween(int fromEpoch, int toEpoch) {
    return (select(punches)
          ..where(
            (t) =>
                t.deviceEpoch.isBetweenValues(fromEpoch, toEpoch) |
                t.correctedEpoch.isBetweenValues(fromEpoch, toEpoch),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.deviceEpoch)]))
        .get();
  }

  /// Sets or clears a corrected time. The recorded time is never touched.
  Future<void> correctPunch(int seq, int? correctedEpoch) =>
      (update(punches)..where((t) => t.seq.equals(seq))).write(
        PunchesCompanion(correctedEpoch: Value(correctedEpoch)),
      );

  /// Only manual rows can be deleted; a device punch is evidence.
  Future<void> deleteManualPunch(int seq) =>
      (delete(punches)..where(
            (t) =>
                t.seq.equals(seq) & t.seq.isBiggerOrEqualValue(manualSeqBase),
          ))
          .go();

  // --- meta --------------------------------------------------------------

  Future<int?> metaInt(String key) async {
    final r = await (select(
      meta,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return r?.value;
  }

  Future<void> setMetaInt(String key, int value) => into(
    meta,
  ).insertOnConflictUpdate(MetaCompanion.insert(key: key, value: value));

  Future<int> punchCount() async {
    final q = selectOnly(punches)..addColumns([punches.seq.count()]);
    final row = await q.getSingle();
    return row.read(punches.seq.count()) ?? 0;
  }

  // --- employees ---------------------------------------------------------

  Future<List<EmployeeRow>> allEmployees() =>
      (select(employees)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();

  Future<EmployeeRow?> employee(int id) =>
      (select(employees)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsertEmployee(EmployeesCompanion row) =>
      into(employees).insertOnConflictUpdate(row);

  /// Marks an employee removed without losing their punches or their name in
  /// past reports.
  Future<void> markEmployeeRemoved(int id, {bool removed = true}) =>
      (update(employees)..where((t) => t.id.equals(id))).write(
        EmployeesCompanion(removed: Value(removed), fingers: const Value(0)),
      );

  /// Drops the row entirely. Only for someone who never punched; anyone with
  /// history is [markEmployeeRemoved] instead.
  Future<void> deleteEmployee(int id) =>
      (delete(employees)..where((t) => t.id.equals(id))).go();

  Future<bool> hasPunches(int employeeId) async {
    final q = selectOnly(punches)
      ..addColumns([punches.seq.count()])
      ..where(punches.employeeId.equals(employeeId));
    final row = await q.getSingle();
    return (row.read(punches.seq.count()) ?? 0) > 0;
  }

  // --- schedules ---------------------------------------------------------

  Future<List<ShiftRow>> allShifts() =>
      (select(shifts)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();

  Future<int> insertShift(ShiftsCompanion row) => into(shifts).insert(row);

  Future<void> upsertShift(ShiftsCompanion row) =>
      into(shifts).insertOnConflictUpdate(row);

  Future<ShiftRow?> defaultShift() => (select(
    shifts,
  )..where((t) => t.isDefault.equals(true))).getSingleOrNull();

  /// Exactly one shift can be the default, so setting one clears the rest.
  Future<void> setDefaultShift(int id) async {
    await transaction(() async {
      await (update(shifts)..where((t) => t.isDefault.equals(true))).write(
        const ShiftsCompanion(isDefault: Value(false)),
      );
      await (update(shifts)..where((t) => t.id.equals(id))).write(
        const ShiftsCompanion(isDefault: Value(true)),
      );
    });
  }

  Future<void> clearAssignmentsFor(int shiftId) =>
      (delete(employeeShifts)..where((t) => t.shiftId.equals(shiftId))).go();

  Future<void> deleteShift(int id) =>
      (delete(shifts)..where((t) => t.id.equals(id))).go();

  Future<List<EmployeeShiftRow>> allEmployeeShifts() =>
      select(employeeShifts).get();

  Future<int> assignShift(EmployeeShiftsCompanion row) =>
      into(employeeShifts).insert(row);

  /// Changes who works [shiftId] from [today] onward without touching the
  /// past.
  ///
  /// The previous approach deleted every assignment for the shift and
  /// re-inserted the selection effective today. That rewrote history: anyone
  /// already on the shift lost their earlier dates, and last month's timesheet
  /// silently recalculated against the default shift. Here, an assignment that
  /// already started is closed off at yesterday instead of deleted, and moving
  /// someone onto this shift closes their other open assignments the same way.
  Future<void> setShiftMembers(
    int shiftId,
    Set<int> employeeIds,
    DateTime today,
  ) async {
    final todayEpoch = _localMidnightEpoch(today);
    final yesterdayEpoch = _localMidnightEpoch(
      DateTime(today.year, today.month, today.day - 1),
    );

    bool isOpen(EmployeeShiftRow a) =>
        a.effectiveTo == null || a.effectiveTo! >= todayEpoch;

    Future<void> end(EmployeeShiftRow a) async {
      if (a.effectiveFrom >= todayEpoch) {
        // Never took effect; nothing in the past depends on it.
        await (delete(employeeShifts)..where((t) => t.id.equals(a.id))).go();
      } else {
        await (update(employeeShifts)..where((t) => t.id.equals(a.id))).write(
          EmployeeShiftsCompanion(effectiveTo: Value(yesterdayEpoch)),
        );
      }
    }

    await transaction(() async {
      final all = await select(employeeShifts).get();
      final open = all.where(isOpen).toList();

      for (final a in open) {
        final keep = employeeIds.contains(a.employeeId);
        if (a.shiftId == shiftId && !keep) await end(a);
        // Joining this shift ends whatever they were on before.
        if (a.shiftId != shiftId && keep) await end(a);
      }

      final already = open
          .where((a) => a.shiftId == shiftId)
          .map((a) => a.employeeId)
          .toSet();
      for (final id in employeeIds.difference(already)) {
        await into(employeeShifts).insert(
          EmployeeShiftsCompanion.insert(
            employeeId: id,
            shiftId: shiftId,
            effectiveFrom: todayEpoch,
          ),
        );
      }
    });
  }

  /// Employees currently on [shiftId], i.e. with an assignment still open.
  Future<Set<int>> currentMembers(int shiftId, DateTime today) async {
    final todayEpoch = _localMidnightEpoch(today);
    final rows = await (select(
      employeeShifts,
    )..where((t) => t.shiftId.equals(shiftId))).get();
    return rows
        .where((a) => a.effectiveTo == null || a.effectiveTo! >= todayEpoch)
        .map((a) => a.employeeId)
        .toSet();
  }

  static int _localMidnightEpoch(DateTime d) =>
      DateTime(d.year, d.month, d.day).toUtc().millisecondsSinceEpoch ~/ 1000;

  /// Roster overrides inside a yyyymmdd range, inclusive.
  Future<List<RosterRow>> rosterBetween(int fromKey, int toKey) => (select(
    rosterEntries,
  )..where((t) => t.dateKey.isBetweenValues(fromKey, toKey))).get();

  Future<int> setRosterEntry(RosterEntriesCompanion row) =>
      into(rosterEntries).insertOnConflictUpdate(row);

  // --- payroll -----------------------------------------------------------

  Future<List<WageRow>> allWages() => select(wages).get();

  Future<void> setWage(WagesCompanion row) =>
      into(wages).insertOnConflictUpdate(row);

  Future<List<PayAdjustmentRow>> payAdjustmentsFor(int monthKey) =>
      (select(payAdjustments)
            ..where((t) => t.monthKey.equals(monthKey))
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();

  Future<int> addPayAdjustment(PayAdjustmentsCompanion row) =>
      into(payAdjustments).insert(row);

  Future<void> deletePayAdjustment(int id) =>
      (delete(payAdjustments)..where((t) => t.id.equals(id))).go();

  Future<List<PayEditRow>> payEditsFor(int monthKey) => (select(
    payEdits,
  )..where((t) => t.monthKey.equals(monthKey))).get();

  Future<void> setPayEdit(PayEditsCompanion row) =>
      into(payEdits).insertOnConflictUpdate(row);

  Future<PayrollRunRow?> payrollRun(int monthKey) => (select(
    payrollRuns,
  )..where((t) => t.monthKey.equals(monthKey))).getSingleOrNull();

  Future<void> savePayrollRun(PayrollRunsCompanion row) =>
      into(payrollRuns).insert(row);

  Future<void> deletePayrollRun(int monthKey) =>
      (delete(payrollRuns)..where((t) => t.monthKey.equals(monthKey))).go();

  // --- audit -------------------------------------------------------------

  Future<void> audit(String action, {int? employeeId, String detail = ''}) {
    return into(auditLog).insert(
      AuditLogCompanion.insert(
        atEpoch: DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
        action: action,
        employeeId: Value(employeeId),
        detail: Value(detail),
      ),
    );
  }

  Future<List<AuditRow>> recentAudit({int limit = 100}) =>
      (select(auditLog)
            ..orderBy([(t) => OrderingTerm.desc(t.id)])
            ..limit(limit))
          .get();
}
