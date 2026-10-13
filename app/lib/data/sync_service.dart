import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../domain/roster_push.dart';
import '../domain/timesheet.dart';
import 'api_client.dart';
import 'database.dart';
import 'device_scanner.dart';
import 'models.dart';
import 'name_raster.dart';
import 'settings.dart';

/// Pulls punches off the terminal into the local database.
///
/// The ordering here is the whole point of the protocol: events are committed
/// locally FIRST, and only then acked. If the app dies between the two, the
/// device still holds the range and simply serves it again on the next pull.
/// Acking first would create a window where a crash silently loses attendance.
class SyncService extends ChangeNotifier {
  SyncService({required this.db, required this.settings});

  final AppDatabase db;
  final Settings settings;

  bool _relocating = false;
  bool get relocating => _relocating;

  ApiClient client() => ApiClient(host: settings.host, token: settings.token);

  DateTime? _lastSync;
  Object? _lastError;
  bool _busy = false;
  int _lastPulled = 0;

  DateTime? get lastSync => _lastSync;
  Object? get lastError => _lastError;
  bool get busy => _busy;
  int get lastPulled => _lastPulled;

  /// Bumped whenever local attendance data changes, so pages reading the
  /// database know to reload instead of showing what they fetched earlier.
  int _revision = 0;
  int get revision => _revision;
  void _changed() {
    _revision++;
    notifyListeners();
  }

  /// Offset from device sequence numbers to local ones. Zero until the
  /// device's counter is seen to go backwards; see [_pullEvents].
  static const _kSeqBase = 'device_seq_base';

  Timer? _timer;

  void startPeriodic({Duration every = const Duration(seconds: 20)}) {
    _timer?.cancel();
    _timer = Timer.periodic(every, (_) => pull());
    pull();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void>? _inflight;

  /// Runs one sync round. A caller arriving mid-round waits for that round
  /// rather than returning at once: "make sure everything is pulled, then
  /// clear the device" must not proceed on the strength of a round that has
  /// not finished.
  Future<void> pull([ApiClient? given]) {
    return _inflight ??= _pull(given).whenComplete(() => _inflight = null);
  }

  Future<void> _pull(ApiClient? given) async {
    _busy = true;
    _lastError = null;
    notifyListeners();

    _given = given;
    try {
      await _round(given ?? client());
      _lastError = null;
    } on ApiException catch (e) {
      // A bad token is not something a different IP fixes, so only go looking
      // for the device when the failure was a network one.
      if (e.isAuthFailure || given != null) {
        _lastError = e;
      } else if (await _relocate()) {
        try {
          await _round(client());
        } catch (e2) {
          _lastError = e2;
        }
      } else {
        _lastError = e;
      }
    } catch (e) {
      _lastError = e;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _round(ApiClient api) async {
    try {
      await _pullEmployees(api);
      _lastPulled = await _pullEvents(api);
      _lastSync = DateTime.now();
      if (_lastPulled > 0) _revision++;
      await _pushRoster(api);
    } finally {
      // Only close clients this service created for itself.
      if (!identical(api, _given)) api.close();
    }
  }

  ApiClient? _given;

  int? _rosterConfirmed;
  DateTime? _rosterCheckedAt;
  Object? _rosterError;

  /// Why the last roster push failed, if it did. Kept apart from [lastError]:
  /// attendance syncing is fine even when this is not.
  Object? get rosterError => _rosterError;

  /// Keeps the terminal's copy of names and upcoming shifts current, so it can
  /// send Telegram alerts with this PC switched off.
  ///
  /// Asks the terminal what it holds only when ours changed, or every ten
  /// minutes in case it was reset -- not on every 20-second round. Never fails
  /// the sync: a terminal with older firmware simply has no /roster.
  Future<void> pushRosterNow(ApiClient api) => _pushRoster(api, force: true);

  Future<void> _pushRoster(ApiClient api, {bool force = false}) async {
    try {
      final payload = await buildRoster(DateTime.now());
      final stale =
          _rosterCheckedAt == null ||
          DateTime.now().difference(_rosterCheckedAt!) >
              const Duration(minutes: 10);
      if (!force && payload.version == _rosterConfirmed && !stale) return;

      final status = await api.notifyStatus();
      if (force || status.rosterVersion != payload.version) {
        await api.pushRoster(
          version: payload.version,
          names: payload.names,
          days: payload.days,
          tzOffsetMin: payload.tzOffsetMin,
        );
      }
      _rosterConfirmed = payload.version;
      _rosterCheckedAt = DateTime.now();
      _rosterError = null;
    } on ApiException catch (e) {
      // 404: firmware from before Telegram support. Not an error worth showing.
      _rosterError = e.statusCode == 404 ? null : e;
      _rosterCheckedAt = DateTime.now();
    } catch (e) {
      _rosterError = e;
    }
  }

  /// Everyone currently on the terminal, with their schedule from [from].
  Future<RosterPayload> buildRoster(DateTime from) async {
    final employees = [
      for (final e in await db.allEmployees())
        if (!e.removed && e.active)
          RosterEmployee(e.id, e.name.isEmpty ? '#${e.id}' : e.name),
    ];
    final to = DateTime(
      from.year,
      from.month,
      from.day + RosterPayload.defaultDays,
    );
    final repo = TimesheetRepository(db);
    await repo.ensureDefaultShift();
    final resolver = await repo.loadResolver(from: from, to: to);
    return RosterPayload.build(
      employees: employees,
      resolver: resolver,
      from: from,
      tzOffsetMin: from.timeZoneOffset.inMinutes,
    );
  }

  /// Finds the terminal again and adopts its new address.
  ///
  /// Searches every candidate network, not just the last one: moving the
  /// device from a PC's shared connection to the real router changes its
  /// subnet entirely, and a sweep limited to the old one would never find it.
  Future<bool> _relocate() async {
    if (_relocating) return false;
    _relocating = true;
    notifyListeners();

    final scanner = DeviceScanner();
    try {
      final found = await scanner.locate(lastKnownHost: settings.host);
      if (found == null || found == settings.host) return false;

      await settings.setHost(found);
      return true;
    } catch (_) {
      return false;
    } finally {
      scanner.close();
      _relocating = false;
      notifyListeners();
    }
  }

  /// Device-side counters (finger count, failed reads) are authoritative;
  /// names live only here, so they must not be clobbered by a pull.
  Future<void> _pullEmployees(ApiClient api) async {
    final remote = await api.employees();
    final onDevice = <int>{};
    for (final e in remote) {
      onDevice.add(e.id);
      final local = await db.employee(e.id);
      await db.upsertEmployee(
        EmployeesCompanion(
          id: Value(e.id),
          name: local == null ? const Value('') : Value(local.name),
          jobTitle: local == null ? const Value('') : Value(local.jobTitle),
          active: Value(e.active),
          fingers: Value(e.fingers),
          failCount: Value(e.failCount),
          // On the terminal again, so no longer removed.
          removed: const Value(false),
        ),
      );
    }
    // Someone the terminal no longer has (fingerprints were cleared) has no
    // usable fingers, whatever the cached count said.
    for (final local in await db.allEmployees()) {
      if (!onDevice.contains(local.id) && local.fingers != 0) {
        await db.upsertEmployee(
          EmployeesCompanion(id: Value(local.id), fingers: const Value(0)),
        );
      }
    }
  }

  /// Imports new punches, committing locally before acking.
  ///
  /// Local rows are numbered `device seq + base`. The base starts at zero and
  /// only moves when the device's counter is seen to go backwards, which
  /// happens when its log is cleared (older firmware restarted numbering at 1)
  /// or a different terminal is connected. Without this, the app asked for
  /// events after a number the device would not reach for months -- syncing
  /// silently stopped -- and once it did, new punches overwrote old ones that
  /// shared their sequence number.
  Future<int> _pullEvents(ApiClient api) async {
    final localTop = await db.highWaterSeq();
    var base = await db.metaInt(_kSeqBase) ?? 0;
    var since = localTop - base;
    if (since < 0) since = 0;

    if (since > 0 && await _deviceWasReset(api, since, base)) {
      base = localTop;
      await db.setMetaInt(_kSeqBase, base);
      await db.audit(
        'device.sequence_reset',
        detail:
            'device numbering restarted; local numbering continues '
            'from $base',
      );
      since = 0;
    }

    var total = 0;
    var ackThrough = 0;

    // Page until the device stops handing us records. The device caps a
    // response at 100, so a long offline stretch drains over several rounds.
    while (true) {
      final page = await api.eventsPage(since: since, limit: 100);
      final batch = page.events;
      if (batch.isEmpty) break;

      final b = base;
      await db.storePunches(
        batch.map(
          (e) => PunchesCompanion.insert(
            seq: Value(e.seq + b),
            deviceEpoch: e.epoch,
            employeeId: e.employeeId,
            slot: Value(e.slot),
            direction: e.direction == PunchDirection.outbound ? 1 : 0,
            method: Value(switch (e.method) {
              PunchMethod.manual => 1,
              PunchMethod.pin => 2,
              PunchMethod.finger => 0,
            }),
            provisionalTime: Value(e.provisionalTime),
          ),
        ),
      );

      since = batch.last.seq;
      ackThrough = since;
      total += batch.length;
      if (batch.length < 100) break;
    }

    // Committed above, so it is now safe to let the device reclaim the space.
    if (ackThrough > 0) {
      await api.ack(ackThrough);
    }
    return total;
  }

  /// Whether the device's numbering no longer continues from ours.
  ///
  /// Two checks. The cheap one: the device's newest number is below the last
  /// one we stored. The thorough one: the device still holds the record we
  /// stored last, so it must be the *same* record -- if its time or employee
  /// differ, the log was cleared and has since grown back past our mark.
  /// When the ring has already wrapped past that record there is nothing left
  /// to compare, and the overflow warning is the honest signal.
  Future<bool> _deviceWasReset(ApiClient api, int since, int base) async {
    final probe = await api.eventsPage(since: since - 1, limit: 1);
    if (probe.stats.head < since) return true;
    if (probe.events.isEmpty || probe.events.first.seq != since) return false;

    final theirs = probe.events.first;
    final ours = await db.punch(since + base);
    if (ours == null) return false;
    return ours.deviceEpoch != theirs.epoch ||
        ours.employeeId != theirs.employeeId;
  }

  /// Creates or updates an employee on both sides, rendering their name to the
  /// bitmap the terminal displays (D3).
  Future<void> saveEmployee(
    ApiClient api, {
    required int id,
    required String name,
    String jobTitle = '',
    bool active = true,
  }) async {
    final bitmap = name.trim().isEmpty ? null : await NameRaster.render(name);

    await api.upsertEmployee(id, active: active, nameBitmap: bitmap);
    await db.upsertEmployee(
      EmployeesCompanion(
        id: Value(id),
        name: Value(name),
        jobTitle: Value(jobTitle),
        active: Value(active),
        removed: const Value(false),
      ),
    );
    await db.audit('employee.save', employeeId: id, detail: name);
    _changed();
  }

  /// Removes someone from the terminal. Their punches and name stay here, so
  /// past timesheets still add up; only a person with no history at all is
  /// dropped outright.
  Future<void> removeEmployee(ApiClient api, int id) async {
    await api.deleteEmployee(id);
    if (await db.hasPunches(id)) {
      await db.markEmployeeRemoved(id);
    } else {
      await db.deleteEmployee(id);
    }
    await db.audit('employee.delete', employeeId: id);
    _changed();
  }

  /// Sets a corrected time on a punch, or clears it with null. The recorded
  /// time is kept; the timesheet prefers the correction.
  Future<void> correctPunch({
    required int seq,
    required DateTime? at,
    required String reason,
  }) async {
    final row = await db.punch(seq);
    if (row == null) return;
    await db.correctPunch(
      seq,
      at == null ? null : at.toUtc().millisecondsSinceEpoch ~/ 1000,
    );
    await db.audit(
      'punch.correct',
      employeeId: row.employeeId,
      detail: at == null
          ? 'seq $seq: correction removed: $reason'
          : 'seq $seq -> ${at.toIso8601String()}: $reason',
    );
    _changed();
  }

  /// Deletes a manual punch entered by mistake. Device punches cannot be
  /// deleted, only corrected.
  Future<void> deleteManualPunch(int seq, {String reason = ''}) async {
    final row = await db.punch(seq);
    if (row == null || seq < AppDatabase.manualSeqBase) return;
    await db.deleteManualPunch(seq);
    await db.audit(
      'punch.manual_delete',
      employeeId: row.employeeId,
      detail: 'seq $seq: $reason',
    );
    _changed();
  }

  /// Manager-entered punch, for when a finger will not read (D5). Recorded
  /// locally only -- the device is the source of truth for scans, not for
  /// corrections -- and always flagged plus audited so it stays visible.
  Future<void> addManualPunch({
    required int employeeId,
    required DateTime at,
    required bool isOut,
    required String reason,
  }) async {
    // Manual rows sit above the device's sequence space so they can never
    // collide with a real punch the device has yet to send -- and the device
    // high-water mark ignores them, so they never stall the next pull.
    final seq = await db.nextManualSeq();

    await db.storePunches([
      PunchesCompanion.insert(
        seq: Value(seq),
        deviceEpoch: at.toUtc().millisecondsSinceEpoch ~/ 1000,
        employeeId: employeeId,
        direction: isOut ? 1 : 0,
        method: const Value(1),
      ),
    ]);
    await db.audit(
      'punch.manual',
      employeeId: employeeId,
      detail: '${isOut ? 'out' : 'in'} at ${at.toIso8601String()}: $reason',
    );
    _changed();
  }
}
