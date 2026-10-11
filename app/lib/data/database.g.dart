// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $EmployeesTable extends Employees
    with TableInfo<$EmployeesTable, EmployeeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EmployeesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _jobTitleMeta = const VerificationMeta(
    'jobTitle',
  );
  @override
  late final GeneratedColumn<String> jobTitle = GeneratedColumn<String>(
    'job_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _fingersMeta = const VerificationMeta(
    'fingers',
  );
  @override
  late final GeneratedColumn<int> fingers = GeneratedColumn<int>(
    'fingers',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _failCountMeta = const VerificationMeta(
    'failCount',
  );
  @override
  late final GeneratedColumn<int> failCount = GeneratedColumn<int>(
    'fail_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _removedMeta = const VerificationMeta(
    'removed',
  );
  @override
  late final GeneratedColumn<bool> removed = GeneratedColumn<bool>(
    'removed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("removed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    jobTitle,
    active,
    fingers,
    failCount,
    removed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'employees';
  @override
  VerificationContext validateIntegrity(
    Insertable<EmployeeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('job_title')) {
      context.handle(
        _jobTitleMeta,
        jobTitle.isAcceptableOrUnknown(data['job_title']!, _jobTitleMeta),
      );
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    if (data.containsKey('fingers')) {
      context.handle(
        _fingersMeta,
        fingers.isAcceptableOrUnknown(data['fingers']!, _fingersMeta),
      );
    }
    if (data.containsKey('fail_count')) {
      context.handle(
        _failCountMeta,
        failCount.isAcceptableOrUnknown(data['fail_count']!, _failCountMeta),
      );
    }
    if (data.containsKey('removed')) {
      context.handle(
        _removedMeta,
        removed.isAcceptableOrUnknown(data['removed']!, _removedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EmployeeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EmployeeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      jobTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}job_title'],
      )!,
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      fingers: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fingers'],
      )!,
      failCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fail_count'],
      )!,
      removed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}removed'],
      )!,
    );
  }

  @override
  $EmployeesTable createAlias(String alias) {
    return $EmployeesTable(attachedDatabase, alias);
  }
}

class EmployeeRow extends DataClass implements Insertable<EmployeeRow> {
  final int id;

  /// Real Arabic (or Latin) name. The 1bpp bitmap pushed to the device is
  /// rendered from this; the device itself never stores text.
  final String name;
  final String jobTitle;
  final bool active;

  /// Cached from the device so the roster renders without a round trip.
  final int fingers;
  final int failCount;

  /// Removed from the terminal, but kept here. Deleting the row outright took
  /// the person's history out of every past timesheet with it -- payroll for
  /// a month someone worked must not depend on whether they still work here.
  final bool removed;
  const EmployeeRow({
    required this.id,
    required this.name,
    required this.jobTitle,
    required this.active,
    required this.fingers,
    required this.failCount,
    required this.removed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['job_title'] = Variable<String>(jobTitle);
    map['active'] = Variable<bool>(active);
    map['fingers'] = Variable<int>(fingers);
    map['fail_count'] = Variable<int>(failCount);
    map['removed'] = Variable<bool>(removed);
    return map;
  }

  EmployeesCompanion toCompanion(bool nullToAbsent) {
    return EmployeesCompanion(
      id: Value(id),
      name: Value(name),
      jobTitle: Value(jobTitle),
      active: Value(active),
      fingers: Value(fingers),
      failCount: Value(failCount),
      removed: Value(removed),
    );
  }

  factory EmployeeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EmployeeRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      jobTitle: serializer.fromJson<String>(json['jobTitle']),
      active: serializer.fromJson<bool>(json['active']),
      fingers: serializer.fromJson<int>(json['fingers']),
      failCount: serializer.fromJson<int>(json['failCount']),
      removed: serializer.fromJson<bool>(json['removed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'jobTitle': serializer.toJson<String>(jobTitle),
      'active': serializer.toJson<bool>(active),
      'fingers': serializer.toJson<int>(fingers),
      'failCount': serializer.toJson<int>(failCount),
      'removed': serializer.toJson<bool>(removed),
    };
  }

  EmployeeRow copyWith({
    int? id,
    String? name,
    String? jobTitle,
    bool? active,
    int? fingers,
    int? failCount,
    bool? removed,
  }) => EmployeeRow(
    id: id ?? this.id,
    name: name ?? this.name,
    jobTitle: jobTitle ?? this.jobTitle,
    active: active ?? this.active,
    fingers: fingers ?? this.fingers,
    failCount: failCount ?? this.failCount,
    removed: removed ?? this.removed,
  );
  EmployeeRow copyWithCompanion(EmployeesCompanion data) {
    return EmployeeRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      jobTitle: data.jobTitle.present ? data.jobTitle.value : this.jobTitle,
      active: data.active.present ? data.active.value : this.active,
      fingers: data.fingers.present ? data.fingers.value : this.fingers,
      failCount: data.failCount.present ? data.failCount.value : this.failCount,
      removed: data.removed.present ? data.removed.value : this.removed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EmployeeRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('jobTitle: $jobTitle, ')
          ..write('active: $active, ')
          ..write('fingers: $fingers, ')
          ..write('failCount: $failCount, ')
          ..write('removed: $removed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, jobTitle, active, fingers, failCount, removed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EmployeeRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.jobTitle == this.jobTitle &&
          other.active == this.active &&
          other.fingers == this.fingers &&
          other.failCount == this.failCount &&
          other.removed == this.removed);
}

class EmployeesCompanion extends UpdateCompanion<EmployeeRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> jobTitle;
  final Value<bool> active;
  final Value<int> fingers;
  final Value<int> failCount;
  final Value<bool> removed;
  const EmployeesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.jobTitle = const Value.absent(),
    this.active = const Value.absent(),
    this.fingers = const Value.absent(),
    this.failCount = const Value.absent(),
    this.removed = const Value.absent(),
  });
  EmployeesCompanion.insert({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.jobTitle = const Value.absent(),
    this.active = const Value.absent(),
    this.fingers = const Value.absent(),
    this.failCount = const Value.absent(),
    this.removed = const Value.absent(),
  });
  static Insertable<EmployeeRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? jobTitle,
    Expression<bool>? active,
    Expression<int>? fingers,
    Expression<int>? failCount,
    Expression<bool>? removed,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (jobTitle != null) 'job_title': jobTitle,
      if (active != null) 'active': active,
      if (fingers != null) 'fingers': fingers,
      if (failCount != null) 'fail_count': failCount,
      if (removed != null) 'removed': removed,
    });
  }

  EmployeesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? jobTitle,
    Value<bool>? active,
    Value<int>? fingers,
    Value<int>? failCount,
    Value<bool>? removed,
  }) {
    return EmployeesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      jobTitle: jobTitle ?? this.jobTitle,
      active: active ?? this.active,
      fingers: fingers ?? this.fingers,
      failCount: failCount ?? this.failCount,
      removed: removed ?? this.removed,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (jobTitle.present) {
      map['job_title'] = Variable<String>(jobTitle.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (fingers.present) {
      map['fingers'] = Variable<int>(fingers.value);
    }
    if (failCount.present) {
      map['fail_count'] = Variable<int>(failCount.value);
    }
    if (removed.present) {
      map['removed'] = Variable<bool>(removed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EmployeesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('jobTitle: $jobTitle, ')
          ..write('active: $active, ')
          ..write('fingers: $fingers, ')
          ..write('failCount: $failCount, ')
          ..write('removed: $removed')
          ..write(')'))
        .toString();
  }
}

class $PunchesTable extends Punches with TableInfo<$PunchesTable, PunchRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PunchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceEpochMeta = const VerificationMeta(
    'deviceEpoch',
  );
  @override
  late final GeneratedColumn<int> deviceEpoch = GeneratedColumn<int>(
    'device_epoch',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _employeeIdMeta = const VerificationMeta(
    'employeeId',
  );
  @override
  late final GeneratedColumn<int> employeeId = GeneratedColumn<int>(
    'employee_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _slotMeta = const VerificationMeta('slot');
  @override
  late final GeneratedColumn<int> slot = GeneratedColumn<int>(
    'slot',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _directionMeta = const VerificationMeta(
    'direction',
  );
  @override
  late final GeneratedColumn<int> direction = GeneratedColumn<int>(
    'direction',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<int> method = GeneratedColumn<int>(
    'method',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _provisionalTimeMeta = const VerificationMeta(
    'provisionalTime',
  );
  @override
  late final GeneratedColumn<bool> provisionalTime = GeneratedColumn<bool>(
    'provisional_time',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("provisional_time" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _correctedEpochMeta = const VerificationMeta(
    'correctedEpoch',
  );
  @override
  late final GeneratedColumn<int> correctedEpoch = GeneratedColumn<int>(
    'corrected_epoch',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    seq,
    deviceEpoch,
    employeeId,
    slot,
    direction,
    method,
    provisionalTime,
    correctedEpoch,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'punches';
  @override
  VerificationContext validateIntegrity(
    Insertable<PunchRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('device_epoch')) {
      context.handle(
        _deviceEpochMeta,
        deviceEpoch.isAcceptableOrUnknown(
          data['device_epoch']!,
          _deviceEpochMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_deviceEpochMeta);
    }
    if (data.containsKey('employee_id')) {
      context.handle(
        _employeeIdMeta,
        employeeId.isAcceptableOrUnknown(data['employee_id']!, _employeeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_employeeIdMeta);
    }
    if (data.containsKey('slot')) {
      context.handle(
        _slotMeta,
        slot.isAcceptableOrUnknown(data['slot']!, _slotMeta),
      );
    }
    if (data.containsKey('direction')) {
      context.handle(
        _directionMeta,
        direction.isAcceptableOrUnknown(data['direction']!, _directionMeta),
      );
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('method')) {
      context.handle(
        _methodMeta,
        method.isAcceptableOrUnknown(data['method']!, _methodMeta),
      );
    }
    if (data.containsKey('provisional_time')) {
      context.handle(
        _provisionalTimeMeta,
        provisionalTime.isAcceptableOrUnknown(
          data['provisional_time']!,
          _provisionalTimeMeta,
        ),
      );
    }
    if (data.containsKey('corrected_epoch')) {
      context.handle(
        _correctedEpochMeta,
        correctedEpoch.isAcceptableOrUnknown(
          data['corrected_epoch']!,
          _correctedEpochMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  PunchRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PunchRow(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      deviceEpoch: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}device_epoch'],
      )!,
      employeeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}employee_id'],
      )!,
      slot: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}slot'],
      )!,
      direction: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}direction'],
      )!,
      method: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}method'],
      )!,
      provisionalTime: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}provisional_time'],
      )!,
      correctedEpoch: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}corrected_epoch'],
      ),
    );
  }

  @override
  $PunchesTable createAlias(String alias) {
    return $PunchesTable(attachedDatabase, alias);
  }
}

class PunchRow extends DataClass implements Insertable<PunchRow> {
  /// Device sequence number. Monotonic and never reused, which makes it a
  /// natural primary key and gives us idempotent re-imports for free: pulling
  /// an already-stored range simply overwrites identical rows.
  final int seq;
  final int deviceEpoch;
  final int employeeId;
  final int slot;

  /// 0 = in, 1 = out.
  final int direction;

  /// 0 = finger, 1 = manual, 2 = pin.
  final int method;

  /// The device could not verify its clock (D7). Kept as recorded; corrections
  /// go in [correctedEpoch] so the original is never overwritten.
  final bool provisionalTime;
  final int? correctedEpoch;
  const PunchRow({
    required this.seq,
    required this.deviceEpoch,
    required this.employeeId,
    required this.slot,
    required this.direction,
    required this.method,
    required this.provisionalTime,
    this.correctedEpoch,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['device_epoch'] = Variable<int>(deviceEpoch);
    map['employee_id'] = Variable<int>(employeeId);
    map['slot'] = Variable<int>(slot);
    map['direction'] = Variable<int>(direction);
    map['method'] = Variable<int>(method);
    map['provisional_time'] = Variable<bool>(provisionalTime);
    if (!nullToAbsent || correctedEpoch != null) {
      map['corrected_epoch'] = Variable<int>(correctedEpoch);
    }
    return map;
  }

  PunchesCompanion toCompanion(bool nullToAbsent) {
    return PunchesCompanion(
      seq: Value(seq),
      deviceEpoch: Value(deviceEpoch),
      employeeId: Value(employeeId),
      slot: Value(slot),
      direction: Value(direction),
      method: Value(method),
      provisionalTime: Value(provisionalTime),
      correctedEpoch: correctedEpoch == null && nullToAbsent
          ? const Value.absent()
          : Value(correctedEpoch),
    );
  }

  factory PunchRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PunchRow(
      seq: serializer.fromJson<int>(json['seq']),
      deviceEpoch: serializer.fromJson<int>(json['deviceEpoch']),
      employeeId: serializer.fromJson<int>(json['employeeId']),
      slot: serializer.fromJson<int>(json['slot']),
      direction: serializer.fromJson<int>(json['direction']),
      method: serializer.fromJson<int>(json['method']),
      provisionalTime: serializer.fromJson<bool>(json['provisionalTime']),
      correctedEpoch: serializer.fromJson<int?>(json['correctedEpoch']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'deviceEpoch': serializer.toJson<int>(deviceEpoch),
      'employeeId': serializer.toJson<int>(employeeId),
      'slot': serializer.toJson<int>(slot),
      'direction': serializer.toJson<int>(direction),
      'method': serializer.toJson<int>(method),
      'provisionalTime': serializer.toJson<bool>(provisionalTime),
      'correctedEpoch': serializer.toJson<int?>(correctedEpoch),
    };
  }

  PunchRow copyWith({
    int? seq,
    int? deviceEpoch,
    int? employeeId,
    int? slot,
    int? direction,
    int? method,
    bool? provisionalTime,
    Value<int?> correctedEpoch = const Value.absent(),
  }) => PunchRow(
    seq: seq ?? this.seq,
    deviceEpoch: deviceEpoch ?? this.deviceEpoch,
    employeeId: employeeId ?? this.employeeId,
    slot: slot ?? this.slot,
    direction: direction ?? this.direction,
    method: method ?? this.method,
    provisionalTime: provisionalTime ?? this.provisionalTime,
    correctedEpoch: correctedEpoch.present
        ? correctedEpoch.value
        : this.correctedEpoch,
  );
  PunchRow copyWithCompanion(PunchesCompanion data) {
    return PunchRow(
      seq: data.seq.present ? data.seq.value : this.seq,
      deviceEpoch: data.deviceEpoch.present
          ? data.deviceEpoch.value
          : this.deviceEpoch,
      employeeId: data.employeeId.present
          ? data.employeeId.value
          : this.employeeId,
      slot: data.slot.present ? data.slot.value : this.slot,
      direction: data.direction.present ? data.direction.value : this.direction,
      method: data.method.present ? data.method.value : this.method,
      provisionalTime: data.provisionalTime.present
          ? data.provisionalTime.value
          : this.provisionalTime,
      correctedEpoch: data.correctedEpoch.present
          ? data.correctedEpoch.value
          : this.correctedEpoch,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PunchRow(')
          ..write('seq: $seq, ')
          ..write('deviceEpoch: $deviceEpoch, ')
          ..write('employeeId: $employeeId, ')
          ..write('slot: $slot, ')
          ..write('direction: $direction, ')
          ..write('method: $method, ')
          ..write('provisionalTime: $provisionalTime, ')
          ..write('correctedEpoch: $correctedEpoch')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    seq,
    deviceEpoch,
    employeeId,
    slot,
    direction,
    method,
    provisionalTime,
    correctedEpoch,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PunchRow &&
          other.seq == this.seq &&
          other.deviceEpoch == this.deviceEpoch &&
          other.employeeId == this.employeeId &&
          other.slot == this.slot &&
          other.direction == this.direction &&
          other.method == this.method &&
          other.provisionalTime == this.provisionalTime &&
          other.correctedEpoch == this.correctedEpoch);
}

class PunchesCompanion extends UpdateCompanion<PunchRow> {
  final Value<int> seq;
  final Value<int> deviceEpoch;
  final Value<int> employeeId;
  final Value<int> slot;
  final Value<int> direction;
  final Value<int> method;
  final Value<bool> provisionalTime;
  final Value<int?> correctedEpoch;
  const PunchesCompanion({
    this.seq = const Value.absent(),
    this.deviceEpoch = const Value.absent(),
    this.employeeId = const Value.absent(),
    this.slot = const Value.absent(),
    this.direction = const Value.absent(),
    this.method = const Value.absent(),
    this.provisionalTime = const Value.absent(),
    this.correctedEpoch = const Value.absent(),
  });
  PunchesCompanion.insert({
    this.seq = const Value.absent(),
    required int deviceEpoch,
    required int employeeId,
    this.slot = const Value.absent(),
    required int direction,
    this.method = const Value.absent(),
    this.provisionalTime = const Value.absent(),
    this.correctedEpoch = const Value.absent(),
  }) : deviceEpoch = Value(deviceEpoch),
       employeeId = Value(employeeId),
       direction = Value(direction);
  static Insertable<PunchRow> custom({
    Expression<int>? seq,
    Expression<int>? deviceEpoch,
    Expression<int>? employeeId,
    Expression<int>? slot,
    Expression<int>? direction,
    Expression<int>? method,
    Expression<bool>? provisionalTime,
    Expression<int>? correctedEpoch,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (deviceEpoch != null) 'device_epoch': deviceEpoch,
      if (employeeId != null) 'employee_id': employeeId,
      if (slot != null) 'slot': slot,
      if (direction != null) 'direction': direction,
      if (method != null) 'method': method,
      if (provisionalTime != null) 'provisional_time': provisionalTime,
      if (correctedEpoch != null) 'corrected_epoch': correctedEpoch,
    });
  }

  PunchesCompanion copyWith({
    Value<int>? seq,
    Value<int>? deviceEpoch,
    Value<int>? employeeId,
    Value<int>? slot,
    Value<int>? direction,
    Value<int>? method,
    Value<bool>? provisionalTime,
    Value<int?>? correctedEpoch,
  }) {
    return PunchesCompanion(
      seq: seq ?? this.seq,
      deviceEpoch: deviceEpoch ?? this.deviceEpoch,
      employeeId: employeeId ?? this.employeeId,
      slot: slot ?? this.slot,
      direction: direction ?? this.direction,
      method: method ?? this.method,
      provisionalTime: provisionalTime ?? this.provisionalTime,
      correctedEpoch: correctedEpoch ?? this.correctedEpoch,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (deviceEpoch.present) {
      map['device_epoch'] = Variable<int>(deviceEpoch.value);
    }
    if (employeeId.present) {
      map['employee_id'] = Variable<int>(employeeId.value);
    }
    if (slot.present) {
      map['slot'] = Variable<int>(slot.value);
    }
    if (direction.present) {
      map['direction'] = Variable<int>(direction.value);
    }
    if (method.present) {
      map['method'] = Variable<int>(method.value);
    }
    if (provisionalTime.present) {
      map['provisional_time'] = Variable<bool>(provisionalTime.value);
    }
    if (correctedEpoch.present) {
      map['corrected_epoch'] = Variable<int>(correctedEpoch.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PunchesCompanion(')
          ..write('seq: $seq, ')
          ..write('deviceEpoch: $deviceEpoch, ')
          ..write('employeeId: $employeeId, ')
          ..write('slot: $slot, ')
          ..write('direction: $direction, ')
          ..write('method: $method, ')
          ..write('provisionalTime: $provisionalTime, ')
          ..write('correctedEpoch: $correctedEpoch')
          ..write(')'))
        .toString();
  }
}

class $AuditLogTable extends AuditLog with TableInfo<$AuditLogTable, AuditRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AuditLogTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _atEpochMeta = const VerificationMeta(
    'atEpoch',
  );
  @override
  late final GeneratedColumn<int> atEpoch = GeneratedColumn<int>(
    'at_epoch',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _employeeIdMeta = const VerificationMeta(
    'employeeId',
  );
  @override
  late final GeneratedColumn<int> employeeId = GeneratedColumn<int>(
    'employee_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _detailMeta = const VerificationMeta('detail');
  @override
  late final GeneratedColumn<String> detail = GeneratedColumn<String>(
    'detail',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    atEpoch,
    action,
    employeeId,
    detail,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audit_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<AuditRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('at_epoch')) {
      context.handle(
        _atEpochMeta,
        atEpoch.isAcceptableOrUnknown(data['at_epoch']!, _atEpochMeta),
      );
    } else if (isInserting) {
      context.missing(_atEpochMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('employee_id')) {
      context.handle(
        _employeeIdMeta,
        employeeId.isAcceptableOrUnknown(data['employee_id']!, _employeeIdMeta),
      );
    }
    if (data.containsKey('detail')) {
      context.handle(
        _detailMeta,
        detail.isAcceptableOrUnknown(data['detail']!, _detailMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AuditRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AuditRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      atEpoch: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at_epoch'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      employeeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}employee_id'],
      ),
      detail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail'],
      )!,
    );
  }

  @override
  $AuditLogTable createAlias(String alias) {
    return $AuditLogTable(attachedDatabase, alias);
  }
}

class AuditRow extends DataClass implements Insertable<AuditRow> {
  final int id;
  final int atEpoch;
  final String action;
  final int? employeeId;
  final String detail;
  const AuditRow({
    required this.id,
    required this.atEpoch,
    required this.action,
    this.employeeId,
    required this.detail,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['at_epoch'] = Variable<int>(atEpoch);
    map['action'] = Variable<String>(action);
    if (!nullToAbsent || employeeId != null) {
      map['employee_id'] = Variable<int>(employeeId);
    }
    map['detail'] = Variable<String>(detail);
    return map;
  }

  AuditLogCompanion toCompanion(bool nullToAbsent) {
    return AuditLogCompanion(
      id: Value(id),
      atEpoch: Value(atEpoch),
      action: Value(action),
      employeeId: employeeId == null && nullToAbsent
          ? const Value.absent()
          : Value(employeeId),
      detail: Value(detail),
    );
  }

  factory AuditRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AuditRow(
      id: serializer.fromJson<int>(json['id']),
      atEpoch: serializer.fromJson<int>(json['atEpoch']),
      action: serializer.fromJson<String>(json['action']),
      employeeId: serializer.fromJson<int?>(json['employeeId']),
      detail: serializer.fromJson<String>(json['detail']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'atEpoch': serializer.toJson<int>(atEpoch),
      'action': serializer.toJson<String>(action),
      'employeeId': serializer.toJson<int?>(employeeId),
      'detail': serializer.toJson<String>(detail),
    };
  }

  AuditRow copyWith({
    int? id,
    int? atEpoch,
    String? action,
    Value<int?> employeeId = const Value.absent(),
    String? detail,
  }) => AuditRow(
    id: id ?? this.id,
    atEpoch: atEpoch ?? this.atEpoch,
    action: action ?? this.action,
    employeeId: employeeId.present ? employeeId.value : this.employeeId,
    detail: detail ?? this.detail,
  );
  AuditRow copyWithCompanion(AuditLogCompanion data) {
    return AuditRow(
      id: data.id.present ? data.id.value : this.id,
      atEpoch: data.atEpoch.present ? data.atEpoch.value : this.atEpoch,
      action: data.action.present ? data.action.value : this.action,
      employeeId: data.employeeId.present
          ? data.employeeId.value
          : this.employeeId,
      detail: data.detail.present ? data.detail.value : this.detail,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AuditRow(')
          ..write('id: $id, ')
          ..write('atEpoch: $atEpoch, ')
          ..write('action: $action, ')
          ..write('employeeId: $employeeId, ')
          ..write('detail: $detail')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, atEpoch, action, employeeId, detail);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuditRow &&
          other.id == this.id &&
          other.atEpoch == this.atEpoch &&
          other.action == this.action &&
          other.employeeId == this.employeeId &&
          other.detail == this.detail);
}

class AuditLogCompanion extends UpdateCompanion<AuditRow> {
  final Value<int> id;
  final Value<int> atEpoch;
  final Value<String> action;
  final Value<int?> employeeId;
  final Value<String> detail;
  const AuditLogCompanion({
    this.id = const Value.absent(),
    this.atEpoch = const Value.absent(),
    this.action = const Value.absent(),
    this.employeeId = const Value.absent(),
    this.detail = const Value.absent(),
  });
  AuditLogCompanion.insert({
    this.id = const Value.absent(),
    required int atEpoch,
    required String action,
    this.employeeId = const Value.absent(),
    this.detail = const Value.absent(),
  }) : atEpoch = Value(atEpoch),
       action = Value(action);
  static Insertable<AuditRow> custom({
    Expression<int>? id,
    Expression<int>? atEpoch,
    Expression<String>? action,
    Expression<int>? employeeId,
    Expression<String>? detail,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (atEpoch != null) 'at_epoch': atEpoch,
      if (action != null) 'action': action,
      if (employeeId != null) 'employee_id': employeeId,
      if (detail != null) 'detail': detail,
    });
  }

  AuditLogCompanion copyWith({
    Value<int>? id,
    Value<int>? atEpoch,
    Value<String>? action,
    Value<int?>? employeeId,
    Value<String>? detail,
  }) {
    return AuditLogCompanion(
      id: id ?? this.id,
      atEpoch: atEpoch ?? this.atEpoch,
      action: action ?? this.action,
      employeeId: employeeId ?? this.employeeId,
      detail: detail ?? this.detail,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (atEpoch.present) {
      map['at_epoch'] = Variable<int>(atEpoch.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (employeeId.present) {
      map['employee_id'] = Variable<int>(employeeId.value);
    }
    if (detail.present) {
      map['detail'] = Variable<String>(detail.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AuditLogCompanion(')
          ..write('id: $id, ')
          ..write('atEpoch: $atEpoch, ')
          ..write('action: $action, ')
          ..write('employeeId: $employeeId, ')
          ..write('detail: $detail')
          ..write(')'))
        .toString();
  }
}

class $ShiftsTable extends Shifts with TableInfo<$ShiftsTable, ShiftRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShiftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<int> kind = GeneratedColumn<int>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _startMinuteMeta = const VerificationMeta(
    'startMinute',
  );
  @override
  late final GeneratedColumn<int> startMinute = GeneratedColumn<int>(
    'start_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(540),
  );
  static const VerificationMeta _endMinuteMeta = const VerificationMeta(
    'endMinute',
  );
  @override
  late final GeneratedColumn<int> endMinute = GeneratedColumn<int>(
    'end_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1020),
  );
  static const VerificationMeta _breakMinutesMeta = const VerificationMeta(
    'breakMinutes',
  );
  @override
  late final GeneratedColumn<int> breakMinutes = GeneratedColumn<int>(
    'break_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _graceInMinutesMeta = const VerificationMeta(
    'graceInMinutes',
  );
  @override
  late final GeneratedColumn<int> graceInMinutes = GeneratedColumn<int>(
    'grace_in_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(10),
  );
  static const VerificationMeta _graceOutMinutesMeta = const VerificationMeta(
    'graceOutMinutes',
  );
  @override
  late final GeneratedColumn<int> graceOutMinutes = GeneratedColumn<int>(
    'grace_out_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(10),
  );
  static const VerificationMeta _requiredMinutesMeta = const VerificationMeta(
    'requiredMinutes',
  );
  @override
  late final GeneratedColumn<int> requiredMinutes = GeneratedColumn<int>(
    'required_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(480),
  );
  static const VerificationMeta _daysMaskMeta = const VerificationMeta(
    'daysMask',
  );
  @override
  late final GeneratedColumn<int> daysMask = GeneratedColumn<int>(
    'days_mask',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0x3E),
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    kind,
    startMinute,
    endMinute,
    breakMinutes,
    graceInMinutes,
    graceOutMinutes,
    requiredMinutes,
    daysMask,
    isDefault,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shifts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShiftRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('start_minute')) {
      context.handle(
        _startMinuteMeta,
        startMinute.isAcceptableOrUnknown(
          data['start_minute']!,
          _startMinuteMeta,
        ),
      );
    }
    if (data.containsKey('end_minute')) {
      context.handle(
        _endMinuteMeta,
        endMinute.isAcceptableOrUnknown(data['end_minute']!, _endMinuteMeta),
      );
    }
    if (data.containsKey('break_minutes')) {
      context.handle(
        _breakMinutesMeta,
        breakMinutes.isAcceptableOrUnknown(
          data['break_minutes']!,
          _breakMinutesMeta,
        ),
      );
    }
    if (data.containsKey('grace_in_minutes')) {
      context.handle(
        _graceInMinutesMeta,
        graceInMinutes.isAcceptableOrUnknown(
          data['grace_in_minutes']!,
          _graceInMinutesMeta,
        ),
      );
    }
    if (data.containsKey('grace_out_minutes')) {
      context.handle(
        _graceOutMinutesMeta,
        graceOutMinutes.isAcceptableOrUnknown(
          data['grace_out_minutes']!,
          _graceOutMinutesMeta,
        ),
      );
    }
    if (data.containsKey('required_minutes')) {
      context.handle(
        _requiredMinutesMeta,
        requiredMinutes.isAcceptableOrUnknown(
          data['required_minutes']!,
          _requiredMinutesMeta,
        ),
      );
    }
    if (data.containsKey('days_mask')) {
      context.handle(
        _daysMaskMeta,
        daysMask.isAcceptableOrUnknown(data['days_mask']!, _daysMaskMeta),
      );
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ShiftRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShiftRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kind'],
      )!,
      startMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_minute'],
      )!,
      endMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_minute'],
      )!,
      breakMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}break_minutes'],
      )!,
      graceInMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}grace_in_minutes'],
      )!,
      graceOutMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}grace_out_minutes'],
      )!,
      requiredMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}required_minutes'],
      )!,
      daysMask: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}days_mask'],
      )!,
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
    );
  }

  @override
  $ShiftsTable createAlias(String alias) {
    return $ShiftsTable(attachedDatabase, alias);
  }
}

class ShiftRow extends DataClass implements Insertable<ShiftRow> {
  final int id;
  final String name;

  /// 0 = fixed times, 1 = flexible (count hours only).
  final int kind;

  /// Minutes from midnight. Ignored when [kind] is flexible.
  final int startMinute;
  final int endMinute;
  final int breakMinutes;
  final int graceInMinutes;
  final int graceOutMinutes;

  /// Required minutes per day when [kind] is flexible.
  final int requiredMinutes;

  /// Bit 0 = Sunday .. bit 6 = Saturday. Weekend is simply the unset bits,
  /// which keeps Fri/Sat and Sat/Sun weekends the same mechanism.
  final int daysMask;

  /// The shift applied to anyone without their own assignment.
  ///
  /// Explicit rather than inferred. This used to be "whichever shift nobody is
  /// assigned to", which happens to work with one shift and silently picks the
  /// wrong one as soon as there are several.
  final bool isDefault;
  const ShiftRow({
    required this.id,
    required this.name,
    required this.kind,
    required this.startMinute,
    required this.endMinute,
    required this.breakMinutes,
    required this.graceInMinutes,
    required this.graceOutMinutes,
    required this.requiredMinutes,
    required this.daysMask,
    required this.isDefault,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['kind'] = Variable<int>(kind);
    map['start_minute'] = Variable<int>(startMinute);
    map['end_minute'] = Variable<int>(endMinute);
    map['break_minutes'] = Variable<int>(breakMinutes);
    map['grace_in_minutes'] = Variable<int>(graceInMinutes);
    map['grace_out_minutes'] = Variable<int>(graceOutMinutes);
    map['required_minutes'] = Variable<int>(requiredMinutes);
    map['days_mask'] = Variable<int>(daysMask);
    map['is_default'] = Variable<bool>(isDefault);
    return map;
  }

  ShiftsCompanion toCompanion(bool nullToAbsent) {
    return ShiftsCompanion(
      id: Value(id),
      name: Value(name),
      kind: Value(kind),
      startMinute: Value(startMinute),
      endMinute: Value(endMinute),
      breakMinutes: Value(breakMinutes),
      graceInMinutes: Value(graceInMinutes),
      graceOutMinutes: Value(graceOutMinutes),
      requiredMinutes: Value(requiredMinutes),
      daysMask: Value(daysMask),
      isDefault: Value(isDefault),
    );
  }

  factory ShiftRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShiftRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      kind: serializer.fromJson<int>(json['kind']),
      startMinute: serializer.fromJson<int>(json['startMinute']),
      endMinute: serializer.fromJson<int>(json['endMinute']),
      breakMinutes: serializer.fromJson<int>(json['breakMinutes']),
      graceInMinutes: serializer.fromJson<int>(json['graceInMinutes']),
      graceOutMinutes: serializer.fromJson<int>(json['graceOutMinutes']),
      requiredMinutes: serializer.fromJson<int>(json['requiredMinutes']),
      daysMask: serializer.fromJson<int>(json['daysMask']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<int>(kind),
      'startMinute': serializer.toJson<int>(startMinute),
      'endMinute': serializer.toJson<int>(endMinute),
      'breakMinutes': serializer.toJson<int>(breakMinutes),
      'graceInMinutes': serializer.toJson<int>(graceInMinutes),
      'graceOutMinutes': serializer.toJson<int>(graceOutMinutes),
      'requiredMinutes': serializer.toJson<int>(requiredMinutes),
      'daysMask': serializer.toJson<int>(daysMask),
      'isDefault': serializer.toJson<bool>(isDefault),
    };
  }

  ShiftRow copyWith({
    int? id,
    String? name,
    int? kind,
    int? startMinute,
    int? endMinute,
    int? breakMinutes,
    int? graceInMinutes,
    int? graceOutMinutes,
    int? requiredMinutes,
    int? daysMask,
    bool? isDefault,
  }) => ShiftRow(
    id: id ?? this.id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    startMinute: startMinute ?? this.startMinute,
    endMinute: endMinute ?? this.endMinute,
    breakMinutes: breakMinutes ?? this.breakMinutes,
    graceInMinutes: graceInMinutes ?? this.graceInMinutes,
    graceOutMinutes: graceOutMinutes ?? this.graceOutMinutes,
    requiredMinutes: requiredMinutes ?? this.requiredMinutes,
    daysMask: daysMask ?? this.daysMask,
    isDefault: isDefault ?? this.isDefault,
  );
  ShiftRow copyWithCompanion(ShiftsCompanion data) {
    return ShiftRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      startMinute: data.startMinute.present
          ? data.startMinute.value
          : this.startMinute,
      endMinute: data.endMinute.present ? data.endMinute.value : this.endMinute,
      breakMinutes: data.breakMinutes.present
          ? data.breakMinutes.value
          : this.breakMinutes,
      graceInMinutes: data.graceInMinutes.present
          ? data.graceInMinutes.value
          : this.graceInMinutes,
      graceOutMinutes: data.graceOutMinutes.present
          ? data.graceOutMinutes.value
          : this.graceOutMinutes,
      requiredMinutes: data.requiredMinutes.present
          ? data.requiredMinutes.value
          : this.requiredMinutes,
      daysMask: data.daysMask.present ? data.daysMask.value : this.daysMask,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShiftRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('startMinute: $startMinute, ')
          ..write('endMinute: $endMinute, ')
          ..write('breakMinutes: $breakMinutes, ')
          ..write('graceInMinutes: $graceInMinutes, ')
          ..write('graceOutMinutes: $graceOutMinutes, ')
          ..write('requiredMinutes: $requiredMinutes, ')
          ..write('daysMask: $daysMask, ')
          ..write('isDefault: $isDefault')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    kind,
    startMinute,
    endMinute,
    breakMinutes,
    graceInMinutes,
    graceOutMinutes,
    requiredMinutes,
    daysMask,
    isDefault,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShiftRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.startMinute == this.startMinute &&
          other.endMinute == this.endMinute &&
          other.breakMinutes == this.breakMinutes &&
          other.graceInMinutes == this.graceInMinutes &&
          other.graceOutMinutes == this.graceOutMinutes &&
          other.requiredMinutes == this.requiredMinutes &&
          other.daysMask == this.daysMask &&
          other.isDefault == this.isDefault);
}

class ShiftsCompanion extends UpdateCompanion<ShiftRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> kind;
  final Value<int> startMinute;
  final Value<int> endMinute;
  final Value<int> breakMinutes;
  final Value<int> graceInMinutes;
  final Value<int> graceOutMinutes;
  final Value<int> requiredMinutes;
  final Value<int> daysMask;
  final Value<bool> isDefault;
  const ShiftsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.startMinute = const Value.absent(),
    this.endMinute = const Value.absent(),
    this.breakMinutes = const Value.absent(),
    this.graceInMinutes = const Value.absent(),
    this.graceOutMinutes = const Value.absent(),
    this.requiredMinutes = const Value.absent(),
    this.daysMask = const Value.absent(),
    this.isDefault = const Value.absent(),
  });
  ShiftsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.kind = const Value.absent(),
    this.startMinute = const Value.absent(),
    this.endMinute = const Value.absent(),
    this.breakMinutes = const Value.absent(),
    this.graceInMinutes = const Value.absent(),
    this.graceOutMinutes = const Value.absent(),
    this.requiredMinutes = const Value.absent(),
    this.daysMask = const Value.absent(),
    this.isDefault = const Value.absent(),
  }) : name = Value(name);
  static Insertable<ShiftRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? kind,
    Expression<int>? startMinute,
    Expression<int>? endMinute,
    Expression<int>? breakMinutes,
    Expression<int>? graceInMinutes,
    Expression<int>? graceOutMinutes,
    Expression<int>? requiredMinutes,
    Expression<int>? daysMask,
    Expression<bool>? isDefault,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (startMinute != null) 'start_minute': startMinute,
      if (endMinute != null) 'end_minute': endMinute,
      if (breakMinutes != null) 'break_minutes': breakMinutes,
      if (graceInMinutes != null) 'grace_in_minutes': graceInMinutes,
      if (graceOutMinutes != null) 'grace_out_minutes': graceOutMinutes,
      if (requiredMinutes != null) 'required_minutes': requiredMinutes,
      if (daysMask != null) 'days_mask': daysMask,
      if (isDefault != null) 'is_default': isDefault,
    });
  }

  ShiftsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? kind,
    Value<int>? startMinute,
    Value<int>? endMinute,
    Value<int>? breakMinutes,
    Value<int>? graceInMinutes,
    Value<int>? graceOutMinutes,
    Value<int>? requiredMinutes,
    Value<int>? daysMask,
    Value<bool>? isDefault,
  }) {
    return ShiftsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      graceInMinutes: graceInMinutes ?? this.graceInMinutes,
      graceOutMinutes: graceOutMinutes ?? this.graceOutMinutes,
      requiredMinutes: requiredMinutes ?? this.requiredMinutes,
      daysMask: daysMask ?? this.daysMask,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<int>(kind.value);
    }
    if (startMinute.present) {
      map['start_minute'] = Variable<int>(startMinute.value);
    }
    if (endMinute.present) {
      map['end_minute'] = Variable<int>(endMinute.value);
    }
    if (breakMinutes.present) {
      map['break_minutes'] = Variable<int>(breakMinutes.value);
    }
    if (graceInMinutes.present) {
      map['grace_in_minutes'] = Variable<int>(graceInMinutes.value);
    }
    if (graceOutMinutes.present) {
      map['grace_out_minutes'] = Variable<int>(graceOutMinutes.value);
    }
    if (requiredMinutes.present) {
      map['required_minutes'] = Variable<int>(requiredMinutes.value);
    }
    if (daysMask.present) {
      map['days_mask'] = Variable<int>(daysMask.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShiftsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('startMinute: $startMinute, ')
          ..write('endMinute: $endMinute, ')
          ..write('breakMinutes: $breakMinutes, ')
          ..write('graceInMinutes: $graceInMinutes, ')
          ..write('graceOutMinutes: $graceOutMinutes, ')
          ..write('requiredMinutes: $requiredMinutes, ')
          ..write('daysMask: $daysMask, ')
          ..write('isDefault: $isDefault')
          ..write(')'))
        .toString();
  }
}

class $EmployeeShiftsTable extends EmployeeShifts
    with TableInfo<$EmployeeShiftsTable, EmployeeShiftRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EmployeeShiftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _employeeIdMeta = const VerificationMeta(
    'employeeId',
  );
  @override
  late final GeneratedColumn<int> employeeId = GeneratedColumn<int>(
    'employee_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _shiftIdMeta = const VerificationMeta(
    'shiftId',
  );
  @override
  late final GeneratedColumn<int> shiftId = GeneratedColumn<int>(
    'shift_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _effectiveFromMeta = const VerificationMeta(
    'effectiveFrom',
  );
  @override
  late final GeneratedColumn<int> effectiveFrom = GeneratedColumn<int>(
    'effective_from',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _effectiveToMeta = const VerificationMeta(
    'effectiveTo',
  );
  @override
  late final GeneratedColumn<int> effectiveTo = GeneratedColumn<int>(
    'effective_to',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    employeeId,
    shiftId,
    effectiveFrom,
    effectiveTo,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'employee_shifts';
  @override
  VerificationContext validateIntegrity(
    Insertable<EmployeeShiftRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('employee_id')) {
      context.handle(
        _employeeIdMeta,
        employeeId.isAcceptableOrUnknown(data['employee_id']!, _employeeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_employeeIdMeta);
    }
    if (data.containsKey('shift_id')) {
      context.handle(
        _shiftIdMeta,
        shiftId.isAcceptableOrUnknown(data['shift_id']!, _shiftIdMeta),
      );
    } else if (isInserting) {
      context.missing(_shiftIdMeta);
    }
    if (data.containsKey('effective_from')) {
      context.handle(
        _effectiveFromMeta,
        effectiveFrom.isAcceptableOrUnknown(
          data['effective_from']!,
          _effectiveFromMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_effectiveFromMeta);
    }
    if (data.containsKey('effective_to')) {
      context.handle(
        _effectiveToMeta,
        effectiveTo.isAcceptableOrUnknown(
          data['effective_to']!,
          _effectiveToMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EmployeeShiftRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EmployeeShiftRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      employeeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}employee_id'],
      )!,
      shiftId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}shift_id'],
      )!,
      effectiveFrom: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}effective_from'],
      )!,
      effectiveTo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}effective_to'],
      ),
    );
  }

  @override
  $EmployeeShiftsTable createAlias(String alias) {
    return $EmployeeShiftsTable(attachedDatabase, alias);
  }
}

class EmployeeShiftRow extends DataClass
    implements Insertable<EmployeeShiftRow> {
  final int id;
  final int employeeId;
  final int shiftId;
  final int effectiveFrom;
  final int? effectiveTo;
  const EmployeeShiftRow({
    required this.id,
    required this.employeeId,
    required this.shiftId,
    required this.effectiveFrom,
    this.effectiveTo,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['employee_id'] = Variable<int>(employeeId);
    map['shift_id'] = Variable<int>(shiftId);
    map['effective_from'] = Variable<int>(effectiveFrom);
    if (!nullToAbsent || effectiveTo != null) {
      map['effective_to'] = Variable<int>(effectiveTo);
    }
    return map;
  }

  EmployeeShiftsCompanion toCompanion(bool nullToAbsent) {
    return EmployeeShiftsCompanion(
      id: Value(id),
      employeeId: Value(employeeId),
      shiftId: Value(shiftId),
      effectiveFrom: Value(effectiveFrom),
      effectiveTo: effectiveTo == null && nullToAbsent
          ? const Value.absent()
          : Value(effectiveTo),
    );
  }

  factory EmployeeShiftRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EmployeeShiftRow(
      id: serializer.fromJson<int>(json['id']),
      employeeId: serializer.fromJson<int>(json['employeeId']),
      shiftId: serializer.fromJson<int>(json['shiftId']),
      effectiveFrom: serializer.fromJson<int>(json['effectiveFrom']),
      effectiveTo: serializer.fromJson<int?>(json['effectiveTo']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'employeeId': serializer.toJson<int>(employeeId),
      'shiftId': serializer.toJson<int>(shiftId),
      'effectiveFrom': serializer.toJson<int>(effectiveFrom),
      'effectiveTo': serializer.toJson<int?>(effectiveTo),
    };
  }

  EmployeeShiftRow copyWith({
    int? id,
    int? employeeId,
    int? shiftId,
    int? effectiveFrom,
    Value<int?> effectiveTo = const Value.absent(),
  }) => EmployeeShiftRow(
    id: id ?? this.id,
    employeeId: employeeId ?? this.employeeId,
    shiftId: shiftId ?? this.shiftId,
    effectiveFrom: effectiveFrom ?? this.effectiveFrom,
    effectiveTo: effectiveTo.present ? effectiveTo.value : this.effectiveTo,
  );
  EmployeeShiftRow copyWithCompanion(EmployeeShiftsCompanion data) {
    return EmployeeShiftRow(
      id: data.id.present ? data.id.value : this.id,
      employeeId: data.employeeId.present
          ? data.employeeId.value
          : this.employeeId,
      shiftId: data.shiftId.present ? data.shiftId.value : this.shiftId,
      effectiveFrom: data.effectiveFrom.present
          ? data.effectiveFrom.value
          : this.effectiveFrom,
      effectiveTo: data.effectiveTo.present
          ? data.effectiveTo.value
          : this.effectiveTo,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EmployeeShiftRow(')
          ..write('id: $id, ')
          ..write('employeeId: $employeeId, ')
          ..write('shiftId: $shiftId, ')
          ..write('effectiveFrom: $effectiveFrom, ')
          ..write('effectiveTo: $effectiveTo')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, employeeId, shiftId, effectiveFrom, effectiveTo);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EmployeeShiftRow &&
          other.id == this.id &&
          other.employeeId == this.employeeId &&
          other.shiftId == this.shiftId &&
          other.effectiveFrom == this.effectiveFrom &&
          other.effectiveTo == this.effectiveTo);
}

class EmployeeShiftsCompanion extends UpdateCompanion<EmployeeShiftRow> {
  final Value<int> id;
  final Value<int> employeeId;
  final Value<int> shiftId;
  final Value<int> effectiveFrom;
  final Value<int?> effectiveTo;
  const EmployeeShiftsCompanion({
    this.id = const Value.absent(),
    this.employeeId = const Value.absent(),
    this.shiftId = const Value.absent(),
    this.effectiveFrom = const Value.absent(),
    this.effectiveTo = const Value.absent(),
  });
  EmployeeShiftsCompanion.insert({
    this.id = const Value.absent(),
    required int employeeId,
    required int shiftId,
    required int effectiveFrom,
    this.effectiveTo = const Value.absent(),
  }) : employeeId = Value(employeeId),
       shiftId = Value(shiftId),
       effectiveFrom = Value(effectiveFrom);
  static Insertable<EmployeeShiftRow> custom({
    Expression<int>? id,
    Expression<int>? employeeId,
    Expression<int>? shiftId,
    Expression<int>? effectiveFrom,
    Expression<int>? effectiveTo,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (employeeId != null) 'employee_id': employeeId,
      if (shiftId != null) 'shift_id': shiftId,
      if (effectiveFrom != null) 'effective_from': effectiveFrom,
      if (effectiveTo != null) 'effective_to': effectiveTo,
    });
  }

  EmployeeShiftsCompanion copyWith({
    Value<int>? id,
    Value<int>? employeeId,
    Value<int>? shiftId,
    Value<int>? effectiveFrom,
    Value<int?>? effectiveTo,
  }) {
    return EmployeeShiftsCompanion(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      shiftId: shiftId ?? this.shiftId,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      effectiveTo: effectiveTo ?? this.effectiveTo,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (employeeId.present) {
      map['employee_id'] = Variable<int>(employeeId.value);
    }
    if (shiftId.present) {
      map['shift_id'] = Variable<int>(shiftId.value);
    }
    if (effectiveFrom.present) {
      map['effective_from'] = Variable<int>(effectiveFrom.value);
    }
    if (effectiveTo.present) {
      map['effective_to'] = Variable<int>(effectiveTo.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EmployeeShiftsCompanion(')
          ..write('id: $id, ')
          ..write('employeeId: $employeeId, ')
          ..write('shiftId: $shiftId, ')
          ..write('effectiveFrom: $effectiveFrom, ')
          ..write('effectiveTo: $effectiveTo')
          ..write(')'))
        .toString();
  }
}

class $RosterEntriesTable extends RosterEntries
    with TableInfo<$RosterEntriesTable, RosterRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RosterEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _employeeIdMeta = const VerificationMeta(
    'employeeId',
  );
  @override
  late final GeneratedColumn<int> employeeId = GeneratedColumn<int>(
    'employee_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateKeyMeta = const VerificationMeta(
    'dateKey',
  );
  @override
  late final GeneratedColumn<int> dateKey = GeneratedColumn<int>(
    'date_key',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _shiftIdMeta = const VerificationMeta(
    'shiftId',
  );
  @override
  late final GeneratedColumn<int> shiftId = GeneratedColumn<int>(
    'shift_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, employeeId, dateKey, shiftId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'roster_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<RosterRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('employee_id')) {
      context.handle(
        _employeeIdMeta,
        employeeId.isAcceptableOrUnknown(data['employee_id']!, _employeeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_employeeIdMeta);
    }
    if (data.containsKey('date_key')) {
      context.handle(
        _dateKeyMeta,
        dateKey.isAcceptableOrUnknown(data['date_key']!, _dateKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dateKeyMeta);
    }
    if (data.containsKey('shift_id')) {
      context.handle(
        _shiftIdMeta,
        shiftId.isAcceptableOrUnknown(data['shift_id']!, _shiftIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RosterRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RosterRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      employeeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}employee_id'],
      )!,
      dateKey: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}date_key'],
      )!,
      shiftId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}shift_id'],
      ),
    );
  }

  @override
  $RosterEntriesTable createAlias(String alias) {
    return $RosterEntriesTable(attachedDatabase, alias);
  }
}

class RosterRow extends DataClass implements Insertable<RosterRow> {
  final int id;
  final int employeeId;

  /// Local calendar date as yyyymmdd, so day lookups never trip over
  /// timezone arithmetic.
  final int dateKey;

  /// Null means explicitly off that day.
  final int? shiftId;
  const RosterRow({
    required this.id,
    required this.employeeId,
    required this.dateKey,
    this.shiftId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['employee_id'] = Variable<int>(employeeId);
    map['date_key'] = Variable<int>(dateKey);
    if (!nullToAbsent || shiftId != null) {
      map['shift_id'] = Variable<int>(shiftId);
    }
    return map;
  }

  RosterEntriesCompanion toCompanion(bool nullToAbsent) {
    return RosterEntriesCompanion(
      id: Value(id),
      employeeId: Value(employeeId),
      dateKey: Value(dateKey),
      shiftId: shiftId == null && nullToAbsent
          ? const Value.absent()
          : Value(shiftId),
    );
  }

  factory RosterRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RosterRow(
      id: serializer.fromJson<int>(json['id']),
      employeeId: serializer.fromJson<int>(json['employeeId']),
      dateKey: serializer.fromJson<int>(json['dateKey']),
      shiftId: serializer.fromJson<int?>(json['shiftId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'employeeId': serializer.toJson<int>(employeeId),
      'dateKey': serializer.toJson<int>(dateKey),
      'shiftId': serializer.toJson<int?>(shiftId),
    };
  }

  RosterRow copyWith({
    int? id,
    int? employeeId,
    int? dateKey,
    Value<int?> shiftId = const Value.absent(),
  }) => RosterRow(
    id: id ?? this.id,
    employeeId: employeeId ?? this.employeeId,
    dateKey: dateKey ?? this.dateKey,
    shiftId: shiftId.present ? shiftId.value : this.shiftId,
  );
  RosterRow copyWithCompanion(RosterEntriesCompanion data) {
    return RosterRow(
      id: data.id.present ? data.id.value : this.id,
      employeeId: data.employeeId.present
          ? data.employeeId.value
          : this.employeeId,
      dateKey: data.dateKey.present ? data.dateKey.value : this.dateKey,
      shiftId: data.shiftId.present ? data.shiftId.value : this.shiftId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RosterRow(')
          ..write('id: $id, ')
          ..write('employeeId: $employeeId, ')
          ..write('dateKey: $dateKey, ')
          ..write('shiftId: $shiftId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, employeeId, dateKey, shiftId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RosterRow &&
          other.id == this.id &&
          other.employeeId == this.employeeId &&
          other.dateKey == this.dateKey &&
          other.shiftId == this.shiftId);
}

class RosterEntriesCompanion extends UpdateCompanion<RosterRow> {
  final Value<int> id;
  final Value<int> employeeId;
  final Value<int> dateKey;
  final Value<int?> shiftId;
  const RosterEntriesCompanion({
    this.id = const Value.absent(),
    this.employeeId = const Value.absent(),
    this.dateKey = const Value.absent(),
    this.shiftId = const Value.absent(),
  });
  RosterEntriesCompanion.insert({
    this.id = const Value.absent(),
    required int employeeId,
    required int dateKey,
    this.shiftId = const Value.absent(),
  }) : employeeId = Value(employeeId),
       dateKey = Value(dateKey);
  static Insertable<RosterRow> custom({
    Expression<int>? id,
    Expression<int>? employeeId,
    Expression<int>? dateKey,
    Expression<int>? shiftId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (employeeId != null) 'employee_id': employeeId,
      if (dateKey != null) 'date_key': dateKey,
      if (shiftId != null) 'shift_id': shiftId,
    });
  }

  RosterEntriesCompanion copyWith({
    Value<int>? id,
    Value<int>? employeeId,
    Value<int>? dateKey,
    Value<int?>? shiftId,
  }) {
    return RosterEntriesCompanion(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      dateKey: dateKey ?? this.dateKey,
      shiftId: shiftId ?? this.shiftId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (employeeId.present) {
      map['employee_id'] = Variable<int>(employeeId.value);
    }
    if (dateKey.present) {
      map['date_key'] = Variable<int>(dateKey.value);
    }
    if (shiftId.present) {
      map['shift_id'] = Variable<int>(shiftId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RosterEntriesCompanion(')
          ..write('id: $id, ')
          ..write('employeeId: $employeeId, ')
          ..write('dateKey: $dateKey, ')
          ..write('shiftId: $shiftId')
          ..write(')'))
        .toString();
  }
}

class $MetaTable extends Meta with TableInfo<$MetaTable, MetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<int> value = GeneratedColumn<int>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<MetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  MetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetaRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $MetaTable createAlias(String alias) {
    return $MetaTable(attachedDatabase, alias);
  }
}

class MetaRow extends DataClass implements Insertable<MetaRow> {
  final String key;
  final int value;
  const MetaRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<int>(value);
    return map;
  }

  MetaCompanion toCompanion(bool nullToAbsent) {
    return MetaCompanion(key: Value(key), value: Value(value));
  }

  factory MetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetaRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<int>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<int>(value),
    };
  }

  MetaRow copyWith({String? key, int? value}) =>
      MetaRow(key: key ?? this.key, value: value ?? this.value);
  MetaRow copyWithCompanion(MetaCompanion data) {
    return MetaRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetaRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetaRow && other.key == this.key && other.value == this.value);
}

class MetaCompanion extends UpdateCompanion<MetaRow> {
  final Value<String> key;
  final Value<int> value;
  final Value<int> rowid;
  const MetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MetaCompanion.insert({
    required String key,
    required int value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<MetaRow> custom({
    Expression<String>? key,
    Expression<int>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MetaCompanion copyWith({
    Value<String>? key,
    Value<int>? value,
    Value<int>? rowid,
  }) {
    return MetaCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<int>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $EmployeesTable employees = $EmployeesTable(this);
  late final $PunchesTable punches = $PunchesTable(this);
  late final $AuditLogTable auditLog = $AuditLogTable(this);
  late final $ShiftsTable shifts = $ShiftsTable(this);
  late final $EmployeeShiftsTable employeeShifts = $EmployeeShiftsTable(this);
  late final $RosterEntriesTable rosterEntries = $RosterEntriesTable(this);
  late final $MetaTable meta = $MetaTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    employees,
    punches,
    auditLog,
    shifts,
    employeeShifts,
    rosterEntries,
    meta,
  ];
}

typedef $$EmployeesTableCreateCompanionBuilder =
    EmployeesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> jobTitle,
      Value<bool> active,
      Value<int> fingers,
      Value<int> failCount,
      Value<bool> removed,
    });
typedef $$EmployeesTableUpdateCompanionBuilder =
    EmployeesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> jobTitle,
      Value<bool> active,
      Value<int> fingers,
      Value<int> failCount,
      Value<bool> removed,
    });

class $$EmployeesTableFilterComposer
    extends Composer<_$AppDatabase, $EmployeesTable> {
  $$EmployeesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jobTitle => $composableBuilder(
    column: $table.jobTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fingers => $composableBuilder(
    column: $table.fingers,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get failCount => $composableBuilder(
    column: $table.failCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get removed => $composableBuilder(
    column: $table.removed,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EmployeesTableOrderingComposer
    extends Composer<_$AppDatabase, $EmployeesTable> {
  $$EmployeesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jobTitle => $composableBuilder(
    column: $table.jobTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fingers => $composableBuilder(
    column: $table.fingers,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get failCount => $composableBuilder(
    column: $table.failCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get removed => $composableBuilder(
    column: $table.removed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EmployeesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EmployeesTable> {
  $$EmployeesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get jobTitle =>
      $composableBuilder(column: $table.jobTitle, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<int> get fingers =>
      $composableBuilder(column: $table.fingers, builder: (column) => column);

  GeneratedColumn<int> get failCount =>
      $composableBuilder(column: $table.failCount, builder: (column) => column);

  GeneratedColumn<bool> get removed =>
      $composableBuilder(column: $table.removed, builder: (column) => column);
}

class $$EmployeesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EmployeesTable,
          EmployeeRow,
          $$EmployeesTableFilterComposer,
          $$EmployeesTableOrderingComposer,
          $$EmployeesTableAnnotationComposer,
          $$EmployeesTableCreateCompanionBuilder,
          $$EmployeesTableUpdateCompanionBuilder,
          (
            EmployeeRow,
            BaseReferences<_$AppDatabase, $EmployeesTable, EmployeeRow>,
          ),
          EmployeeRow,
          PrefetchHooks Function()
        > {
  $$EmployeesTableTableManager(_$AppDatabase db, $EmployeesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EmployeesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EmployeesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EmployeesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> jobTitle = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<int> fingers = const Value.absent(),
                Value<int> failCount = const Value.absent(),
                Value<bool> removed = const Value.absent(),
              }) => EmployeesCompanion(
                id: id,
                name: name,
                jobTitle: jobTitle,
                active: active,
                fingers: fingers,
                failCount: failCount,
                removed: removed,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> jobTitle = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<int> fingers = const Value.absent(),
                Value<int> failCount = const Value.absent(),
                Value<bool> removed = const Value.absent(),
              }) => EmployeesCompanion.insert(
                id: id,
                name: name,
                jobTitle: jobTitle,
                active: active,
                fingers: fingers,
                failCount: failCount,
                removed: removed,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EmployeesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EmployeesTable,
      EmployeeRow,
      $$EmployeesTableFilterComposer,
      $$EmployeesTableOrderingComposer,
      $$EmployeesTableAnnotationComposer,
      $$EmployeesTableCreateCompanionBuilder,
      $$EmployeesTableUpdateCompanionBuilder,
      (
        EmployeeRow,
        BaseReferences<_$AppDatabase, $EmployeesTable, EmployeeRow>,
      ),
      EmployeeRow,
      PrefetchHooks Function()
    >;
typedef $$PunchesTableCreateCompanionBuilder =
    PunchesCompanion Function({
      Value<int> seq,
      required int deviceEpoch,
      required int employeeId,
      Value<int> slot,
      required int direction,
      Value<int> method,
      Value<bool> provisionalTime,
      Value<int?> correctedEpoch,
    });
typedef $$PunchesTableUpdateCompanionBuilder =
    PunchesCompanion Function({
      Value<int> seq,
      Value<int> deviceEpoch,
      Value<int> employeeId,
      Value<int> slot,
      Value<int> direction,
      Value<int> method,
      Value<bool> provisionalTime,
      Value<int?> correctedEpoch,
    });

class $$PunchesTableFilterComposer
    extends Composer<_$AppDatabase, $PunchesTable> {
  $$PunchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deviceEpoch => $composableBuilder(
    column: $table.deviceEpoch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get employeeId => $composableBuilder(
    column: $table.employeeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get provisionalTime => $composableBuilder(
    column: $table.provisionalTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get correctedEpoch => $composableBuilder(
    column: $table.correctedEpoch,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PunchesTableOrderingComposer
    extends Composer<_$AppDatabase, $PunchesTable> {
  $$PunchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deviceEpoch => $composableBuilder(
    column: $table.deviceEpoch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get employeeId => $composableBuilder(
    column: $table.employeeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get provisionalTime => $composableBuilder(
    column: $table.provisionalTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get correctedEpoch => $composableBuilder(
    column: $table.correctedEpoch,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PunchesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PunchesTable> {
  $$PunchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<int> get deviceEpoch => $composableBuilder(
    column: $table.deviceEpoch,
    builder: (column) => column,
  );

  GeneratedColumn<int> get employeeId => $composableBuilder(
    column: $table.employeeId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get slot =>
      $composableBuilder(column: $table.slot, builder: (column) => column);

  GeneratedColumn<int> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<int> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<bool> get provisionalTime => $composableBuilder(
    column: $table.provisionalTime,
    builder: (column) => column,
  );

  GeneratedColumn<int> get correctedEpoch => $composableBuilder(
    column: $table.correctedEpoch,
    builder: (column) => column,
  );
}

class $$PunchesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PunchesTable,
          PunchRow,
          $$PunchesTableFilterComposer,
          $$PunchesTableOrderingComposer,
          $$PunchesTableAnnotationComposer,
          $$PunchesTableCreateCompanionBuilder,
          $$PunchesTableUpdateCompanionBuilder,
          (PunchRow, BaseReferences<_$AppDatabase, $PunchesTable, PunchRow>),
          PunchRow,
          PrefetchHooks Function()
        > {
  $$PunchesTableTableManager(_$AppDatabase db, $PunchesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PunchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PunchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PunchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                Value<int> deviceEpoch = const Value.absent(),
                Value<int> employeeId = const Value.absent(),
                Value<int> slot = const Value.absent(),
                Value<int> direction = const Value.absent(),
                Value<int> method = const Value.absent(),
                Value<bool> provisionalTime = const Value.absent(),
                Value<int?> correctedEpoch = const Value.absent(),
              }) => PunchesCompanion(
                seq: seq,
                deviceEpoch: deviceEpoch,
                employeeId: employeeId,
                slot: slot,
                direction: direction,
                method: method,
                provisionalTime: provisionalTime,
                correctedEpoch: correctedEpoch,
              ),
          createCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                required int deviceEpoch,
                required int employeeId,
                Value<int> slot = const Value.absent(),
                required int direction,
                Value<int> method = const Value.absent(),
                Value<bool> provisionalTime = const Value.absent(),
                Value<int?> correctedEpoch = const Value.absent(),
              }) => PunchesCompanion.insert(
                seq: seq,
                deviceEpoch: deviceEpoch,
                employeeId: employeeId,
                slot: slot,
                direction: direction,
                method: method,
                provisionalTime: provisionalTime,
                correctedEpoch: correctedEpoch,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PunchesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PunchesTable,
      PunchRow,
      $$PunchesTableFilterComposer,
      $$PunchesTableOrderingComposer,
      $$PunchesTableAnnotationComposer,
      $$PunchesTableCreateCompanionBuilder,
      $$PunchesTableUpdateCompanionBuilder,
      (PunchRow, BaseReferences<_$AppDatabase, $PunchesTable, PunchRow>),
      PunchRow,
      PrefetchHooks Function()
    >;
typedef $$AuditLogTableCreateCompanionBuilder =
    AuditLogCompanion Function({
      Value<int> id,
      required int atEpoch,
      required String action,
      Value<int?> employeeId,
      Value<String> detail,
    });
typedef $$AuditLogTableUpdateCompanionBuilder =
    AuditLogCompanion Function({
      Value<int> id,
      Value<int> atEpoch,
      Value<String> action,
      Value<int?> employeeId,
      Value<String> detail,
    });

class $$AuditLogTableFilterComposer
    extends Composer<_$AppDatabase, $AuditLogTable> {
  $$AuditLogTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get atEpoch => $composableBuilder(
    column: $table.atEpoch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get employeeId => $composableBuilder(
    column: $table.employeeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AuditLogTableOrderingComposer
    extends Composer<_$AppDatabase, $AuditLogTable> {
  $$AuditLogTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get atEpoch => $composableBuilder(
    column: $table.atEpoch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get employeeId => $composableBuilder(
    column: $table.employeeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AuditLogTableAnnotationComposer
    extends Composer<_$AppDatabase, $AuditLogTable> {
  $$AuditLogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get atEpoch =>
      $composableBuilder(column: $table.atEpoch, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<int> get employeeId => $composableBuilder(
    column: $table.employeeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get detail =>
      $composableBuilder(column: $table.detail, builder: (column) => column);
}

class $$AuditLogTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AuditLogTable,
          AuditRow,
          $$AuditLogTableFilterComposer,
          $$AuditLogTableOrderingComposer,
          $$AuditLogTableAnnotationComposer,
          $$AuditLogTableCreateCompanionBuilder,
          $$AuditLogTableUpdateCompanionBuilder,
          (AuditRow, BaseReferences<_$AppDatabase, $AuditLogTable, AuditRow>),
          AuditRow,
          PrefetchHooks Function()
        > {
  $$AuditLogTableTableManager(_$AppDatabase db, $AuditLogTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AuditLogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AuditLogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AuditLogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> atEpoch = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<int?> employeeId = const Value.absent(),
                Value<String> detail = const Value.absent(),
              }) => AuditLogCompanion(
                id: id,
                atEpoch: atEpoch,
                action: action,
                employeeId: employeeId,
                detail: detail,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int atEpoch,
                required String action,
                Value<int?> employeeId = const Value.absent(),
                Value<String> detail = const Value.absent(),
              }) => AuditLogCompanion.insert(
                id: id,
                atEpoch: atEpoch,
                action: action,
                employeeId: employeeId,
                detail: detail,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AuditLogTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AuditLogTable,
      AuditRow,
      $$AuditLogTableFilterComposer,
      $$AuditLogTableOrderingComposer,
      $$AuditLogTableAnnotationComposer,
      $$AuditLogTableCreateCompanionBuilder,
      $$AuditLogTableUpdateCompanionBuilder,
      (AuditRow, BaseReferences<_$AppDatabase, $AuditLogTable, AuditRow>),
      AuditRow,
      PrefetchHooks Function()
    >;
typedef $$ShiftsTableCreateCompanionBuilder =
    ShiftsCompanion Function({
      Value<int> id,
      required String name,
      Value<int> kind,
      Value<int> startMinute,
      Value<int> endMinute,
      Value<int> breakMinutes,
      Value<int> graceInMinutes,
      Value<int> graceOutMinutes,
      Value<int> requiredMinutes,
      Value<int> daysMask,
      Value<bool> isDefault,
    });
typedef $$ShiftsTableUpdateCompanionBuilder =
    ShiftsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> kind,
      Value<int> startMinute,
      Value<int> endMinute,
      Value<int> breakMinutes,
      Value<int> graceInMinutes,
      Value<int> graceOutMinutes,
      Value<int> requiredMinutes,
      Value<int> daysMask,
      Value<bool> isDefault,
    });

class $$ShiftsTableFilterComposer
    extends Composer<_$AppDatabase, $ShiftsTable> {
  $$ShiftsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get breakMinutes => $composableBuilder(
    column: $table.breakMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get graceInMinutes => $composableBuilder(
    column: $table.graceInMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get graceOutMinutes => $composableBuilder(
    column: $table.graceOutMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get requiredMinutes => $composableBuilder(
    column: $table.requiredMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get daysMask => $composableBuilder(
    column: $table.daysMask,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ShiftsTableOrderingComposer
    extends Composer<_$AppDatabase, $ShiftsTable> {
  $$ShiftsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get breakMinutes => $composableBuilder(
    column: $table.breakMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get graceInMinutes => $composableBuilder(
    column: $table.graceInMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get graceOutMinutes => $composableBuilder(
    column: $table.graceOutMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get requiredMinutes => $composableBuilder(
    column: $table.requiredMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get daysMask => $composableBuilder(
    column: $table.daysMask,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ShiftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShiftsTable> {
  $$ShiftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endMinute =>
      $composableBuilder(column: $table.endMinute, builder: (column) => column);

  GeneratedColumn<int> get breakMinutes => $composableBuilder(
    column: $table.breakMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get graceInMinutes => $composableBuilder(
    column: $table.graceInMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get graceOutMinutes => $composableBuilder(
    column: $table.graceOutMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get requiredMinutes => $composableBuilder(
    column: $table.requiredMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get daysMask =>
      $composableBuilder(column: $table.daysMask, builder: (column) => column);

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);
}

class $$ShiftsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShiftsTable,
          ShiftRow,
          $$ShiftsTableFilterComposer,
          $$ShiftsTableOrderingComposer,
          $$ShiftsTableAnnotationComposer,
          $$ShiftsTableCreateCompanionBuilder,
          $$ShiftsTableUpdateCompanionBuilder,
          (ShiftRow, BaseReferences<_$AppDatabase, $ShiftsTable, ShiftRow>),
          ShiftRow,
          PrefetchHooks Function()
        > {
  $$ShiftsTableTableManager(_$AppDatabase db, $ShiftsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShiftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShiftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShiftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> kind = const Value.absent(),
                Value<int> startMinute = const Value.absent(),
                Value<int> endMinute = const Value.absent(),
                Value<int> breakMinutes = const Value.absent(),
                Value<int> graceInMinutes = const Value.absent(),
                Value<int> graceOutMinutes = const Value.absent(),
                Value<int> requiredMinutes = const Value.absent(),
                Value<int> daysMask = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
              }) => ShiftsCompanion(
                id: id,
                name: name,
                kind: kind,
                startMinute: startMinute,
                endMinute: endMinute,
                breakMinutes: breakMinutes,
                graceInMinutes: graceInMinutes,
                graceOutMinutes: graceOutMinutes,
                requiredMinutes: requiredMinutes,
                daysMask: daysMask,
                isDefault: isDefault,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<int> kind = const Value.absent(),
                Value<int> startMinute = const Value.absent(),
                Value<int> endMinute = const Value.absent(),
                Value<int> breakMinutes = const Value.absent(),
                Value<int> graceInMinutes = const Value.absent(),
                Value<int> graceOutMinutes = const Value.absent(),
                Value<int> requiredMinutes = const Value.absent(),
                Value<int> daysMask = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
              }) => ShiftsCompanion.insert(
                id: id,
                name: name,
                kind: kind,
                startMinute: startMinute,
                endMinute: endMinute,
                breakMinutes: breakMinutes,
                graceInMinutes: graceInMinutes,
                graceOutMinutes: graceOutMinutes,
                requiredMinutes: requiredMinutes,
                daysMask: daysMask,
                isDefault: isDefault,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ShiftsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShiftsTable,
      ShiftRow,
      $$ShiftsTableFilterComposer,
      $$ShiftsTableOrderingComposer,
      $$ShiftsTableAnnotationComposer,
      $$ShiftsTableCreateCompanionBuilder,
      $$ShiftsTableUpdateCompanionBuilder,
      (ShiftRow, BaseReferences<_$AppDatabase, $ShiftsTable, ShiftRow>),
      ShiftRow,
      PrefetchHooks Function()
    >;
typedef $$EmployeeShiftsTableCreateCompanionBuilder =
    EmployeeShiftsCompanion Function({
      Value<int> id,
      required int employeeId,
      required int shiftId,
      required int effectiveFrom,
      Value<int?> effectiveTo,
    });
typedef $$EmployeeShiftsTableUpdateCompanionBuilder =
    EmployeeShiftsCompanion Function({
      Value<int> id,
      Value<int> employeeId,
      Value<int> shiftId,
      Value<int> effectiveFrom,
      Value<int?> effectiveTo,
    });

class $$EmployeeShiftsTableFilterComposer
    extends Composer<_$AppDatabase, $EmployeeShiftsTable> {
  $$EmployeeShiftsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get employeeId => $composableBuilder(
    column: $table.employeeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get shiftId => $composableBuilder(
    column: $table.shiftId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get effectiveFrom => $composableBuilder(
    column: $table.effectiveFrom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get effectiveTo => $composableBuilder(
    column: $table.effectiveTo,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EmployeeShiftsTableOrderingComposer
    extends Composer<_$AppDatabase, $EmployeeShiftsTable> {
  $$EmployeeShiftsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get employeeId => $composableBuilder(
    column: $table.employeeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get shiftId => $composableBuilder(
    column: $table.shiftId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get effectiveFrom => $composableBuilder(
    column: $table.effectiveFrom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get effectiveTo => $composableBuilder(
    column: $table.effectiveTo,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EmployeeShiftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EmployeeShiftsTable> {
  $$EmployeeShiftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get employeeId => $composableBuilder(
    column: $table.employeeId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get shiftId =>
      $composableBuilder(column: $table.shiftId, builder: (column) => column);

  GeneratedColumn<int> get effectiveFrom => $composableBuilder(
    column: $table.effectiveFrom,
    builder: (column) => column,
  );

  GeneratedColumn<int> get effectiveTo => $composableBuilder(
    column: $table.effectiveTo,
    builder: (column) => column,
  );
}

class $$EmployeeShiftsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EmployeeShiftsTable,
          EmployeeShiftRow,
          $$EmployeeShiftsTableFilterComposer,
          $$EmployeeShiftsTableOrderingComposer,
          $$EmployeeShiftsTableAnnotationComposer,
          $$EmployeeShiftsTableCreateCompanionBuilder,
          $$EmployeeShiftsTableUpdateCompanionBuilder,
          (
            EmployeeShiftRow,
            BaseReferences<
              _$AppDatabase,
              $EmployeeShiftsTable,
              EmployeeShiftRow
            >,
          ),
          EmployeeShiftRow,
          PrefetchHooks Function()
        > {
  $$EmployeeShiftsTableTableManager(
    _$AppDatabase db,
    $EmployeeShiftsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EmployeeShiftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EmployeeShiftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EmployeeShiftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> employeeId = const Value.absent(),
                Value<int> shiftId = const Value.absent(),
                Value<int> effectiveFrom = const Value.absent(),
                Value<int?> effectiveTo = const Value.absent(),
              }) => EmployeeShiftsCompanion(
                id: id,
                employeeId: employeeId,
                shiftId: shiftId,
                effectiveFrom: effectiveFrom,
                effectiveTo: effectiveTo,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int employeeId,
                required int shiftId,
                required int effectiveFrom,
                Value<int?> effectiveTo = const Value.absent(),
              }) => EmployeeShiftsCompanion.insert(
                id: id,
                employeeId: employeeId,
                shiftId: shiftId,
                effectiveFrom: effectiveFrom,
                effectiveTo: effectiveTo,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EmployeeShiftsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EmployeeShiftsTable,
      EmployeeShiftRow,
      $$EmployeeShiftsTableFilterComposer,
      $$EmployeeShiftsTableOrderingComposer,
      $$EmployeeShiftsTableAnnotationComposer,
      $$EmployeeShiftsTableCreateCompanionBuilder,
      $$EmployeeShiftsTableUpdateCompanionBuilder,
      (
        EmployeeShiftRow,
        BaseReferences<_$AppDatabase, $EmployeeShiftsTable, EmployeeShiftRow>,
      ),
      EmployeeShiftRow,
      PrefetchHooks Function()
    >;
typedef $$RosterEntriesTableCreateCompanionBuilder =
    RosterEntriesCompanion Function({
      Value<int> id,
      required int employeeId,
      required int dateKey,
      Value<int?> shiftId,
    });
typedef $$RosterEntriesTableUpdateCompanionBuilder =
    RosterEntriesCompanion Function({
      Value<int> id,
      Value<int> employeeId,
      Value<int> dateKey,
      Value<int?> shiftId,
    });

class $$RosterEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $RosterEntriesTable> {
  $$RosterEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get employeeId => $composableBuilder(
    column: $table.employeeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dateKey => $composableBuilder(
    column: $table.dateKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get shiftId => $composableBuilder(
    column: $table.shiftId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RosterEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $RosterEntriesTable> {
  $$RosterEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get employeeId => $composableBuilder(
    column: $table.employeeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dateKey => $composableBuilder(
    column: $table.dateKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get shiftId => $composableBuilder(
    column: $table.shiftId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RosterEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RosterEntriesTable> {
  $$RosterEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get employeeId => $composableBuilder(
    column: $table.employeeId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dateKey =>
      $composableBuilder(column: $table.dateKey, builder: (column) => column);

  GeneratedColumn<int> get shiftId =>
      $composableBuilder(column: $table.shiftId, builder: (column) => column);
}

class $$RosterEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RosterEntriesTable,
          RosterRow,
          $$RosterEntriesTableFilterComposer,
          $$RosterEntriesTableOrderingComposer,
          $$RosterEntriesTableAnnotationComposer,
          $$RosterEntriesTableCreateCompanionBuilder,
          $$RosterEntriesTableUpdateCompanionBuilder,
          (
            RosterRow,
            BaseReferences<_$AppDatabase, $RosterEntriesTable, RosterRow>,
          ),
          RosterRow,
          PrefetchHooks Function()
        > {
  $$RosterEntriesTableTableManager(_$AppDatabase db, $RosterEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RosterEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RosterEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RosterEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> employeeId = const Value.absent(),
                Value<int> dateKey = const Value.absent(),
                Value<int?> shiftId = const Value.absent(),
              }) => RosterEntriesCompanion(
                id: id,
                employeeId: employeeId,
                dateKey: dateKey,
                shiftId: shiftId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int employeeId,
                required int dateKey,
                Value<int?> shiftId = const Value.absent(),
              }) => RosterEntriesCompanion.insert(
                id: id,
                employeeId: employeeId,
                dateKey: dateKey,
                shiftId: shiftId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RosterEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RosterEntriesTable,
      RosterRow,
      $$RosterEntriesTableFilterComposer,
      $$RosterEntriesTableOrderingComposer,
      $$RosterEntriesTableAnnotationComposer,
      $$RosterEntriesTableCreateCompanionBuilder,
      $$RosterEntriesTableUpdateCompanionBuilder,
      (
        RosterRow,
        BaseReferences<_$AppDatabase, $RosterEntriesTable, RosterRow>,
      ),
      RosterRow,
      PrefetchHooks Function()
    >;
typedef $$MetaTableCreateCompanionBuilder =
    MetaCompanion Function({
      required String key,
      required int value,
      Value<int> rowid,
    });
typedef $$MetaTableUpdateCompanionBuilder =
    MetaCompanion Function({
      Value<String> key,
      Value<int> value,
      Value<int> rowid,
    });

class $$MetaTableFilterComposer extends Composer<_$AppDatabase, $MetaTable> {
  $$MetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MetaTableOrderingComposer extends Composer<_$AppDatabase, $MetaTable> {
  $$MetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $MetaTable> {
  $$MetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<int> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$MetaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MetaTable,
          MetaRow,
          $$MetaTableFilterComposer,
          $$MetaTableOrderingComposer,
          $$MetaTableAnnotationComposer,
          $$MetaTableCreateCompanionBuilder,
          $$MetaTableUpdateCompanionBuilder,
          (MetaRow, BaseReferences<_$AppDatabase, $MetaTable, MetaRow>),
          MetaRow,
          PrefetchHooks Function()
        > {
  $$MetaTableTableManager(_$AppDatabase db, $MetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<int> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MetaCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required int value,
                Value<int> rowid = const Value.absent(),
              }) => MetaCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MetaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MetaTable,
      MetaRow,
      $$MetaTableFilterComposer,
      $$MetaTableOrderingComposer,
      $$MetaTableAnnotationComposer,
      $$MetaTableCreateCompanionBuilder,
      $$MetaTableUpdateCompanionBuilder,
      (MetaRow, BaseReferences<_$AppDatabase, $MetaTable, MetaRow>),
      MetaRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$EmployeesTableTableManager get employees =>
      $$EmployeesTableTableManager(_db, _db.employees);
  $$PunchesTableTableManager get punches =>
      $$PunchesTableTableManager(_db, _db.punches);
  $$AuditLogTableTableManager get auditLog =>
      $$AuditLogTableTableManager(_db, _db.auditLog);
  $$ShiftsTableTableManager get shifts =>
      $$ShiftsTableTableManager(_db, _db.shifts);
  $$EmployeeShiftsTableTableManager get employeeShifts =>
      $$EmployeeShiftsTableTableManager(_db, _db.employeeShifts);
  $$RosterEntriesTableTableManager get rosterEntries =>
      $$RosterEntriesTableTableManager(_db, _db.rosterEntries);
  $$MetaTableTableManager get meta => $$MetaTableTableManager(_db, _db.meta);
}
