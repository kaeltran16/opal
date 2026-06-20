// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $EntriesTable extends Entries with TableInfo<$EntriesTable, EntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detailMeta = const VerificationMeta('detail');
  @override
  late final GeneratedColumn<String> detail = GeneratedColumn<String>(
    'detail',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMeta = const VerificationMeta(
    'duration',
  );
  @override
  late final GeneratedColumn<int> duration = GeneratedColumn<int>(
    'duration',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _caloriesMeta = const VerificationMeta(
    'calories',
  );
  @override
  late final GeneratedColumn<int> calories = GeneratedColumn<int>(
    'calories',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _distanceMeta = const VerificationMeta(
    'distance',
  );
  @override
  late final GeneratedColumn<double> distance = GeneratedColumn<double>(
    'distance',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ritualIdMeta = const VerificationMeta(
    'ritualId',
  );
  @override
  late final GeneratedColumn<String> ritualId = GeneratedColumn<String>(
    'ritual_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceRefMeta = const VerificationMeta(
    'sourceRef',
  );
  @override
  late final GeneratedColumn<String> sourceRef = GeneratedColumn<String>(
    'source_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _workoutIdMeta = const VerificationMeta(
    'workoutId',
  );
  @override
  late final GeneratedColumn<String> workoutId = GeneratedColumn<String>(
    'workout_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    timestamp,
    type,
    title,
    detail,
    amount,
    duration,
    calories,
    distance,
    category,
    ritualId,
    note,
    source,
    sourceRef,
    workoutId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<EntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('detail')) {
      context.handle(
        _detailMeta,
        detail.isAcceptableOrUnknown(data['detail']!, _detailMeta),
      );
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    }
    if (data.containsKey('duration')) {
      context.handle(
        _durationMeta,
        duration.isAcceptableOrUnknown(data['duration']!, _durationMeta),
      );
    }
    if (data.containsKey('calories')) {
      context.handle(
        _caloriesMeta,
        calories.isAcceptableOrUnknown(data['calories']!, _caloriesMeta),
      );
    }
    if (data.containsKey('distance')) {
      context.handle(
        _distanceMeta,
        distance.isAcceptableOrUnknown(data['distance']!, _distanceMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('ritual_id')) {
      context.handle(
        _ritualIdMeta,
        ritualId.isAcceptableOrUnknown(data['ritual_id']!, _ritualIdMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('source_ref')) {
      context.handle(
        _sourceRefMeta,
        sourceRef.isAcceptableOrUnknown(data['source_ref']!, _sourceRefMeta),
      );
    }
    if (data.containsKey('workout_id')) {
      context.handle(
        _workoutIdMeta,
        workoutId.isAcceptableOrUnknown(data['workout_id']!, _workoutIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      detail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail'],
      ),
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      ),
      duration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration'],
      ),
      calories: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}calories'],
      ),
      distance: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}distance'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      ritualId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ritual_id'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      sourceRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_ref'],
      ),
      workoutId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workout_id'],
      ),
    );
  }

  @override
  $EntriesTable createAlias(String alias) {
    return $EntriesTable(attachedDatabase, alias);
  }
}

class EntryRow extends DataClass implements Insertable<EntryRow> {
  final String id;
  final DateTime timestamp;

  /// [EntryType.wire].
  final String type;
  final String title;
  final String? detail;
  final double? amount;
  final int? duration;
  final int? calories;
  final double? distance;
  final String? category;
  final String? ritualId;
  final String? note;

  /// [EntrySource.wire].
  final String source;
  final String? sourceRef;
  final String? workoutId;
  const EntryRow({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.title,
    this.detail,
    this.amount,
    this.duration,
    this.calories,
    this.distance,
    this.category,
    this.ritualId,
    this.note,
    required this.source,
    this.sourceRef,
    this.workoutId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['type'] = Variable<String>(type);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || detail != null) {
      map['detail'] = Variable<String>(detail);
    }
    if (!nullToAbsent || amount != null) {
      map['amount'] = Variable<double>(amount);
    }
    if (!nullToAbsent || duration != null) {
      map['duration'] = Variable<int>(duration);
    }
    if (!nullToAbsent || calories != null) {
      map['calories'] = Variable<int>(calories);
    }
    if (!nullToAbsent || distance != null) {
      map['distance'] = Variable<double>(distance);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    if (!nullToAbsent || ritualId != null) {
      map['ritual_id'] = Variable<String>(ritualId);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || sourceRef != null) {
      map['source_ref'] = Variable<String>(sourceRef);
    }
    if (!nullToAbsent || workoutId != null) {
      map['workout_id'] = Variable<String>(workoutId);
    }
    return map;
  }

  EntriesCompanion toCompanion(bool nullToAbsent) {
    return EntriesCompanion(
      id: Value(id),
      timestamp: Value(timestamp),
      type: Value(type),
      title: Value(title),
      detail: detail == null && nullToAbsent
          ? const Value.absent()
          : Value(detail),
      amount: amount == null && nullToAbsent
          ? const Value.absent()
          : Value(amount),
      duration: duration == null && nullToAbsent
          ? const Value.absent()
          : Value(duration),
      calories: calories == null && nullToAbsent
          ? const Value.absent()
          : Value(calories),
      distance: distance == null && nullToAbsent
          ? const Value.absent()
          : Value(distance),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      ritualId: ritualId == null && nullToAbsent
          ? const Value.absent()
          : Value(ritualId),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      source: Value(source),
      sourceRef: sourceRef == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceRef),
      workoutId: workoutId == null && nullToAbsent
          ? const Value.absent()
          : Value(workoutId),
    );
  }

  factory EntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EntryRow(
      id: serializer.fromJson<String>(json['id']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      type: serializer.fromJson<String>(json['type']),
      title: serializer.fromJson<String>(json['title']),
      detail: serializer.fromJson<String?>(json['detail']),
      amount: serializer.fromJson<double?>(json['amount']),
      duration: serializer.fromJson<int?>(json['duration']),
      calories: serializer.fromJson<int?>(json['calories']),
      distance: serializer.fromJson<double?>(json['distance']),
      category: serializer.fromJson<String?>(json['category']),
      ritualId: serializer.fromJson<String?>(json['ritualId']),
      note: serializer.fromJson<String?>(json['note']),
      source: serializer.fromJson<String>(json['source']),
      sourceRef: serializer.fromJson<String?>(json['sourceRef']),
      workoutId: serializer.fromJson<String?>(json['workoutId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'type': serializer.toJson<String>(type),
      'title': serializer.toJson<String>(title),
      'detail': serializer.toJson<String?>(detail),
      'amount': serializer.toJson<double?>(amount),
      'duration': serializer.toJson<int?>(duration),
      'calories': serializer.toJson<int?>(calories),
      'distance': serializer.toJson<double?>(distance),
      'category': serializer.toJson<String?>(category),
      'ritualId': serializer.toJson<String?>(ritualId),
      'note': serializer.toJson<String?>(note),
      'source': serializer.toJson<String>(source),
      'sourceRef': serializer.toJson<String?>(sourceRef),
      'workoutId': serializer.toJson<String?>(workoutId),
    };
  }

  EntryRow copyWith({
    String? id,
    DateTime? timestamp,
    String? type,
    String? title,
    Value<String?> detail = const Value.absent(),
    Value<double?> amount = const Value.absent(),
    Value<int?> duration = const Value.absent(),
    Value<int?> calories = const Value.absent(),
    Value<double?> distance = const Value.absent(),
    Value<String?> category = const Value.absent(),
    Value<String?> ritualId = const Value.absent(),
    Value<String?> note = const Value.absent(),
    String? source,
    Value<String?> sourceRef = const Value.absent(),
    Value<String?> workoutId = const Value.absent(),
  }) => EntryRow(
    id: id ?? this.id,
    timestamp: timestamp ?? this.timestamp,
    type: type ?? this.type,
    title: title ?? this.title,
    detail: detail.present ? detail.value : this.detail,
    amount: amount.present ? amount.value : this.amount,
    duration: duration.present ? duration.value : this.duration,
    calories: calories.present ? calories.value : this.calories,
    distance: distance.present ? distance.value : this.distance,
    category: category.present ? category.value : this.category,
    ritualId: ritualId.present ? ritualId.value : this.ritualId,
    note: note.present ? note.value : this.note,
    source: source ?? this.source,
    sourceRef: sourceRef.present ? sourceRef.value : this.sourceRef,
    workoutId: workoutId.present ? workoutId.value : this.workoutId,
  );
  EntryRow copyWithCompanion(EntriesCompanion data) {
    return EntryRow(
      id: data.id.present ? data.id.value : this.id,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      type: data.type.present ? data.type.value : this.type,
      title: data.title.present ? data.title.value : this.title,
      detail: data.detail.present ? data.detail.value : this.detail,
      amount: data.amount.present ? data.amount.value : this.amount,
      duration: data.duration.present ? data.duration.value : this.duration,
      calories: data.calories.present ? data.calories.value : this.calories,
      distance: data.distance.present ? data.distance.value : this.distance,
      category: data.category.present ? data.category.value : this.category,
      ritualId: data.ritualId.present ? data.ritualId.value : this.ritualId,
      note: data.note.present ? data.note.value : this.note,
      source: data.source.present ? data.source.value : this.source,
      sourceRef: data.sourceRef.present ? data.sourceRef.value : this.sourceRef,
      workoutId: data.workoutId.present ? data.workoutId.value : this.workoutId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EntryRow(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('detail: $detail, ')
          ..write('amount: $amount, ')
          ..write('duration: $duration, ')
          ..write('calories: $calories, ')
          ..write('distance: $distance, ')
          ..write('category: $category, ')
          ..write('ritualId: $ritualId, ')
          ..write('note: $note, ')
          ..write('source: $source, ')
          ..write('sourceRef: $sourceRef, ')
          ..write('workoutId: $workoutId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    timestamp,
    type,
    title,
    detail,
    amount,
    duration,
    calories,
    distance,
    category,
    ritualId,
    note,
    source,
    sourceRef,
    workoutId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntryRow &&
          other.id == this.id &&
          other.timestamp == this.timestamp &&
          other.type == this.type &&
          other.title == this.title &&
          other.detail == this.detail &&
          other.amount == this.amount &&
          other.duration == this.duration &&
          other.calories == this.calories &&
          other.distance == this.distance &&
          other.category == this.category &&
          other.ritualId == this.ritualId &&
          other.note == this.note &&
          other.source == this.source &&
          other.sourceRef == this.sourceRef &&
          other.workoutId == this.workoutId);
}

class EntriesCompanion extends UpdateCompanion<EntryRow> {
  final Value<String> id;
  final Value<DateTime> timestamp;
  final Value<String> type;
  final Value<String> title;
  final Value<String?> detail;
  final Value<double?> amount;
  final Value<int?> duration;
  final Value<int?> calories;
  final Value<double?> distance;
  final Value<String?> category;
  final Value<String?> ritualId;
  final Value<String?> note;
  final Value<String> source;
  final Value<String?> sourceRef;
  final Value<String?> workoutId;
  final Value<int> rowid;
  const EntriesCompanion({
    this.id = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.type = const Value.absent(),
    this.title = const Value.absent(),
    this.detail = const Value.absent(),
    this.amount = const Value.absent(),
    this.duration = const Value.absent(),
    this.calories = const Value.absent(),
    this.distance = const Value.absent(),
    this.category = const Value.absent(),
    this.ritualId = const Value.absent(),
    this.note = const Value.absent(),
    this.source = const Value.absent(),
    this.sourceRef = const Value.absent(),
    this.workoutId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EntriesCompanion.insert({
    required String id,
    required DateTime timestamp,
    required String type,
    required String title,
    this.detail = const Value.absent(),
    this.amount = const Value.absent(),
    this.duration = const Value.absent(),
    this.calories = const Value.absent(),
    this.distance = const Value.absent(),
    this.category = const Value.absent(),
    this.ritualId = const Value.absent(),
    this.note = const Value.absent(),
    required String source,
    this.sourceRef = const Value.absent(),
    this.workoutId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       timestamp = Value(timestamp),
       type = Value(type),
       title = Value(title),
       source = Value(source);
  static Insertable<EntryRow> custom({
    Expression<String>? id,
    Expression<DateTime>? timestamp,
    Expression<String>? type,
    Expression<String>? title,
    Expression<String>? detail,
    Expression<double>? amount,
    Expression<int>? duration,
    Expression<int>? calories,
    Expression<double>? distance,
    Expression<String>? category,
    Expression<String>? ritualId,
    Expression<String>? note,
    Expression<String>? source,
    Expression<String>? sourceRef,
    Expression<String>? workoutId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (timestamp != null) 'timestamp': timestamp,
      if (type != null) 'type': type,
      if (title != null) 'title': title,
      if (detail != null) 'detail': detail,
      if (amount != null) 'amount': amount,
      if (duration != null) 'duration': duration,
      if (calories != null) 'calories': calories,
      if (distance != null) 'distance': distance,
      if (category != null) 'category': category,
      if (ritualId != null) 'ritual_id': ritualId,
      if (note != null) 'note': note,
      if (source != null) 'source': source,
      if (sourceRef != null) 'source_ref': sourceRef,
      if (workoutId != null) 'workout_id': workoutId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EntriesCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? timestamp,
    Value<String>? type,
    Value<String>? title,
    Value<String?>? detail,
    Value<double?>? amount,
    Value<int?>? duration,
    Value<int?>? calories,
    Value<double?>? distance,
    Value<String?>? category,
    Value<String?>? ritualId,
    Value<String?>? note,
    Value<String>? source,
    Value<String?>? sourceRef,
    Value<String?>? workoutId,
    Value<int>? rowid,
  }) {
    return EntriesCompanion(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      title: title ?? this.title,
      detail: detail ?? this.detail,
      amount: amount ?? this.amount,
      duration: duration ?? this.duration,
      calories: calories ?? this.calories,
      distance: distance ?? this.distance,
      category: category ?? this.category,
      ritualId: ritualId ?? this.ritualId,
      note: note ?? this.note,
      source: source ?? this.source,
      sourceRef: sourceRef ?? this.sourceRef,
      workoutId: workoutId ?? this.workoutId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (detail.present) {
      map['detail'] = Variable<String>(detail.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (duration.present) {
      map['duration'] = Variable<int>(duration.value);
    }
    if (calories.present) {
      map['calories'] = Variable<int>(calories.value);
    }
    if (distance.present) {
      map['distance'] = Variable<double>(distance.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (ritualId.present) {
      map['ritual_id'] = Variable<String>(ritualId.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (sourceRef.present) {
      map['source_ref'] = Variable<String>(sourceRef.value);
    }
    if (workoutId.present) {
      map['workout_id'] = Variable<String>(workoutId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntriesCompanion(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('detail: $detail, ')
          ..write('amount: $amount, ')
          ..write('duration: $duration, ')
          ..write('calories: $calories, ')
          ..write('distance: $distance, ')
          ..write('category: $category, ')
          ..write('ritualId: $ritualId, ')
          ..write('note: $note, ')
          ..write('source: $source, ')
          ..write('sourceRef: $sourceRef, ')
          ..write('workoutId: $workoutId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExercisesTable extends Exercises
    with TableInfo<$ExercisesTable, ExerciseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExercisesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _groupMeta = const VerificationMeta('group');
  @override
  late final GeneratedColumn<String> group = GeneratedColumn<String>(
    'group',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _muscleMeta = const VerificationMeta('muscle');
  @override
  late final GeneratedColumn<String> muscle = GeneratedColumn<String>(
    'muscle',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _equipmentMeta = const VerificationMeta(
    'equipment',
  );
  @override
  late final GeneratedColumn<String> equipment = GeneratedColumn<String>(
    'equipment',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _prWeightKgMeta = const VerificationMeta(
    'prWeightKg',
  );
  @override
  late final GeneratedColumn<double> prWeightKg = GeneratedColumn<double>(
    'pr_weight_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _prRepsMeta = const VerificationMeta('prReps');
  @override
  late final GeneratedColumn<int> prReps = GeneratedColumn<int>(
    'pr_reps',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    group,
    muscle,
    icon,
    equipment,
    prWeightKg,
    prReps,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercises';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExerciseRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('group')) {
      context.handle(
        _groupMeta,
        group.isAcceptableOrUnknown(data['group']!, _groupMeta),
      );
    } else if (isInserting) {
      context.missing(_groupMeta);
    }
    if (data.containsKey('muscle')) {
      context.handle(
        _muscleMeta,
        muscle.isAcceptableOrUnknown(data['muscle']!, _muscleMeta),
      );
    } else if (isInserting) {
      context.missing(_muscleMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    } else if (isInserting) {
      context.missing(_iconMeta);
    }
    if (data.containsKey('equipment')) {
      context.handle(
        _equipmentMeta,
        equipment.isAcceptableOrUnknown(data['equipment']!, _equipmentMeta),
      );
    }
    if (data.containsKey('pr_weight_kg')) {
      context.handle(
        _prWeightKgMeta,
        prWeightKg.isAcceptableOrUnknown(
          data['pr_weight_kg']!,
          _prWeightKgMeta,
        ),
      );
    }
    if (data.containsKey('pr_reps')) {
      context.handle(
        _prRepsMeta,
        prReps.isAcceptableOrUnknown(data['pr_reps']!, _prRepsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExerciseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExerciseRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      group: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group'],
      )!,
      muscle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}muscle'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      )!,
      equipment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}equipment'],
      ),
      prWeightKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pr_weight_kg'],
      ),
      prReps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pr_reps'],
      ),
    );
  }

  @override
  $ExercisesTable createAlias(String alias) {
    return $ExercisesTable(attachedDatabase, alias);
  }
}

class ExerciseRow extends DataClass implements Insertable<ExerciseRow> {
  final String id;
  final String name;
  final String group;
  final String muscle;
  final String icon;
  final String? equipment;

  /// `ExercisePR.weightKg` — null when the exercise has no PR.
  final double? prWeightKg;

  /// `ExercisePR.reps` — null when the exercise has no PR.
  final int? prReps;
  const ExerciseRow({
    required this.id,
    required this.name,
    required this.group,
    required this.muscle,
    required this.icon,
    this.equipment,
    this.prWeightKg,
    this.prReps,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['group'] = Variable<String>(group);
    map['muscle'] = Variable<String>(muscle);
    map['icon'] = Variable<String>(icon);
    if (!nullToAbsent || equipment != null) {
      map['equipment'] = Variable<String>(equipment);
    }
    if (!nullToAbsent || prWeightKg != null) {
      map['pr_weight_kg'] = Variable<double>(prWeightKg);
    }
    if (!nullToAbsent || prReps != null) {
      map['pr_reps'] = Variable<int>(prReps);
    }
    return map;
  }

  ExercisesCompanion toCompanion(bool nullToAbsent) {
    return ExercisesCompanion(
      id: Value(id),
      name: Value(name),
      group: Value(group),
      muscle: Value(muscle),
      icon: Value(icon),
      equipment: equipment == null && nullToAbsent
          ? const Value.absent()
          : Value(equipment),
      prWeightKg: prWeightKg == null && nullToAbsent
          ? const Value.absent()
          : Value(prWeightKg),
      prReps: prReps == null && nullToAbsent
          ? const Value.absent()
          : Value(prReps),
    );
  }

  factory ExerciseRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExerciseRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      group: serializer.fromJson<String>(json['group']),
      muscle: serializer.fromJson<String>(json['muscle']),
      icon: serializer.fromJson<String>(json['icon']),
      equipment: serializer.fromJson<String?>(json['equipment']),
      prWeightKg: serializer.fromJson<double?>(json['prWeightKg']),
      prReps: serializer.fromJson<int?>(json['prReps']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'group': serializer.toJson<String>(group),
      'muscle': serializer.toJson<String>(muscle),
      'icon': serializer.toJson<String>(icon),
      'equipment': serializer.toJson<String?>(equipment),
      'prWeightKg': serializer.toJson<double?>(prWeightKg),
      'prReps': serializer.toJson<int?>(prReps),
    };
  }

  ExerciseRow copyWith({
    String? id,
    String? name,
    String? group,
    String? muscle,
    String? icon,
    Value<String?> equipment = const Value.absent(),
    Value<double?> prWeightKg = const Value.absent(),
    Value<int?> prReps = const Value.absent(),
  }) => ExerciseRow(
    id: id ?? this.id,
    name: name ?? this.name,
    group: group ?? this.group,
    muscle: muscle ?? this.muscle,
    icon: icon ?? this.icon,
    equipment: equipment.present ? equipment.value : this.equipment,
    prWeightKg: prWeightKg.present ? prWeightKg.value : this.prWeightKg,
    prReps: prReps.present ? prReps.value : this.prReps,
  );
  ExerciseRow copyWithCompanion(ExercisesCompanion data) {
    return ExerciseRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      group: data.group.present ? data.group.value : this.group,
      muscle: data.muscle.present ? data.muscle.value : this.muscle,
      icon: data.icon.present ? data.icon.value : this.icon,
      equipment: data.equipment.present ? data.equipment.value : this.equipment,
      prWeightKg: data.prWeightKg.present
          ? data.prWeightKg.value
          : this.prWeightKg,
      prReps: data.prReps.present ? data.prReps.value : this.prReps,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('group: $group, ')
          ..write('muscle: $muscle, ')
          ..write('icon: $icon, ')
          ..write('equipment: $equipment, ')
          ..write('prWeightKg: $prWeightKg, ')
          ..write('prReps: $prReps')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, group, muscle, icon, equipment, prWeightKg, prReps);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExerciseRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.group == this.group &&
          other.muscle == this.muscle &&
          other.icon == this.icon &&
          other.equipment == this.equipment &&
          other.prWeightKg == this.prWeightKg &&
          other.prReps == this.prReps);
}

class ExercisesCompanion extends UpdateCompanion<ExerciseRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> group;
  final Value<String> muscle;
  final Value<String> icon;
  final Value<String?> equipment;
  final Value<double?> prWeightKg;
  final Value<int?> prReps;
  final Value<int> rowid;
  const ExercisesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.group = const Value.absent(),
    this.muscle = const Value.absent(),
    this.icon = const Value.absent(),
    this.equipment = const Value.absent(),
    this.prWeightKg = const Value.absent(),
    this.prReps = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExercisesCompanion.insert({
    required String id,
    required String name,
    required String group,
    required String muscle,
    required String icon,
    this.equipment = const Value.absent(),
    this.prWeightKg = const Value.absent(),
    this.prReps = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       group = Value(group),
       muscle = Value(muscle),
       icon = Value(icon);
  static Insertable<ExerciseRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? group,
    Expression<String>? muscle,
    Expression<String>? icon,
    Expression<String>? equipment,
    Expression<double>? prWeightKg,
    Expression<int>? prReps,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (group != null) 'group': group,
      if (muscle != null) 'muscle': muscle,
      if (icon != null) 'icon': icon,
      if (equipment != null) 'equipment': equipment,
      if (prWeightKg != null) 'pr_weight_kg': prWeightKg,
      if (prReps != null) 'pr_reps': prReps,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExercisesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? group,
    Value<String>? muscle,
    Value<String>? icon,
    Value<String?>? equipment,
    Value<double?>? prWeightKg,
    Value<int?>? prReps,
    Value<int>? rowid,
  }) {
    return ExercisesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      group: group ?? this.group,
      muscle: muscle ?? this.muscle,
      icon: icon ?? this.icon,
      equipment: equipment ?? this.equipment,
      prWeightKg: prWeightKg ?? this.prWeightKg,
      prReps: prReps ?? this.prReps,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (group.present) {
      map['group'] = Variable<String>(group.value);
    }
    if (muscle.present) {
      map['muscle'] = Variable<String>(muscle.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (equipment.present) {
      map['equipment'] = Variable<String>(equipment.value);
    }
    if (prWeightKg.present) {
      map['pr_weight_kg'] = Variable<double>(prWeightKg.value);
    }
    if (prReps.present) {
      map['pr_reps'] = Variable<int>(prReps.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExercisesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('group: $group, ')
          ..write('muscle: $muscle, ')
          ..write('icon: $icon, ')
          ..write('equipment: $equipment, ')
          ..write('prWeightKg: $prWeightKg, ')
          ..write('prReps: $prReps, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RoutinesTable extends Routines
    with TableInfo<$RoutinesTable, RoutineRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoutinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _restSecondsMeta = const VerificationMeta(
    'restSeconds',
  );
  @override
  late final GeneratedColumn<int> restSeconds = GeneratedColumn<int>(
    'rest_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(120),
  );
  static const VerificationMeta _warmupReminderMeta = const VerificationMeta(
    'warmupReminder',
  );
  @override
  late final GeneratedColumn<bool> warmupReminder = GeneratedColumn<bool>(
    'warmup_reminder',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("warmup_reminder" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _autoProgressMeta = const VerificationMeta(
    'autoProgress',
  );
  @override
  late final GeneratedColumn<bool> autoProgress = GeneratedColumn<bool>(
    'auto_progress',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_progress" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _estMinMeta = const VerificationMeta('estMin');
  @override
  late final GeneratedColumn<int> estMin = GeneratedColumn<int>(
    'est_min',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _distanceKmMeta = const VerificationMeta(
    'distanceKm',
  );
  @override
  late final GeneratedColumn<double> distanceKm = GeneratedColumn<double>(
    'distance_km',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paceMeta = const VerificationMeta('pace');
  @override
  late final GeneratedColumn<String> pace = GeneratedColumn<String>(
    'pace',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    tag,
    restSeconds,
    warmupReminder,
    autoProgress,
    estMin,
    distanceKm,
    pace,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'routines';
  @override
  VerificationContext validateIntegrity(
    Insertable<RoutineRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    if (data.containsKey('rest_seconds')) {
      context.handle(
        _restSecondsMeta,
        restSeconds.isAcceptableOrUnknown(
          data['rest_seconds']!,
          _restSecondsMeta,
        ),
      );
    }
    if (data.containsKey('warmup_reminder')) {
      context.handle(
        _warmupReminderMeta,
        warmupReminder.isAcceptableOrUnknown(
          data['warmup_reminder']!,
          _warmupReminderMeta,
        ),
      );
    }
    if (data.containsKey('auto_progress')) {
      context.handle(
        _autoProgressMeta,
        autoProgress.isAcceptableOrUnknown(
          data['auto_progress']!,
          _autoProgressMeta,
        ),
      );
    }
    if (data.containsKey('est_min')) {
      context.handle(
        _estMinMeta,
        estMin.isAcceptableOrUnknown(data['est_min']!, _estMinMeta),
      );
    }
    if (data.containsKey('distance_km')) {
      context.handle(
        _distanceKmMeta,
        distanceKm.isAcceptableOrUnknown(data['distance_km']!, _distanceKmMeta),
      );
    }
    if (data.containsKey('pace')) {
      context.handle(
        _paceMeta,
        pace.isAcceptableOrUnknown(data['pace']!, _paceMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RoutineRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RoutineRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      )!,
      restSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rest_seconds'],
      )!,
      warmupReminder: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}warmup_reminder'],
      )!,
      autoProgress: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_progress'],
      )!,
      estMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}est_min'],
      ),
      distanceKm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}distance_km'],
      ),
      pace: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pace'],
      ),
    );
  }

  @override
  $RoutinesTable createAlias(String alias) {
    return $RoutinesTable(attachedDatabase, alias);
  }
}

class RoutineRow extends DataClass implements Insertable<RoutineRow> {
  final String id;
  final String name;

  /// [RoutineTag.wire].
  final String tag;
  final int restSeconds;
  final bool warmupReminder;
  final bool autoProgress;

  /// Authored session-length estimate in minutes (null → derived heuristic).
  final int? estMin;

  /// Planned cardio distance in km (null for strength).
  final double? distanceKm;

  /// Display cardio pace string, e.g. "5:00 /km" (null for strength).
  final String? pace;
  const RoutineRow({
    required this.id,
    required this.name,
    required this.tag,
    required this.restSeconds,
    required this.warmupReminder,
    required this.autoProgress,
    this.estMin,
    this.distanceKm,
    this.pace,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['tag'] = Variable<String>(tag);
    map['rest_seconds'] = Variable<int>(restSeconds);
    map['warmup_reminder'] = Variable<bool>(warmupReminder);
    map['auto_progress'] = Variable<bool>(autoProgress);
    if (!nullToAbsent || estMin != null) {
      map['est_min'] = Variable<int>(estMin);
    }
    if (!nullToAbsent || distanceKm != null) {
      map['distance_km'] = Variable<double>(distanceKm);
    }
    if (!nullToAbsent || pace != null) {
      map['pace'] = Variable<String>(pace);
    }
    return map;
  }

  RoutinesCompanion toCompanion(bool nullToAbsent) {
    return RoutinesCompanion(
      id: Value(id),
      name: Value(name),
      tag: Value(tag),
      restSeconds: Value(restSeconds),
      warmupReminder: Value(warmupReminder),
      autoProgress: Value(autoProgress),
      estMin: estMin == null && nullToAbsent
          ? const Value.absent()
          : Value(estMin),
      distanceKm: distanceKm == null && nullToAbsent
          ? const Value.absent()
          : Value(distanceKm),
      pace: pace == null && nullToAbsent ? const Value.absent() : Value(pace),
    );
  }

  factory RoutineRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RoutineRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      tag: serializer.fromJson<String>(json['tag']),
      restSeconds: serializer.fromJson<int>(json['restSeconds']),
      warmupReminder: serializer.fromJson<bool>(json['warmupReminder']),
      autoProgress: serializer.fromJson<bool>(json['autoProgress']),
      estMin: serializer.fromJson<int?>(json['estMin']),
      distanceKm: serializer.fromJson<double?>(json['distanceKm']),
      pace: serializer.fromJson<String?>(json['pace']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'tag': serializer.toJson<String>(tag),
      'restSeconds': serializer.toJson<int>(restSeconds),
      'warmupReminder': serializer.toJson<bool>(warmupReminder),
      'autoProgress': serializer.toJson<bool>(autoProgress),
      'estMin': serializer.toJson<int?>(estMin),
      'distanceKm': serializer.toJson<double?>(distanceKm),
      'pace': serializer.toJson<String?>(pace),
    };
  }

  RoutineRow copyWith({
    String? id,
    String? name,
    String? tag,
    int? restSeconds,
    bool? warmupReminder,
    bool? autoProgress,
    Value<int?> estMin = const Value.absent(),
    Value<double?> distanceKm = const Value.absent(),
    Value<String?> pace = const Value.absent(),
  }) => RoutineRow(
    id: id ?? this.id,
    name: name ?? this.name,
    tag: tag ?? this.tag,
    restSeconds: restSeconds ?? this.restSeconds,
    warmupReminder: warmupReminder ?? this.warmupReminder,
    autoProgress: autoProgress ?? this.autoProgress,
    estMin: estMin.present ? estMin.value : this.estMin,
    distanceKm: distanceKm.present ? distanceKm.value : this.distanceKm,
    pace: pace.present ? pace.value : this.pace,
  );
  RoutineRow copyWithCompanion(RoutinesCompanion data) {
    return RoutineRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      tag: data.tag.present ? data.tag.value : this.tag,
      restSeconds: data.restSeconds.present
          ? data.restSeconds.value
          : this.restSeconds,
      warmupReminder: data.warmupReminder.present
          ? data.warmupReminder.value
          : this.warmupReminder,
      autoProgress: data.autoProgress.present
          ? data.autoProgress.value
          : this.autoProgress,
      estMin: data.estMin.present ? data.estMin.value : this.estMin,
      distanceKm: data.distanceKm.present
          ? data.distanceKm.value
          : this.distanceKm,
      pace: data.pace.present ? data.pace.value : this.pace,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RoutineRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('tag: $tag, ')
          ..write('restSeconds: $restSeconds, ')
          ..write('warmupReminder: $warmupReminder, ')
          ..write('autoProgress: $autoProgress, ')
          ..write('estMin: $estMin, ')
          ..write('distanceKm: $distanceKm, ')
          ..write('pace: $pace')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    tag,
    restSeconds,
    warmupReminder,
    autoProgress,
    estMin,
    distanceKm,
    pace,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RoutineRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.tag == this.tag &&
          other.restSeconds == this.restSeconds &&
          other.warmupReminder == this.warmupReminder &&
          other.autoProgress == this.autoProgress &&
          other.estMin == this.estMin &&
          other.distanceKm == this.distanceKm &&
          other.pace == this.pace);
}

class RoutinesCompanion extends UpdateCompanion<RoutineRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> tag;
  final Value<int> restSeconds;
  final Value<bool> warmupReminder;
  final Value<bool> autoProgress;
  final Value<int?> estMin;
  final Value<double?> distanceKm;
  final Value<String?> pace;
  final Value<int> rowid;
  const RoutinesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.tag = const Value.absent(),
    this.restSeconds = const Value.absent(),
    this.warmupReminder = const Value.absent(),
    this.autoProgress = const Value.absent(),
    this.estMin = const Value.absent(),
    this.distanceKm = const Value.absent(),
    this.pace = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RoutinesCompanion.insert({
    required String id,
    required String name,
    required String tag,
    this.restSeconds = const Value.absent(),
    this.warmupReminder = const Value.absent(),
    this.autoProgress = const Value.absent(),
    this.estMin = const Value.absent(),
    this.distanceKm = const Value.absent(),
    this.pace = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       tag = Value(tag);
  static Insertable<RoutineRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? tag,
    Expression<int>? restSeconds,
    Expression<bool>? warmupReminder,
    Expression<bool>? autoProgress,
    Expression<int>? estMin,
    Expression<double>? distanceKm,
    Expression<String>? pace,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (tag != null) 'tag': tag,
      if (restSeconds != null) 'rest_seconds': restSeconds,
      if (warmupReminder != null) 'warmup_reminder': warmupReminder,
      if (autoProgress != null) 'auto_progress': autoProgress,
      if (estMin != null) 'est_min': estMin,
      if (distanceKm != null) 'distance_km': distanceKm,
      if (pace != null) 'pace': pace,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RoutinesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? tag,
    Value<int>? restSeconds,
    Value<bool>? warmupReminder,
    Value<bool>? autoProgress,
    Value<int?>? estMin,
    Value<double?>? distanceKm,
    Value<String?>? pace,
    Value<int>? rowid,
  }) {
    return RoutinesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      tag: tag ?? this.tag,
      restSeconds: restSeconds ?? this.restSeconds,
      warmupReminder: warmupReminder ?? this.warmupReminder,
      autoProgress: autoProgress ?? this.autoProgress,
      estMin: estMin ?? this.estMin,
      distanceKm: distanceKm ?? this.distanceKm,
      pace: pace ?? this.pace,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (restSeconds.present) {
      map['rest_seconds'] = Variable<int>(restSeconds.value);
    }
    if (warmupReminder.present) {
      map['warmup_reminder'] = Variable<bool>(warmupReminder.value);
    }
    if (autoProgress.present) {
      map['auto_progress'] = Variable<bool>(autoProgress.value);
    }
    if (estMin.present) {
      map['est_min'] = Variable<int>(estMin.value);
    }
    if (distanceKm.present) {
      map['distance_km'] = Variable<double>(distanceKm.value);
    }
    if (pace.present) {
      map['pace'] = Variable<String>(pace.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoutinesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('tag: $tag, ')
          ..write('restSeconds: $restSeconds, ')
          ..write('warmupReminder: $warmupReminder, ')
          ..write('autoProgress: $autoProgress, ')
          ..write('estMin: $estMin, ')
          ..write('distanceKm: $distanceKm, ')
          ..write('pace: $pace, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RoutineExercisesTable extends RoutineExercises
    with TableInfo<$RoutineExercisesTable, RoutineExerciseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoutineExercisesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _routineIdMeta = const VerificationMeta(
    'routineId',
  );
  @override
  late final GeneratedColumn<String> routineId = GeneratedColumn<String>(
    'routine_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta(
    'exerciseId',
  );
  @override
  late final GeneratedColumn<String> exerciseId = GeneratedColumn<String>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetSetsMeta = const VerificationMeta(
    'targetSets',
  );
  @override
  late final GeneratedColumn<int> targetSets = GeneratedColumn<int>(
    'target_sets',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(3),
  );
  static const VerificationMeta _targetRepsMeta = const VerificationMeta(
    'targetReps',
  );
  @override
  late final GeneratedColumn<int> targetReps = GeneratedColumn<int>(
    'target_reps',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetWeightKgMeta = const VerificationMeta(
    'targetWeightKg',
  );
  @override
  late final GeneratedColumn<double> targetWeightKg = GeneratedColumn<double>(
    'target_weight_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    routineId,
    exerciseId,
    position,
    targetSets,
    targetReps,
    targetWeightKg,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'routine_exercises';
  @override
  VerificationContext validateIntegrity(
    Insertable<RoutineExerciseRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('routine_id')) {
      context.handle(
        _routineIdMeta,
        routineId.isAcceptableOrUnknown(data['routine_id']!, _routineIdMeta),
      );
    } else if (isInserting) {
      context.missing(_routineIdMeta);
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('target_sets')) {
      context.handle(
        _targetSetsMeta,
        targetSets.isAcceptableOrUnknown(data['target_sets']!, _targetSetsMeta),
      );
    }
    if (data.containsKey('target_reps')) {
      context.handle(
        _targetRepsMeta,
        targetReps.isAcceptableOrUnknown(data['target_reps']!, _targetRepsMeta),
      );
    }
    if (data.containsKey('target_weight_kg')) {
      context.handle(
        _targetWeightKgMeta,
        targetWeightKg.isAcceptableOrUnknown(
          data['target_weight_kg']!,
          _targetWeightKgMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RoutineExerciseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RoutineExerciseRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      routineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}routine_id'],
      )!,
      exerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      targetSets: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_sets'],
      )!,
      targetReps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_reps'],
      ),
      targetWeightKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}target_weight_kg'],
      ),
    );
  }

  @override
  $RoutineExercisesTable createAlias(String alias) {
    return $RoutineExercisesTable(attachedDatabase, alias);
  }
}

class RoutineExerciseRow extends DataClass
    implements Insertable<RoutineExerciseRow> {
  final String id;
  final String routineId;
  final String exerciseId;

  /// `RoutineExercise.order` (renamed; `order` is a SQL keyword).
  final int position;
  final int targetSets;
  final int? targetReps;
  final double? targetWeightKg;
  const RoutineExerciseRow({
    required this.id,
    required this.routineId,
    required this.exerciseId,
    required this.position,
    required this.targetSets,
    this.targetReps,
    this.targetWeightKg,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['routine_id'] = Variable<String>(routineId);
    map['exercise_id'] = Variable<String>(exerciseId);
    map['position'] = Variable<int>(position);
    map['target_sets'] = Variable<int>(targetSets);
    if (!nullToAbsent || targetReps != null) {
      map['target_reps'] = Variable<int>(targetReps);
    }
    if (!nullToAbsent || targetWeightKg != null) {
      map['target_weight_kg'] = Variable<double>(targetWeightKg);
    }
    return map;
  }

  RoutineExercisesCompanion toCompanion(bool nullToAbsent) {
    return RoutineExercisesCompanion(
      id: Value(id),
      routineId: Value(routineId),
      exerciseId: Value(exerciseId),
      position: Value(position),
      targetSets: Value(targetSets),
      targetReps: targetReps == null && nullToAbsent
          ? const Value.absent()
          : Value(targetReps),
      targetWeightKg: targetWeightKg == null && nullToAbsent
          ? const Value.absent()
          : Value(targetWeightKg),
    );
  }

  factory RoutineExerciseRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RoutineExerciseRow(
      id: serializer.fromJson<String>(json['id']),
      routineId: serializer.fromJson<String>(json['routineId']),
      exerciseId: serializer.fromJson<String>(json['exerciseId']),
      position: serializer.fromJson<int>(json['position']),
      targetSets: serializer.fromJson<int>(json['targetSets']),
      targetReps: serializer.fromJson<int?>(json['targetReps']),
      targetWeightKg: serializer.fromJson<double?>(json['targetWeightKg']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'routineId': serializer.toJson<String>(routineId),
      'exerciseId': serializer.toJson<String>(exerciseId),
      'position': serializer.toJson<int>(position),
      'targetSets': serializer.toJson<int>(targetSets),
      'targetReps': serializer.toJson<int?>(targetReps),
      'targetWeightKg': serializer.toJson<double?>(targetWeightKg),
    };
  }

  RoutineExerciseRow copyWith({
    String? id,
    String? routineId,
    String? exerciseId,
    int? position,
    int? targetSets,
    Value<int?> targetReps = const Value.absent(),
    Value<double?> targetWeightKg = const Value.absent(),
  }) => RoutineExerciseRow(
    id: id ?? this.id,
    routineId: routineId ?? this.routineId,
    exerciseId: exerciseId ?? this.exerciseId,
    position: position ?? this.position,
    targetSets: targetSets ?? this.targetSets,
    targetReps: targetReps.present ? targetReps.value : this.targetReps,
    targetWeightKg: targetWeightKg.present
        ? targetWeightKg.value
        : this.targetWeightKg,
  );
  RoutineExerciseRow copyWithCompanion(RoutineExercisesCompanion data) {
    return RoutineExerciseRow(
      id: data.id.present ? data.id.value : this.id,
      routineId: data.routineId.present ? data.routineId.value : this.routineId,
      exerciseId: data.exerciseId.present
          ? data.exerciseId.value
          : this.exerciseId,
      position: data.position.present ? data.position.value : this.position,
      targetSets: data.targetSets.present
          ? data.targetSets.value
          : this.targetSets,
      targetReps: data.targetReps.present
          ? data.targetReps.value
          : this.targetReps,
      targetWeightKg: data.targetWeightKg.present
          ? data.targetWeightKg.value
          : this.targetWeightKg,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RoutineExerciseRow(')
          ..write('id: $id, ')
          ..write('routineId: $routineId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('position: $position, ')
          ..write('targetSets: $targetSets, ')
          ..write('targetReps: $targetReps, ')
          ..write('targetWeightKg: $targetWeightKg')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    routineId,
    exerciseId,
    position,
    targetSets,
    targetReps,
    targetWeightKg,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RoutineExerciseRow &&
          other.id == this.id &&
          other.routineId == this.routineId &&
          other.exerciseId == this.exerciseId &&
          other.position == this.position &&
          other.targetSets == this.targetSets &&
          other.targetReps == this.targetReps &&
          other.targetWeightKg == this.targetWeightKg);
}

class RoutineExercisesCompanion extends UpdateCompanion<RoutineExerciseRow> {
  final Value<String> id;
  final Value<String> routineId;
  final Value<String> exerciseId;
  final Value<int> position;
  final Value<int> targetSets;
  final Value<int?> targetReps;
  final Value<double?> targetWeightKg;
  final Value<int> rowid;
  const RoutineExercisesCompanion({
    this.id = const Value.absent(),
    this.routineId = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.position = const Value.absent(),
    this.targetSets = const Value.absent(),
    this.targetReps = const Value.absent(),
    this.targetWeightKg = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RoutineExercisesCompanion.insert({
    required String id,
    required String routineId,
    required String exerciseId,
    required int position,
    this.targetSets = const Value.absent(),
    this.targetReps = const Value.absent(),
    this.targetWeightKg = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       routineId = Value(routineId),
       exerciseId = Value(exerciseId),
       position = Value(position);
  static Insertable<RoutineExerciseRow> custom({
    Expression<String>? id,
    Expression<String>? routineId,
    Expression<String>? exerciseId,
    Expression<int>? position,
    Expression<int>? targetSets,
    Expression<int>? targetReps,
    Expression<double>? targetWeightKg,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (routineId != null) 'routine_id': routineId,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (position != null) 'position': position,
      if (targetSets != null) 'target_sets': targetSets,
      if (targetReps != null) 'target_reps': targetReps,
      if (targetWeightKg != null) 'target_weight_kg': targetWeightKg,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RoutineExercisesCompanion copyWith({
    Value<String>? id,
    Value<String>? routineId,
    Value<String>? exerciseId,
    Value<int>? position,
    Value<int>? targetSets,
    Value<int?>? targetReps,
    Value<double?>? targetWeightKg,
    Value<int>? rowid,
  }) {
    return RoutineExercisesCompanion(
      id: id ?? this.id,
      routineId: routineId ?? this.routineId,
      exerciseId: exerciseId ?? this.exerciseId,
      position: position ?? this.position,
      targetSets: targetSets ?? this.targetSets,
      targetReps: targetReps ?? this.targetReps,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (routineId.present) {
      map['routine_id'] = Variable<String>(routineId.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<String>(exerciseId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (targetSets.present) {
      map['target_sets'] = Variable<int>(targetSets.value);
    }
    if (targetReps.present) {
      map['target_reps'] = Variable<int>(targetReps.value);
    }
    if (targetWeightKg.present) {
      map['target_weight_kg'] = Variable<double>(targetWeightKg.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoutineExercisesCompanion(')
          ..write('id: $id, ')
          ..write('routineId: $routineId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('position: $position, ')
          ..write('targetSets: $targetSets, ')
          ..write('targetReps: $targetReps, ')
          ..write('targetWeightKg: $targetWeightKg, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkoutsTable extends Workouts
    with TableInfo<$WorkoutsTable, WorkoutRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _routineIdMeta = const VerificationMeta(
    'routineId',
  );
  @override
  late final GeneratedColumn<String> routineId = GeneratedColumn<String>(
    'routine_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    routineId,
    name,
    startedAt,
    endedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workouts';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkoutRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('routine_id')) {
      context.handle(
        _routineIdMeta,
        routineId.isAcceptableOrUnknown(data['routine_id']!, _routineIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkoutRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      routineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}routine_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
    );
  }

  @override
  $WorkoutsTable createAlias(String alias) {
    return $WorkoutsTable(attachedDatabase, alias);
  }
}

class WorkoutRow extends DataClass implements Insertable<WorkoutRow> {
  final String id;
  final String? routineId;
  final String name;
  final DateTime startedAt;
  final DateTime? endedAt;
  const WorkoutRow({
    required this.id,
    this.routineId,
    required this.name,
    required this.startedAt,
    this.endedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || routineId != null) {
      map['routine_id'] = Variable<String>(routineId);
    }
    map['name'] = Variable<String>(name);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    return map;
  }

  WorkoutsCompanion toCompanion(bool nullToAbsent) {
    return WorkoutsCompanion(
      id: Value(id),
      routineId: routineId == null && nullToAbsent
          ? const Value.absent()
          : Value(routineId),
      name: Value(name),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
    );
  }

  factory WorkoutRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutRow(
      id: serializer.fromJson<String>(json['id']),
      routineId: serializer.fromJson<String?>(json['routineId']),
      name: serializer.fromJson<String>(json['name']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'routineId': serializer.toJson<String?>(routineId),
      'name': serializer.toJson<String>(name),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
    };
  }

  WorkoutRow copyWith({
    String? id,
    Value<String?> routineId = const Value.absent(),
    String? name,
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
  }) => WorkoutRow(
    id: id ?? this.id,
    routineId: routineId.present ? routineId.value : this.routineId,
    name: name ?? this.name,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
  );
  WorkoutRow copyWithCompanion(WorkoutsCompanion data) {
    return WorkoutRow(
      id: data.id.present ? data.id.value : this.id,
      routineId: data.routineId.present ? data.routineId.value : this.routineId,
      name: data.name.present ? data.name.value : this.name,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutRow(')
          ..write('id: $id, ')
          ..write('routineId: $routineId, ')
          ..write('name: $name, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, routineId, name, startedAt, endedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutRow &&
          other.id == this.id &&
          other.routineId == this.routineId &&
          other.name == this.name &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt);
}

class WorkoutsCompanion extends UpdateCompanion<WorkoutRow> {
  final Value<String> id;
  final Value<String?> routineId;
  final Value<String> name;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<int> rowid;
  const WorkoutsCompanion({
    this.id = const Value.absent(),
    this.routineId = const Value.absent(),
    this.name = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkoutsCompanion.insert({
    required String id,
    this.routineId = const Value.absent(),
    required String name,
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       startedAt = Value(startedAt);
  static Insertable<WorkoutRow> custom({
    Expression<String>? id,
    Expression<String>? routineId,
    Expression<String>? name,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (routineId != null) 'routine_id': routineId,
      if (name != null) 'name': name,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkoutsCompanion copyWith({
    Value<String>? id,
    Value<String?>? routineId,
    Value<String>? name,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<int>? rowid,
  }) {
    return WorkoutsCompanion(
      id: id ?? this.id,
      routineId: routineId ?? this.routineId,
      name: name ?? this.name,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (routineId.present) {
      map['routine_id'] = Variable<String>(routineId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutsCompanion(')
          ..write('id: $id, ')
          ..write('routineId: $routineId, ')
          ..write('name: $name, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SetLogsTable extends SetLogs with TableInfo<$SetLogsTable, SetLogRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SetLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _workoutIdMeta = const VerificationMeta(
    'workoutId',
  );
  @override
  late final GeneratedColumn<String> workoutId = GeneratedColumn<String>(
    'workout_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta(
    'exerciseId',
  );
  @override
  late final GeneratedColumn<String> exerciseId = GeneratedColumn<String>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weightKgMeta = const VerificationMeta(
    'weightKg',
  );
  @override
  late final GeneratedColumn<double> weightKg = GeneratedColumn<double>(
    'weight_kg',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
    'reps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _doneMeta = const VerificationMeta('done');
  @override
  late final GeneratedColumn<bool> done = GeneratedColumn<bool>(
    'done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("done" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isPRMeta = const VerificationMeta('isPR');
  @override
  late final GeneratedColumn<bool> isPR = GeneratedColumn<bool>(
    'is_p_r',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_p_r" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    workoutId,
    exerciseId,
    weightKg,
    reps,
    done,
    isPR,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'set_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<SetLogRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workout_id')) {
      context.handle(
        _workoutIdMeta,
        workoutId.isAcceptableOrUnknown(data['workout_id']!, _workoutIdMeta),
      );
    } else if (isInserting) {
      context.missing(_workoutIdMeta);
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('weight_kg')) {
      context.handle(
        _weightKgMeta,
        weightKg.isAcceptableOrUnknown(data['weight_kg']!, _weightKgMeta),
      );
    } else if (isInserting) {
      context.missing(_weightKgMeta);
    }
    if (data.containsKey('reps')) {
      context.handle(
        _repsMeta,
        reps.isAcceptableOrUnknown(data['reps']!, _repsMeta),
      );
    } else if (isInserting) {
      context.missing(_repsMeta);
    }
    if (data.containsKey('done')) {
      context.handle(
        _doneMeta,
        done.isAcceptableOrUnknown(data['done']!, _doneMeta),
      );
    }
    if (data.containsKey('is_p_r')) {
      context.handle(
        _isPRMeta,
        isPR.isAcceptableOrUnknown(data['is_p_r']!, _isPRMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SetLogRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SetLogRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      workoutId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workout_id'],
      )!,
      exerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_id'],
      )!,
      weightKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight_kg'],
      )!,
      reps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reps'],
      )!,
      done: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}done'],
      )!,
      isPR: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_p_r'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $SetLogsTable createAlias(String alias) {
    return $SetLogsTable(attachedDatabase, alias);
  }
}

class SetLogRow extends DataClass implements Insertable<SetLogRow> {
  final String id;
  final String workoutId;
  final String exerciseId;
  final double weightKg;
  final int reps;
  final bool done;
  final bool isPR;

  /// Preserves insertion order within a workout.
  final int position;
  const SetLogRow({
    required this.id,
    required this.workoutId,
    required this.exerciseId,
    required this.weightKg,
    required this.reps,
    required this.done,
    required this.isPR,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['workout_id'] = Variable<String>(workoutId);
    map['exercise_id'] = Variable<String>(exerciseId);
    map['weight_kg'] = Variable<double>(weightKg);
    map['reps'] = Variable<int>(reps);
    map['done'] = Variable<bool>(done);
    map['is_p_r'] = Variable<bool>(isPR);
    map['position'] = Variable<int>(position);
    return map;
  }

  SetLogsCompanion toCompanion(bool nullToAbsent) {
    return SetLogsCompanion(
      id: Value(id),
      workoutId: Value(workoutId),
      exerciseId: Value(exerciseId),
      weightKg: Value(weightKg),
      reps: Value(reps),
      done: Value(done),
      isPR: Value(isPR),
      position: Value(position),
    );
  }

  factory SetLogRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SetLogRow(
      id: serializer.fromJson<String>(json['id']),
      workoutId: serializer.fromJson<String>(json['workoutId']),
      exerciseId: serializer.fromJson<String>(json['exerciseId']),
      weightKg: serializer.fromJson<double>(json['weightKg']),
      reps: serializer.fromJson<int>(json['reps']),
      done: serializer.fromJson<bool>(json['done']),
      isPR: serializer.fromJson<bool>(json['isPR']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workoutId': serializer.toJson<String>(workoutId),
      'exerciseId': serializer.toJson<String>(exerciseId),
      'weightKg': serializer.toJson<double>(weightKg),
      'reps': serializer.toJson<int>(reps),
      'done': serializer.toJson<bool>(done),
      'isPR': serializer.toJson<bool>(isPR),
      'position': serializer.toJson<int>(position),
    };
  }

  SetLogRow copyWith({
    String? id,
    String? workoutId,
    String? exerciseId,
    double? weightKg,
    int? reps,
    bool? done,
    bool? isPR,
    int? position,
  }) => SetLogRow(
    id: id ?? this.id,
    workoutId: workoutId ?? this.workoutId,
    exerciseId: exerciseId ?? this.exerciseId,
    weightKg: weightKg ?? this.weightKg,
    reps: reps ?? this.reps,
    done: done ?? this.done,
    isPR: isPR ?? this.isPR,
    position: position ?? this.position,
  );
  SetLogRow copyWithCompanion(SetLogsCompanion data) {
    return SetLogRow(
      id: data.id.present ? data.id.value : this.id,
      workoutId: data.workoutId.present ? data.workoutId.value : this.workoutId,
      exerciseId: data.exerciseId.present
          ? data.exerciseId.value
          : this.exerciseId,
      weightKg: data.weightKg.present ? data.weightKg.value : this.weightKg,
      reps: data.reps.present ? data.reps.value : this.reps,
      done: data.done.present ? data.done.value : this.done,
      isPR: data.isPR.present ? data.isPR.value : this.isPR,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SetLogRow(')
          ..write('id: $id, ')
          ..write('workoutId: $workoutId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('weightKg: $weightKg, ')
          ..write('reps: $reps, ')
          ..write('done: $done, ')
          ..write('isPR: $isPR, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    workoutId,
    exerciseId,
    weightKg,
    reps,
    done,
    isPR,
    position,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SetLogRow &&
          other.id == this.id &&
          other.workoutId == this.workoutId &&
          other.exerciseId == this.exerciseId &&
          other.weightKg == this.weightKg &&
          other.reps == this.reps &&
          other.done == this.done &&
          other.isPR == this.isPR &&
          other.position == this.position);
}

class SetLogsCompanion extends UpdateCompanion<SetLogRow> {
  final Value<String> id;
  final Value<String> workoutId;
  final Value<String> exerciseId;
  final Value<double> weightKg;
  final Value<int> reps;
  final Value<bool> done;
  final Value<bool> isPR;
  final Value<int> position;
  final Value<int> rowid;
  const SetLogsCompanion({
    this.id = const Value.absent(),
    this.workoutId = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.weightKg = const Value.absent(),
    this.reps = const Value.absent(),
    this.done = const Value.absent(),
    this.isPR = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SetLogsCompanion.insert({
    required String id,
    required String workoutId,
    required String exerciseId,
    required double weightKg,
    required int reps,
    this.done = const Value.absent(),
    this.isPR = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       workoutId = Value(workoutId),
       exerciseId = Value(exerciseId),
       weightKg = Value(weightKg),
       reps = Value(reps);
  static Insertable<SetLogRow> custom({
    Expression<String>? id,
    Expression<String>? workoutId,
    Expression<String>? exerciseId,
    Expression<double>? weightKg,
    Expression<int>? reps,
    Expression<bool>? done,
    Expression<bool>? isPR,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workoutId != null) 'workout_id': workoutId,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (weightKg != null) 'weight_kg': weightKg,
      if (reps != null) 'reps': reps,
      if (done != null) 'done': done,
      if (isPR != null) 'is_p_r': isPR,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SetLogsCompanion copyWith({
    Value<String>? id,
    Value<String>? workoutId,
    Value<String>? exerciseId,
    Value<double>? weightKg,
    Value<int>? reps,
    Value<bool>? done,
    Value<bool>? isPR,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return SetLogsCompanion(
      id: id ?? this.id,
      workoutId: workoutId ?? this.workoutId,
      exerciseId: exerciseId ?? this.exerciseId,
      weightKg: weightKg ?? this.weightKg,
      reps: reps ?? this.reps,
      done: done ?? this.done,
      isPR: isPR ?? this.isPR,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workoutId.present) {
      map['workout_id'] = Variable<String>(workoutId.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<String>(exerciseId.value);
    }
    if (weightKg.present) {
      map['weight_kg'] = Variable<double>(weightKg.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (done.present) {
      map['done'] = Variable<bool>(done.value);
    }
    if (isPR.present) {
      map['is_p_r'] = Variable<bool>(isPR.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SetLogsCompanion(')
          ..write('id: $id, ')
          ..write('workoutId: $workoutId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('weightKg: $weightKg, ')
          ..write('reps: $reps, ')
          ..write('done: $done, ')
          ..write('isPR: $isPR, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RitualRoutinesTable extends RitualRoutines
    with TableInfo<$RitualRoutinesTable, RitualRoutineRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RitualRoutinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<String> time = GeneratedColumn<String>(
    'time',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _toneMeta = const VerificationMeta('tone');
  @override
  late final GeneratedColumn<String> tone = GeneratedColumn<String>(
    'tone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _blurbMeta = const VerificationMeta('blurb');
  @override
  late final GeneratedColumn<String> blurb = GeneratedColumn<String>(
    'blurb',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _streakMeta = const VerificationMeta('streak');
  @override
  late final GeneratedColumn<int> streak = GeneratedColumn<int>(
    'streak',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    time,
    tone,
    icon,
    blurb,
    streak,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ritual_routines';
  @override
  VerificationContext validateIntegrity(
    Insertable<RitualRoutineRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('time')) {
      context.handle(
        _timeMeta,
        time.isAcceptableOrUnknown(data['time']!, _timeMeta),
      );
    }
    if (data.containsKey('tone')) {
      context.handle(
        _toneMeta,
        tone.isAcceptableOrUnknown(data['tone']!, _toneMeta),
      );
    } else if (isInserting) {
      context.missing(_toneMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    } else if (isInserting) {
      context.missing(_iconMeta);
    }
    if (data.containsKey('blurb')) {
      context.handle(
        _blurbMeta,
        blurb.isAcceptableOrUnknown(data['blurb']!, _blurbMeta),
      );
    }
    if (data.containsKey('streak')) {
      context.handle(
        _streakMeta,
        streak.isAcceptableOrUnknown(data['streak']!, _streakMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RitualRoutineRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RitualRoutineRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      time: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time'],
      )!,
      tone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tone'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      )!,
      blurb: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}blurb'],
      )!,
      streak: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}streak'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $RitualRoutinesTable createAlias(String alias) {
    return $RitualRoutinesTable(attachedDatabase, alias);
  }
}

class RitualRoutineRow extends DataClass
    implements Insertable<RitualRoutineRow> {
  final String id;
  final String name;

  /// Human display time, e.g. "7:00 AM".
  final String time;

  /// [RitualTone.wire].
  final String tone;
  final String icon;
  final String blurb;
  final int streak;

  /// `RitualRoutine.order` (renamed; `order` is a SQL keyword).
  final int position;
  const RitualRoutineRow({
    required this.id,
    required this.name,
    required this.time,
    required this.tone,
    required this.icon,
    required this.blurb,
    required this.streak,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['time'] = Variable<String>(time);
    map['tone'] = Variable<String>(tone);
    map['icon'] = Variable<String>(icon);
    map['blurb'] = Variable<String>(blurb);
    map['streak'] = Variable<int>(streak);
    map['position'] = Variable<int>(position);
    return map;
  }

  RitualRoutinesCompanion toCompanion(bool nullToAbsent) {
    return RitualRoutinesCompanion(
      id: Value(id),
      name: Value(name),
      time: Value(time),
      tone: Value(tone),
      icon: Value(icon),
      blurb: Value(blurb),
      streak: Value(streak),
      position: Value(position),
    );
  }

  factory RitualRoutineRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RitualRoutineRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      time: serializer.fromJson<String>(json['time']),
      tone: serializer.fromJson<String>(json['tone']),
      icon: serializer.fromJson<String>(json['icon']),
      blurb: serializer.fromJson<String>(json['blurb']),
      streak: serializer.fromJson<int>(json['streak']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'time': serializer.toJson<String>(time),
      'tone': serializer.toJson<String>(tone),
      'icon': serializer.toJson<String>(icon),
      'blurb': serializer.toJson<String>(blurb),
      'streak': serializer.toJson<int>(streak),
      'position': serializer.toJson<int>(position),
    };
  }

  RitualRoutineRow copyWith({
    String? id,
    String? name,
    String? time,
    String? tone,
    String? icon,
    String? blurb,
    int? streak,
    int? position,
  }) => RitualRoutineRow(
    id: id ?? this.id,
    name: name ?? this.name,
    time: time ?? this.time,
    tone: tone ?? this.tone,
    icon: icon ?? this.icon,
    blurb: blurb ?? this.blurb,
    streak: streak ?? this.streak,
    position: position ?? this.position,
  );
  RitualRoutineRow copyWithCompanion(RitualRoutinesCompanion data) {
    return RitualRoutineRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      time: data.time.present ? data.time.value : this.time,
      tone: data.tone.present ? data.tone.value : this.tone,
      icon: data.icon.present ? data.icon.value : this.icon,
      blurb: data.blurb.present ? data.blurb.value : this.blurb,
      streak: data.streak.present ? data.streak.value : this.streak,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RitualRoutineRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('time: $time, ')
          ..write('tone: $tone, ')
          ..write('icon: $icon, ')
          ..write('blurb: $blurb, ')
          ..write('streak: $streak, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, time, tone, icon, blurb, streak, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RitualRoutineRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.time == this.time &&
          other.tone == this.tone &&
          other.icon == this.icon &&
          other.blurb == this.blurb &&
          other.streak == this.streak &&
          other.position == this.position);
}

class RitualRoutinesCompanion extends UpdateCompanion<RitualRoutineRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> time;
  final Value<String> tone;
  final Value<String> icon;
  final Value<String> blurb;
  final Value<int> streak;
  final Value<int> position;
  final Value<int> rowid;
  const RitualRoutinesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.time = const Value.absent(),
    this.tone = const Value.absent(),
    this.icon = const Value.absent(),
    this.blurb = const Value.absent(),
    this.streak = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RitualRoutinesCompanion.insert({
    required String id,
    required String name,
    this.time = const Value.absent(),
    required String tone,
    required String icon,
    this.blurb = const Value.absent(),
    this.streak = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       tone = Value(tone),
       icon = Value(icon);
  static Insertable<RitualRoutineRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? time,
    Expression<String>? tone,
    Expression<String>? icon,
    Expression<String>? blurb,
    Expression<int>? streak,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (time != null) 'time': time,
      if (tone != null) 'tone': tone,
      if (icon != null) 'icon': icon,
      if (blurb != null) 'blurb': blurb,
      if (streak != null) 'streak': streak,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RitualRoutinesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? time,
    Value<String>? tone,
    Value<String>? icon,
    Value<String>? blurb,
    Value<int>? streak,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return RitualRoutinesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      time: time ?? this.time,
      tone: tone ?? this.tone,
      icon: icon ?? this.icon,
      blurb: blurb ?? this.blurb,
      streak: streak ?? this.streak,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (time.present) {
      map['time'] = Variable<String>(time.value);
    }
    if (tone.present) {
      map['tone'] = Variable<String>(tone.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (blurb.present) {
      map['blurb'] = Variable<String>(blurb.value);
    }
    if (streak.present) {
      map['streak'] = Variable<int>(streak.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RitualRoutinesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('time: $time, ')
          ..write('tone: $tone, ')
          ..write('icon: $icon, ')
          ..write('blurb: $blurb, ')
          ..write('streak: $streak, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RitualStepsTable extends RitualSteps
    with TableInfo<$RitualStepsTable, RitualStepRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RitualStepsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _routineIdMeta = const VerificationMeta(
    'routineId',
  );
  @override
  late final GeneratedColumn<String> routineId = GeneratedColumn<String>(
    'routine_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    routineId,
    title,
    note,
    icon,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ritual_steps';
  @override
  VerificationContext validateIntegrity(
    Insertable<RitualStepRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('routine_id')) {
      context.handle(
        _routineIdMeta,
        routineId.isAcceptableOrUnknown(data['routine_id']!, _routineIdMeta),
      );
    } else if (isInserting) {
      context.missing(_routineIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    } else if (isInserting) {
      context.missing(_iconMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RitualStepRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RitualStepRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      routineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}routine_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $RitualStepsTable createAlias(String alias) {
    return $RitualStepsTable(attachedDatabase, alias);
  }
}

class RitualStepRow extends DataClass implements Insertable<RitualStepRow> {
  final String id;
  final String routineId;
  final String title;
  final String note;
  final String icon;

  /// `RitualStep` ordering (renamed; `order` is a SQL keyword).
  final int position;
  const RitualStepRow({
    required this.id,
    required this.routineId,
    required this.title,
    required this.note,
    required this.icon,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['routine_id'] = Variable<String>(routineId);
    map['title'] = Variable<String>(title);
    map['note'] = Variable<String>(note);
    map['icon'] = Variable<String>(icon);
    map['position'] = Variable<int>(position);
    return map;
  }

  RitualStepsCompanion toCompanion(bool nullToAbsent) {
    return RitualStepsCompanion(
      id: Value(id),
      routineId: Value(routineId),
      title: Value(title),
      note: Value(note),
      icon: Value(icon),
      position: Value(position),
    );
  }

  factory RitualStepRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RitualStepRow(
      id: serializer.fromJson<String>(json['id']),
      routineId: serializer.fromJson<String>(json['routineId']),
      title: serializer.fromJson<String>(json['title']),
      note: serializer.fromJson<String>(json['note']),
      icon: serializer.fromJson<String>(json['icon']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'routineId': serializer.toJson<String>(routineId),
      'title': serializer.toJson<String>(title),
      'note': serializer.toJson<String>(note),
      'icon': serializer.toJson<String>(icon),
      'position': serializer.toJson<int>(position),
    };
  }

  RitualStepRow copyWith({
    String? id,
    String? routineId,
    String? title,
    String? note,
    String? icon,
    int? position,
  }) => RitualStepRow(
    id: id ?? this.id,
    routineId: routineId ?? this.routineId,
    title: title ?? this.title,
    note: note ?? this.note,
    icon: icon ?? this.icon,
    position: position ?? this.position,
  );
  RitualStepRow copyWithCompanion(RitualStepsCompanion data) {
    return RitualStepRow(
      id: data.id.present ? data.id.value : this.id,
      routineId: data.routineId.present ? data.routineId.value : this.routineId,
      title: data.title.present ? data.title.value : this.title,
      note: data.note.present ? data.note.value : this.note,
      icon: data.icon.present ? data.icon.value : this.icon,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RitualStepRow(')
          ..write('id: $id, ')
          ..write('routineId: $routineId, ')
          ..write('title: $title, ')
          ..write('note: $note, ')
          ..write('icon: $icon, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, routineId, title, note, icon, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RitualStepRow &&
          other.id == this.id &&
          other.routineId == this.routineId &&
          other.title == this.title &&
          other.note == this.note &&
          other.icon == this.icon &&
          other.position == this.position);
}

class RitualStepsCompanion extends UpdateCompanion<RitualStepRow> {
  final Value<String> id;
  final Value<String> routineId;
  final Value<String> title;
  final Value<String> note;
  final Value<String> icon;
  final Value<int> position;
  final Value<int> rowid;
  const RitualStepsCompanion({
    this.id = const Value.absent(),
    this.routineId = const Value.absent(),
    this.title = const Value.absent(),
    this.note = const Value.absent(),
    this.icon = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RitualStepsCompanion.insert({
    required String id,
    required String routineId,
    required String title,
    this.note = const Value.absent(),
    required String icon,
    required int position,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       routineId = Value(routineId),
       title = Value(title),
       icon = Value(icon),
       position = Value(position);
  static Insertable<RitualStepRow> custom({
    Expression<String>? id,
    Expression<String>? routineId,
    Expression<String>? title,
    Expression<String>? note,
    Expression<String>? icon,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (routineId != null) 'routine_id': routineId,
      if (title != null) 'title': title,
      if (note != null) 'note': note,
      if (icon != null) 'icon': icon,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RitualStepsCompanion copyWith({
    Value<String>? id,
    Value<String>? routineId,
    Value<String>? title,
    Value<String>? note,
    Value<String>? icon,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return RitualStepsCompanion(
      id: id ?? this.id,
      routineId: routineId ?? this.routineId,
      title: title ?? this.title,
      note: note ?? this.note,
      icon: icon ?? this.icon,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (routineId.present) {
      map['routine_id'] = Variable<String>(routineId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RitualStepsCompanion(')
          ..write('id: $id, ')
          ..write('routineId: $routineId, ')
          ..write('title: $title, ')
          ..write('note: $note, ')
          ..write('icon: $icon, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PalNotesTable extends PalNotes
    with TableInfo<$PalNotesTable, PalNoteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PalNotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionLabelMeta = const VerificationMeta(
    'actionLabel',
  );
  @override
  late final GeneratedColumn<String> actionLabel = GeneratedColumn<String>(
    'action_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unreadMeta = const VerificationMeta('unread');
  @override
  late final GeneratedColumn<bool> unread = GeneratedColumn<bool>(
    'unread',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("unread" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    kind,
    category,
    icon,
    title,
    body,
    actionLabel,
    unread,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pal_notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<PalNoteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    } else if (isInserting) {
      context.missing(_iconMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('action_label')) {
      context.handle(
        _actionLabelMeta,
        actionLabel.isAcceptableOrUnknown(
          data['action_label']!,
          _actionLabelMeta,
        ),
      );
    }
    if (data.containsKey('unread')) {
      context.handle(
        _unreadMeta,
        unread.isAcceptableOrUnknown(data['unread']!, _unreadMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PalNoteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PalNoteRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      actionLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action_label'],
      ),
      unread: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}unread'],
      )!,
    );
  }

  @override
  $PalNotesTable createAlias(String alias) {
    return $PalNotesTable(attachedDatabase, alias);
  }
}

class PalNoteRow extends DataClass implements Insertable<PalNoteRow> {
  final String id;
  final DateTime createdAt;

  /// [NoteKind.wire].
  final String kind;

  /// [EntryType.wire] of the category dot.
  final String category;
  final String icon;
  final String title;
  final String body;
  final String? actionLabel;
  final bool unread;
  const PalNoteRow({
    required this.id,
    required this.createdAt,
    required this.kind,
    required this.category,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    required this.unread,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['kind'] = Variable<String>(kind);
    map['category'] = Variable<String>(category);
    map['icon'] = Variable<String>(icon);
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    if (!nullToAbsent || actionLabel != null) {
      map['action_label'] = Variable<String>(actionLabel);
    }
    map['unread'] = Variable<bool>(unread);
    return map;
  }

  PalNotesCompanion toCompanion(bool nullToAbsent) {
    return PalNotesCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      kind: Value(kind),
      category: Value(category),
      icon: Value(icon),
      title: Value(title),
      body: Value(body),
      actionLabel: actionLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(actionLabel),
      unread: Value(unread),
    );
  }

  factory PalNoteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PalNoteRow(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      kind: serializer.fromJson<String>(json['kind']),
      category: serializer.fromJson<String>(json['category']),
      icon: serializer.fromJson<String>(json['icon']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      actionLabel: serializer.fromJson<String?>(json['actionLabel']),
      unread: serializer.fromJson<bool>(json['unread']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'kind': serializer.toJson<String>(kind),
      'category': serializer.toJson<String>(category),
      'icon': serializer.toJson<String>(icon),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'actionLabel': serializer.toJson<String?>(actionLabel),
      'unread': serializer.toJson<bool>(unread),
    };
  }

  PalNoteRow copyWith({
    String? id,
    DateTime? createdAt,
    String? kind,
    String? category,
    String? icon,
    String? title,
    String? body,
    Value<String?> actionLabel = const Value.absent(),
    bool? unread,
  }) => PalNoteRow(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    kind: kind ?? this.kind,
    category: category ?? this.category,
    icon: icon ?? this.icon,
    title: title ?? this.title,
    body: body ?? this.body,
    actionLabel: actionLabel.present ? actionLabel.value : this.actionLabel,
    unread: unread ?? this.unread,
  );
  PalNoteRow copyWithCompanion(PalNotesCompanion data) {
    return PalNoteRow(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      kind: data.kind.present ? data.kind.value : this.kind,
      category: data.category.present ? data.category.value : this.category,
      icon: data.icon.present ? data.icon.value : this.icon,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      actionLabel: data.actionLabel.present
          ? data.actionLabel.value
          : this.actionLabel,
      unread: data.unread.present ? data.unread.value : this.unread,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PalNoteRow(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('kind: $kind, ')
          ..write('category: $category, ')
          ..write('icon: $icon, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('actionLabel: $actionLabel, ')
          ..write('unread: $unread')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    kind,
    category,
    icon,
    title,
    body,
    actionLabel,
    unread,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PalNoteRow &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.kind == this.kind &&
          other.category == this.category &&
          other.icon == this.icon &&
          other.title == this.title &&
          other.body == this.body &&
          other.actionLabel == this.actionLabel &&
          other.unread == this.unread);
}

class PalNotesCompanion extends UpdateCompanion<PalNoteRow> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<String> kind;
  final Value<String> category;
  final Value<String> icon;
  final Value<String> title;
  final Value<String> body;
  final Value<String?> actionLabel;
  final Value<bool> unread;
  final Value<int> rowid;
  const PalNotesCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.kind = const Value.absent(),
    this.category = const Value.absent(),
    this.icon = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.actionLabel = const Value.absent(),
    this.unread = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PalNotesCompanion.insert({
    required String id,
    required DateTime createdAt,
    required String kind,
    required String category,
    required String icon,
    required String title,
    required String body,
    this.actionLabel = const Value.absent(),
    this.unread = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       kind = Value(kind),
       category = Value(category),
       icon = Value(icon),
       title = Value(title),
       body = Value(body);
  static Insertable<PalNoteRow> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<String>? kind,
    Expression<String>? category,
    Expression<String>? icon,
    Expression<String>? title,
    Expression<String>? body,
    Expression<String>? actionLabel,
    Expression<bool>? unread,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (kind != null) 'kind': kind,
      if (category != null) 'category': category,
      if (icon != null) 'icon': icon,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (actionLabel != null) 'action_label': actionLabel,
      if (unread != null) 'unread': unread,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PalNotesCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<String>? kind,
    Value<String>? category,
    Value<String>? icon,
    Value<String>? title,
    Value<String>? body,
    Value<String?>? actionLabel,
    Value<bool>? unread,
    Value<int>? rowid,
  }) {
    return PalNotesCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      kind: kind ?? this.kind,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      title: title ?? this.title,
      body: body ?? this.body,
      actionLabel: actionLabel ?? this.actionLabel,
      unread: unread ?? this.unread,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (actionLabel.present) {
      map['action_label'] = Variable<String>(actionLabel.value);
    }
    if (unread.present) {
      map['unread'] = Variable<bool>(unread.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PalNotesCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('kind: $kind, ')
          ..write('category: $category, ')
          ..write('icon: $icon, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('actionLabel: $actionLabel, ')
          ..write('unread: $unread, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GoalsTableTable extends GoalsTable
    with TableInfo<$GoalsTableTable, GoalsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GoalsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('goals'),
  );
  static const VerificationMeta _dailyBudgetMeta = const VerificationMeta(
    'dailyBudget',
  );
  @override
  late final GeneratedColumn<double> dailyBudget = GeneratedColumn<double>(
    'daily_budget',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(85.0),
  );
  static const VerificationMeta _dailyMoveKcalMeta = const VerificationMeta(
    'dailyMoveKcal',
  );
  @override
  late final GeneratedColumn<int> dailyMoveKcal = GeneratedColumn<int>(
    'daily_move_kcal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(500),
  );
  static const VerificationMeta _dailyRitualTargetMeta = const VerificationMeta(
    'dailyRitualTarget',
  );
  @override
  late final GeneratedColumn<int> dailyRitualTarget = GeneratedColumn<int>(
    'daily_ritual_target',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(5),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    dailyBudget,
    dailyMoveKcal,
    dailyRitualTarget,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'goals';
  @override
  VerificationContext validateIntegrity(
    Insertable<GoalsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('daily_budget')) {
      context.handle(
        _dailyBudgetMeta,
        dailyBudget.isAcceptableOrUnknown(
          data['daily_budget']!,
          _dailyBudgetMeta,
        ),
      );
    }
    if (data.containsKey('daily_move_kcal')) {
      context.handle(
        _dailyMoveKcalMeta,
        dailyMoveKcal.isAcceptableOrUnknown(
          data['daily_move_kcal']!,
          _dailyMoveKcalMeta,
        ),
      );
    }
    if (data.containsKey('daily_ritual_target')) {
      context.handle(
        _dailyRitualTargetMeta,
        dailyRitualTarget.isAcceptableOrUnknown(
          data['daily_ritual_target']!,
          _dailyRitualTargetMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GoalsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GoalsRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      dailyBudget: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}daily_budget'],
      )!,
      dailyMoveKcal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}daily_move_kcal'],
      )!,
      dailyRitualTarget: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}daily_ritual_target'],
      )!,
    );
  }

  @override
  $GoalsTableTable createAlias(String alias) {
    return $GoalsTableTable(attachedDatabase, alias);
  }
}

class GoalsRow extends DataClass implements Insertable<GoalsRow> {
  /// Fixed single-row key (literal must match [singletonId]).
  final String id;
  final double dailyBudget;
  final int dailyMoveKcal;
  final int dailyRitualTarget;
  const GoalsRow({
    required this.id,
    required this.dailyBudget,
    required this.dailyMoveKcal,
    required this.dailyRitualTarget,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['daily_budget'] = Variable<double>(dailyBudget);
    map['daily_move_kcal'] = Variable<int>(dailyMoveKcal);
    map['daily_ritual_target'] = Variable<int>(dailyRitualTarget);
    return map;
  }

  GoalsTableCompanion toCompanion(bool nullToAbsent) {
    return GoalsTableCompanion(
      id: Value(id),
      dailyBudget: Value(dailyBudget),
      dailyMoveKcal: Value(dailyMoveKcal),
      dailyRitualTarget: Value(dailyRitualTarget),
    );
  }

  factory GoalsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GoalsRow(
      id: serializer.fromJson<String>(json['id']),
      dailyBudget: serializer.fromJson<double>(json['dailyBudget']),
      dailyMoveKcal: serializer.fromJson<int>(json['dailyMoveKcal']),
      dailyRitualTarget: serializer.fromJson<int>(json['dailyRitualTarget']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'dailyBudget': serializer.toJson<double>(dailyBudget),
      'dailyMoveKcal': serializer.toJson<int>(dailyMoveKcal),
      'dailyRitualTarget': serializer.toJson<int>(dailyRitualTarget),
    };
  }

  GoalsRow copyWith({
    String? id,
    double? dailyBudget,
    int? dailyMoveKcal,
    int? dailyRitualTarget,
  }) => GoalsRow(
    id: id ?? this.id,
    dailyBudget: dailyBudget ?? this.dailyBudget,
    dailyMoveKcal: dailyMoveKcal ?? this.dailyMoveKcal,
    dailyRitualTarget: dailyRitualTarget ?? this.dailyRitualTarget,
  );
  GoalsRow copyWithCompanion(GoalsTableCompanion data) {
    return GoalsRow(
      id: data.id.present ? data.id.value : this.id,
      dailyBudget: data.dailyBudget.present
          ? data.dailyBudget.value
          : this.dailyBudget,
      dailyMoveKcal: data.dailyMoveKcal.present
          ? data.dailyMoveKcal.value
          : this.dailyMoveKcal,
      dailyRitualTarget: data.dailyRitualTarget.present
          ? data.dailyRitualTarget.value
          : this.dailyRitualTarget,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GoalsRow(')
          ..write('id: $id, ')
          ..write('dailyBudget: $dailyBudget, ')
          ..write('dailyMoveKcal: $dailyMoveKcal, ')
          ..write('dailyRitualTarget: $dailyRitualTarget')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, dailyBudget, dailyMoveKcal, dailyRitualTarget);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GoalsRow &&
          other.id == this.id &&
          other.dailyBudget == this.dailyBudget &&
          other.dailyMoveKcal == this.dailyMoveKcal &&
          other.dailyRitualTarget == this.dailyRitualTarget);
}

class GoalsTableCompanion extends UpdateCompanion<GoalsRow> {
  final Value<String> id;
  final Value<double> dailyBudget;
  final Value<int> dailyMoveKcal;
  final Value<int> dailyRitualTarget;
  final Value<int> rowid;
  const GoalsTableCompanion({
    this.id = const Value.absent(),
    this.dailyBudget = const Value.absent(),
    this.dailyMoveKcal = const Value.absent(),
    this.dailyRitualTarget = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GoalsTableCompanion.insert({
    this.id = const Value.absent(),
    this.dailyBudget = const Value.absent(),
    this.dailyMoveKcal = const Value.absent(),
    this.dailyRitualTarget = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  static Insertable<GoalsRow> custom({
    Expression<String>? id,
    Expression<double>? dailyBudget,
    Expression<int>? dailyMoveKcal,
    Expression<int>? dailyRitualTarget,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dailyBudget != null) 'daily_budget': dailyBudget,
      if (dailyMoveKcal != null) 'daily_move_kcal': dailyMoveKcal,
      if (dailyRitualTarget != null) 'daily_ritual_target': dailyRitualTarget,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GoalsTableCompanion copyWith({
    Value<String>? id,
    Value<double>? dailyBudget,
    Value<int>? dailyMoveKcal,
    Value<int>? dailyRitualTarget,
    Value<int>? rowid,
  }) {
    return GoalsTableCompanion(
      id: id ?? this.id,
      dailyBudget: dailyBudget ?? this.dailyBudget,
      dailyMoveKcal: dailyMoveKcal ?? this.dailyMoveKcal,
      dailyRitualTarget: dailyRitualTarget ?? this.dailyRitualTarget,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (dailyBudget.present) {
      map['daily_budget'] = Variable<double>(dailyBudget.value);
    }
    if (dailyMoveKcal.present) {
      map['daily_move_kcal'] = Variable<int>(dailyMoveKcal.value);
    }
    if (dailyRitualTarget.present) {
      map['daily_ritual_target'] = Variable<int>(dailyRitualTarget.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GoalsTableCompanion(')
          ..write('id: $id, ')
          ..write('dailyBudget: $dailyBudget, ')
          ..write('dailyMoveKcal: $dailyMoveKcal, ')
          ..write('dailyRitualTarget: $dailyRitualTarget, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SeedMarkersTable extends SeedMarkers
    with TableInfo<$SeedMarkersTable, SeedMarker> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SeedMarkersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'seed_markers';
  @override
  VerificationContext validateIntegrity(
    Insertable<SeedMarker> instance, {
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SeedMarker map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SeedMarker(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
    );
  }

  @override
  $SeedMarkersTable createAlias(String alias) {
    return $SeedMarkersTable(attachedDatabase, alias);
  }
}

class SeedMarker extends DataClass implements Insertable<SeedMarker> {
  final String key;
  const SeedMarker({required this.key});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    return map;
  }

  SeedMarkersCompanion toCompanion(bool nullToAbsent) {
    return SeedMarkersCompanion(key: Value(key));
  }

  factory SeedMarker.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SeedMarker(key: serializer.fromJson<String>(json['key']));
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{'key': serializer.toJson<String>(key)};
  }

  SeedMarker copyWith({String? key}) => SeedMarker(key: key ?? this.key);
  SeedMarker copyWithCompanion(SeedMarkersCompanion data) {
    return SeedMarker(key: data.key.present ? data.key.value : this.key);
  }

  @override
  String toString() {
    return (StringBuffer('SeedMarker(')
          ..write('key: $key')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => key.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is SeedMarker && other.key == this.key);
}

class SeedMarkersCompanion extends UpdateCompanion<SeedMarker> {
  final Value<String> key;
  final Value<int> rowid;
  const SeedMarkersCompanion({
    this.key = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SeedMarkersCompanion.insert({
    required String key,
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<SeedMarker> custom({
    Expression<String>? key,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SeedMarkersCompanion copyWith({Value<String>? key, Value<int>? rowid}) {
    return SeedMarkersCompanion(
      key: key ?? this.key,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SeedMarkersCompanion(')
          ..write('key: $key, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WeeklyPlanDaysTable extends WeeklyPlanDays
    with TableInfo<$WeeklyPlanDaysTable, WeeklyPlanDayRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WeeklyPlanDaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _weekdayMeta = const VerificationMeta(
    'weekday',
  );
  @override
  late final GeneratedColumn<int> weekday = GeneratedColumn<int>(
    'weekday',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _routineIdMeta = const VerificationMeta(
    'routineId',
  );
  @override
  late final GeneratedColumn<String> routineId = GeneratedColumn<String>(
    'routine_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [weekday, routineId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'weekly_plan_days';
  @override
  VerificationContext validateIntegrity(
    Insertable<WeeklyPlanDayRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('weekday')) {
      context.handle(
        _weekdayMeta,
        weekday.isAcceptableOrUnknown(data['weekday']!, _weekdayMeta),
      );
    }
    if (data.containsKey('routine_id')) {
      context.handle(
        _routineIdMeta,
        routineId.isAcceptableOrUnknown(data['routine_id']!, _routineIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {weekday};
  @override
  WeeklyPlanDayRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WeeklyPlanDayRow(
      weekday: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}weekday'],
      )!,
      routineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}routine_id'],
      ),
    );
  }

  @override
  $WeeklyPlanDaysTable createAlias(String alias) {
    return $WeeklyPlanDaysTable(attachedDatabase, alias);
  }
}

class WeeklyPlanDayRow extends DataClass
    implements Insertable<WeeklyPlanDayRow> {
  /// ISO weekday: 1=Mon .. 7=Sun (also the primary key).
  final int weekday;

  /// FK to [Routines.id]; null = Rest day.
  final String? routineId;
  const WeeklyPlanDayRow({required this.weekday, this.routineId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['weekday'] = Variable<int>(weekday);
    if (!nullToAbsent || routineId != null) {
      map['routine_id'] = Variable<String>(routineId);
    }
    return map;
  }

  WeeklyPlanDaysCompanion toCompanion(bool nullToAbsent) {
    return WeeklyPlanDaysCompanion(
      weekday: Value(weekday),
      routineId: routineId == null && nullToAbsent
          ? const Value.absent()
          : Value(routineId),
    );
  }

  factory WeeklyPlanDayRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WeeklyPlanDayRow(
      weekday: serializer.fromJson<int>(json['weekday']),
      routineId: serializer.fromJson<String?>(json['routineId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'weekday': serializer.toJson<int>(weekday),
      'routineId': serializer.toJson<String?>(routineId),
    };
  }

  WeeklyPlanDayRow copyWith({
    int? weekday,
    Value<String?> routineId = const Value.absent(),
  }) => WeeklyPlanDayRow(
    weekday: weekday ?? this.weekday,
    routineId: routineId.present ? routineId.value : this.routineId,
  );
  WeeklyPlanDayRow copyWithCompanion(WeeklyPlanDaysCompanion data) {
    return WeeklyPlanDayRow(
      weekday: data.weekday.present ? data.weekday.value : this.weekday,
      routineId: data.routineId.present ? data.routineId.value : this.routineId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WeeklyPlanDayRow(')
          ..write('weekday: $weekday, ')
          ..write('routineId: $routineId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(weekday, routineId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WeeklyPlanDayRow &&
          other.weekday == this.weekday &&
          other.routineId == this.routineId);
}

class WeeklyPlanDaysCompanion extends UpdateCompanion<WeeklyPlanDayRow> {
  final Value<int> weekday;
  final Value<String?> routineId;
  const WeeklyPlanDaysCompanion({
    this.weekday = const Value.absent(),
    this.routineId = const Value.absent(),
  });
  WeeklyPlanDaysCompanion.insert({
    this.weekday = const Value.absent(),
    this.routineId = const Value.absent(),
  });
  static Insertable<WeeklyPlanDayRow> custom({
    Expression<int>? weekday,
    Expression<String>? routineId,
  }) {
    return RawValuesInsertable({
      if (weekday != null) 'weekday': weekday,
      if (routineId != null) 'routine_id': routineId,
    });
  }

  WeeklyPlanDaysCompanion copyWith({
    Value<int>? weekday,
    Value<String?>? routineId,
  }) {
    return WeeklyPlanDaysCompanion(
      weekday: weekday ?? this.weekday,
      routineId: routineId ?? this.routineId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (weekday.present) {
      map['weekday'] = Variable<int>(weekday.value);
    }
    if (routineId.present) {
      map['routine_id'] = Variable<String>(routineId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WeeklyPlanDaysCompanion(')
          ..write('weekday: $weekday, ')
          ..write('routineId: $routineId')
          ..write(')'))
        .toString();
  }
}

class $BudgetEnvelopesTable extends BudgetEnvelopes
    with TableInfo<$BudgetEnvelopesTable, BudgetEnvelopeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BudgetEnvelopesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _capMeta = const VerificationMeta('cap');
  @override
  late final GeneratedColumn<double> cap = GeneratedColumn<double>(
    'cap',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorTokenMeta = const VerificationMeta(
    'colorToken',
  );
  @override
  late final GeneratedColumn<String> colorToken = GeneratedColumn<String>(
    'color_token',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    category,
    cap,
    icon,
    colorToken,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'budget_envelopes';
  @override
  VerificationContext validateIntegrity(
    Insertable<BudgetEnvelopeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('cap')) {
      context.handle(
        _capMeta,
        cap.isAcceptableOrUnknown(data['cap']!, _capMeta),
      );
    } else if (isInserting) {
      context.missing(_capMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    } else if (isInserting) {
      context.missing(_iconMeta);
    }
    if (data.containsKey('color_token')) {
      context.handle(
        _colorTokenMeta,
        colorToken.isAcceptableOrUnknown(data['color_token']!, _colorTokenMeta),
      );
    } else if (isInserting) {
      context.missing(_colorTokenMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BudgetEnvelopeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BudgetEnvelopeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      cap: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cap'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      )!,
      colorToken: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_token'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $BudgetEnvelopesTable createAlias(String alias) {
    return $BudgetEnvelopesTable(attachedDatabase, alias);
  }
}

class BudgetEnvelopeRow extends DataClass
    implements Insertable<BudgetEnvelopeRow> {
  final String id;
  final String category;
  final double cap;
  final String icon;
  final String colorToken;
  final int position;
  const BudgetEnvelopeRow({
    required this.id,
    required this.category,
    required this.cap,
    required this.icon,
    required this.colorToken,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['category'] = Variable<String>(category);
    map['cap'] = Variable<double>(cap);
    map['icon'] = Variable<String>(icon);
    map['color_token'] = Variable<String>(colorToken);
    map['position'] = Variable<int>(position);
    return map;
  }

  BudgetEnvelopesCompanion toCompanion(bool nullToAbsent) {
    return BudgetEnvelopesCompanion(
      id: Value(id),
      category: Value(category),
      cap: Value(cap),
      icon: Value(icon),
      colorToken: Value(colorToken),
      position: Value(position),
    );
  }

  factory BudgetEnvelopeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BudgetEnvelopeRow(
      id: serializer.fromJson<String>(json['id']),
      category: serializer.fromJson<String>(json['category']),
      cap: serializer.fromJson<double>(json['cap']),
      icon: serializer.fromJson<String>(json['icon']),
      colorToken: serializer.fromJson<String>(json['colorToken']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'category': serializer.toJson<String>(category),
      'cap': serializer.toJson<double>(cap),
      'icon': serializer.toJson<String>(icon),
      'colorToken': serializer.toJson<String>(colorToken),
      'position': serializer.toJson<int>(position),
    };
  }

  BudgetEnvelopeRow copyWith({
    String? id,
    String? category,
    double? cap,
    String? icon,
    String? colorToken,
    int? position,
  }) => BudgetEnvelopeRow(
    id: id ?? this.id,
    category: category ?? this.category,
    cap: cap ?? this.cap,
    icon: icon ?? this.icon,
    colorToken: colorToken ?? this.colorToken,
    position: position ?? this.position,
  );
  BudgetEnvelopeRow copyWithCompanion(BudgetEnvelopesCompanion data) {
    return BudgetEnvelopeRow(
      id: data.id.present ? data.id.value : this.id,
      category: data.category.present ? data.category.value : this.category,
      cap: data.cap.present ? data.cap.value : this.cap,
      icon: data.icon.present ? data.icon.value : this.icon,
      colorToken: data.colorToken.present
          ? data.colorToken.value
          : this.colorToken,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BudgetEnvelopeRow(')
          ..write('id: $id, ')
          ..write('category: $category, ')
          ..write('cap: $cap, ')
          ..write('icon: $icon, ')
          ..write('colorToken: $colorToken, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, category, cap, icon, colorToken, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BudgetEnvelopeRow &&
          other.id == this.id &&
          other.category == this.category &&
          other.cap == this.cap &&
          other.icon == this.icon &&
          other.colorToken == this.colorToken &&
          other.position == this.position);
}

class BudgetEnvelopesCompanion extends UpdateCompanion<BudgetEnvelopeRow> {
  final Value<String> id;
  final Value<String> category;
  final Value<double> cap;
  final Value<String> icon;
  final Value<String> colorToken;
  final Value<int> position;
  final Value<int> rowid;
  const BudgetEnvelopesCompanion({
    this.id = const Value.absent(),
    this.category = const Value.absent(),
    this.cap = const Value.absent(),
    this.icon = const Value.absent(),
    this.colorToken = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BudgetEnvelopesCompanion.insert({
    required String id,
    required String category,
    required double cap,
    required String icon,
    required String colorToken,
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       category = Value(category),
       cap = Value(cap),
       icon = Value(icon),
       colorToken = Value(colorToken);
  static Insertable<BudgetEnvelopeRow> custom({
    Expression<String>? id,
    Expression<String>? category,
    Expression<double>? cap,
    Expression<String>? icon,
    Expression<String>? colorToken,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (category != null) 'category': category,
      if (cap != null) 'cap': cap,
      if (icon != null) 'icon': icon,
      if (colorToken != null) 'color_token': colorToken,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BudgetEnvelopesCompanion copyWith({
    Value<String>? id,
    Value<String>? category,
    Value<double>? cap,
    Value<String>? icon,
    Value<String>? colorToken,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return BudgetEnvelopesCompanion(
      id: id ?? this.id,
      category: category ?? this.category,
      cap: cap ?? this.cap,
      icon: icon ?? this.icon,
      colorToken: colorToken ?? this.colorToken,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (cap.present) {
      map['cap'] = Variable<double>(cap.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (colorToken.present) {
      map['color_token'] = Variable<String>(colorToken.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BudgetEnvelopesCompanion(')
          ..write('id: $id, ')
          ..write('category: $category, ')
          ..write('cap: $cap, ')
          ..write('icon: $icon, ')
          ..write('colorToken: $colorToken, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NutritionMealsTable extends NutritionMeals
    with TableInfo<$NutritionMealsTable, NutritionMealRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NutritionMealsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _slotMeta = const VerificationMeta('slot');
  @override
  late final GeneratedColumn<String> slot = GeneratedColumn<String>(
    'slot',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<String> confidence = GeneratedColumn<String>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _calLoMeta = const VerificationMeta('calLo');
  @override
  late final GeneratedColumn<int> calLo = GeneratedColumn<int>(
    'cal_lo',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _calHiMeta = const VerificationMeta('calHi');
  @override
  late final GeneratedColumn<int> calHi = GeneratedColumn<int>(
    'cal_hi',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _proteinLoMeta = const VerificationMeta(
    'proteinLo',
  );
  @override
  late final GeneratedColumn<int> proteinLo = GeneratedColumn<int>(
    'protein_lo',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _proteinHiMeta = const VerificationMeta(
    'proteinHi',
  );
  @override
  late final GeneratedColumn<int> proteinHi = GeneratedColumn<int>(
    'protein_hi',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _carbsLoMeta = const VerificationMeta(
    'carbsLo',
  );
  @override
  late final GeneratedColumn<int> carbsLo = GeneratedColumn<int>(
    'carbs_lo',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _carbsHiMeta = const VerificationMeta(
    'carbsHi',
  );
  @override
  late final GeneratedColumn<int> carbsHi = GeneratedColumn<int>(
    'carbs_hi',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fatLoMeta = const VerificationMeta('fatLo');
  @override
  late final GeneratedColumn<int> fatLo = GeneratedColumn<int>(
    'fat_lo',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fatHiMeta = const VerificationMeta('fatHi');
  @override
  late final GeneratedColumn<int> fatHi = GeneratedColumn<int>(
    'fat_hi',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _linkedEntryIdMeta = const VerificationMeta(
    'linkedEntryId',
  );
  @override
  late final GeneratedColumn<String> linkedEntryId = GeneratedColumn<String>(
    'linked_entry_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    timestamp,
    slot,
    name,
    source,
    icon,
    confidence,
    calLo,
    calHi,
    proteinLo,
    proteinHi,
    carbsLo,
    carbsHi,
    fatLo,
    fatHi,
    note,
    tags,
    linkedEntryId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'nutrition_meals';
  @override
  VerificationContext validateIntegrity(
    Insertable<NutritionMealRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('slot')) {
      context.handle(
        _slotMeta,
        slot.isAcceptableOrUnknown(data['slot']!, _slotMeta),
      );
    } else if (isInserting) {
      context.missing(_slotMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    } else if (isInserting) {
      context.missing(_iconMeta);
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    } else if (isInserting) {
      context.missing(_confidenceMeta);
    }
    if (data.containsKey('cal_lo')) {
      context.handle(
        _calLoMeta,
        calLo.isAcceptableOrUnknown(data['cal_lo']!, _calLoMeta),
      );
    } else if (isInserting) {
      context.missing(_calLoMeta);
    }
    if (data.containsKey('cal_hi')) {
      context.handle(
        _calHiMeta,
        calHi.isAcceptableOrUnknown(data['cal_hi']!, _calHiMeta),
      );
    } else if (isInserting) {
      context.missing(_calHiMeta);
    }
    if (data.containsKey('protein_lo')) {
      context.handle(
        _proteinLoMeta,
        proteinLo.isAcceptableOrUnknown(data['protein_lo']!, _proteinLoMeta),
      );
    } else if (isInserting) {
      context.missing(_proteinLoMeta);
    }
    if (data.containsKey('protein_hi')) {
      context.handle(
        _proteinHiMeta,
        proteinHi.isAcceptableOrUnknown(data['protein_hi']!, _proteinHiMeta),
      );
    } else if (isInserting) {
      context.missing(_proteinHiMeta);
    }
    if (data.containsKey('carbs_lo')) {
      context.handle(
        _carbsLoMeta,
        carbsLo.isAcceptableOrUnknown(data['carbs_lo']!, _carbsLoMeta),
      );
    } else if (isInserting) {
      context.missing(_carbsLoMeta);
    }
    if (data.containsKey('carbs_hi')) {
      context.handle(
        _carbsHiMeta,
        carbsHi.isAcceptableOrUnknown(data['carbs_hi']!, _carbsHiMeta),
      );
    } else if (isInserting) {
      context.missing(_carbsHiMeta);
    }
    if (data.containsKey('fat_lo')) {
      context.handle(
        _fatLoMeta,
        fatLo.isAcceptableOrUnknown(data['fat_lo']!, _fatLoMeta),
      );
    } else if (isInserting) {
      context.missing(_fatLoMeta);
    }
    if (data.containsKey('fat_hi')) {
      context.handle(
        _fatHiMeta,
        fatHi.isAcceptableOrUnknown(data['fat_hi']!, _fatHiMeta),
      );
    } else if (isInserting) {
      context.missing(_fatHiMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('linked_entry_id')) {
      context.handle(
        _linkedEntryIdMeta,
        linkedEntryId.isAcceptableOrUnknown(
          data['linked_entry_id']!,
          _linkedEntryIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NutritionMealRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NutritionMealRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      slot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slot'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      )!,
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}confidence'],
      )!,
      calLo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cal_lo'],
      )!,
      calHi: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cal_hi'],
      )!,
      proteinLo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}protein_lo'],
      )!,
      proteinHi: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}protein_hi'],
      )!,
      carbsLo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}carbs_lo'],
      )!,
      carbsHi: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}carbs_hi'],
      )!,
      fatLo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fat_lo'],
      )!,
      fatHi: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fat_hi'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
      linkedEntryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}linked_entry_id'],
      ),
    );
  }

  @override
  $NutritionMealsTable createAlias(String alias) {
    return $NutritionMealsTable(attachedDatabase, alias);
  }
}

class NutritionMealRow extends DataClass
    implements Insertable<NutritionMealRow> {
  final String id;
  final DateTime timestamp;
  final String slot;
  final String name;

  /// [NutritionSource.wire].
  final String source;
  final String icon;

  /// [NutritionConfidence.wire].
  final String confidence;
  final int calLo;
  final int calHi;
  final int proteinLo;
  final int proteinHi;
  final int carbsLo;
  final int carbsHi;
  final int fatLo;
  final int fatHi;
  final String? note;

  /// Newline-joined tag list ('' when none).
  final String tags;

  /// FK to [Entries.id] for takeout meals (null otherwise).
  final String? linkedEntryId;
  const NutritionMealRow({
    required this.id,
    required this.timestamp,
    required this.slot,
    required this.name,
    required this.source,
    required this.icon,
    required this.confidence,
    required this.calLo,
    required this.calHi,
    required this.proteinLo,
    required this.proteinHi,
    required this.carbsLo,
    required this.carbsHi,
    required this.fatLo,
    required this.fatHi,
    this.note,
    required this.tags,
    this.linkedEntryId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['slot'] = Variable<String>(slot);
    map['name'] = Variable<String>(name);
    map['source'] = Variable<String>(source);
    map['icon'] = Variable<String>(icon);
    map['confidence'] = Variable<String>(confidence);
    map['cal_lo'] = Variable<int>(calLo);
    map['cal_hi'] = Variable<int>(calHi);
    map['protein_lo'] = Variable<int>(proteinLo);
    map['protein_hi'] = Variable<int>(proteinHi);
    map['carbs_lo'] = Variable<int>(carbsLo);
    map['carbs_hi'] = Variable<int>(carbsHi);
    map['fat_lo'] = Variable<int>(fatLo);
    map['fat_hi'] = Variable<int>(fatHi);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['tags'] = Variable<String>(tags);
    if (!nullToAbsent || linkedEntryId != null) {
      map['linked_entry_id'] = Variable<String>(linkedEntryId);
    }
    return map;
  }

  NutritionMealsCompanion toCompanion(bool nullToAbsent) {
    return NutritionMealsCompanion(
      id: Value(id),
      timestamp: Value(timestamp),
      slot: Value(slot),
      name: Value(name),
      source: Value(source),
      icon: Value(icon),
      confidence: Value(confidence),
      calLo: Value(calLo),
      calHi: Value(calHi),
      proteinLo: Value(proteinLo),
      proteinHi: Value(proteinHi),
      carbsLo: Value(carbsLo),
      carbsHi: Value(carbsHi),
      fatLo: Value(fatLo),
      fatHi: Value(fatHi),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      tags: Value(tags),
      linkedEntryId: linkedEntryId == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedEntryId),
    );
  }

  factory NutritionMealRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NutritionMealRow(
      id: serializer.fromJson<String>(json['id']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      slot: serializer.fromJson<String>(json['slot']),
      name: serializer.fromJson<String>(json['name']),
      source: serializer.fromJson<String>(json['source']),
      icon: serializer.fromJson<String>(json['icon']),
      confidence: serializer.fromJson<String>(json['confidence']),
      calLo: serializer.fromJson<int>(json['calLo']),
      calHi: serializer.fromJson<int>(json['calHi']),
      proteinLo: serializer.fromJson<int>(json['proteinLo']),
      proteinHi: serializer.fromJson<int>(json['proteinHi']),
      carbsLo: serializer.fromJson<int>(json['carbsLo']),
      carbsHi: serializer.fromJson<int>(json['carbsHi']),
      fatLo: serializer.fromJson<int>(json['fatLo']),
      fatHi: serializer.fromJson<int>(json['fatHi']),
      note: serializer.fromJson<String?>(json['note']),
      tags: serializer.fromJson<String>(json['tags']),
      linkedEntryId: serializer.fromJson<String?>(json['linkedEntryId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'slot': serializer.toJson<String>(slot),
      'name': serializer.toJson<String>(name),
      'source': serializer.toJson<String>(source),
      'icon': serializer.toJson<String>(icon),
      'confidence': serializer.toJson<String>(confidence),
      'calLo': serializer.toJson<int>(calLo),
      'calHi': serializer.toJson<int>(calHi),
      'proteinLo': serializer.toJson<int>(proteinLo),
      'proteinHi': serializer.toJson<int>(proteinHi),
      'carbsLo': serializer.toJson<int>(carbsLo),
      'carbsHi': serializer.toJson<int>(carbsHi),
      'fatLo': serializer.toJson<int>(fatLo),
      'fatHi': serializer.toJson<int>(fatHi),
      'note': serializer.toJson<String?>(note),
      'tags': serializer.toJson<String>(tags),
      'linkedEntryId': serializer.toJson<String?>(linkedEntryId),
    };
  }

  NutritionMealRow copyWith({
    String? id,
    DateTime? timestamp,
    String? slot,
    String? name,
    String? source,
    String? icon,
    String? confidence,
    int? calLo,
    int? calHi,
    int? proteinLo,
    int? proteinHi,
    int? carbsLo,
    int? carbsHi,
    int? fatLo,
    int? fatHi,
    Value<String?> note = const Value.absent(),
    String? tags,
    Value<String?> linkedEntryId = const Value.absent(),
  }) => NutritionMealRow(
    id: id ?? this.id,
    timestamp: timestamp ?? this.timestamp,
    slot: slot ?? this.slot,
    name: name ?? this.name,
    source: source ?? this.source,
    icon: icon ?? this.icon,
    confidence: confidence ?? this.confidence,
    calLo: calLo ?? this.calLo,
    calHi: calHi ?? this.calHi,
    proteinLo: proteinLo ?? this.proteinLo,
    proteinHi: proteinHi ?? this.proteinHi,
    carbsLo: carbsLo ?? this.carbsLo,
    carbsHi: carbsHi ?? this.carbsHi,
    fatLo: fatLo ?? this.fatLo,
    fatHi: fatHi ?? this.fatHi,
    note: note.present ? note.value : this.note,
    tags: tags ?? this.tags,
    linkedEntryId: linkedEntryId.present
        ? linkedEntryId.value
        : this.linkedEntryId,
  );
  NutritionMealRow copyWithCompanion(NutritionMealsCompanion data) {
    return NutritionMealRow(
      id: data.id.present ? data.id.value : this.id,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      slot: data.slot.present ? data.slot.value : this.slot,
      name: data.name.present ? data.name.value : this.name,
      source: data.source.present ? data.source.value : this.source,
      icon: data.icon.present ? data.icon.value : this.icon,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      calLo: data.calLo.present ? data.calLo.value : this.calLo,
      calHi: data.calHi.present ? data.calHi.value : this.calHi,
      proteinLo: data.proteinLo.present ? data.proteinLo.value : this.proteinLo,
      proteinHi: data.proteinHi.present ? data.proteinHi.value : this.proteinHi,
      carbsLo: data.carbsLo.present ? data.carbsLo.value : this.carbsLo,
      carbsHi: data.carbsHi.present ? data.carbsHi.value : this.carbsHi,
      fatLo: data.fatLo.present ? data.fatLo.value : this.fatLo,
      fatHi: data.fatHi.present ? data.fatHi.value : this.fatHi,
      note: data.note.present ? data.note.value : this.note,
      tags: data.tags.present ? data.tags.value : this.tags,
      linkedEntryId: data.linkedEntryId.present
          ? data.linkedEntryId.value
          : this.linkedEntryId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NutritionMealRow(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('slot: $slot, ')
          ..write('name: $name, ')
          ..write('source: $source, ')
          ..write('icon: $icon, ')
          ..write('confidence: $confidence, ')
          ..write('calLo: $calLo, ')
          ..write('calHi: $calHi, ')
          ..write('proteinLo: $proteinLo, ')
          ..write('proteinHi: $proteinHi, ')
          ..write('carbsLo: $carbsLo, ')
          ..write('carbsHi: $carbsHi, ')
          ..write('fatLo: $fatLo, ')
          ..write('fatHi: $fatHi, ')
          ..write('note: $note, ')
          ..write('tags: $tags, ')
          ..write('linkedEntryId: $linkedEntryId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    timestamp,
    slot,
    name,
    source,
    icon,
    confidence,
    calLo,
    calHi,
    proteinLo,
    proteinHi,
    carbsLo,
    carbsHi,
    fatLo,
    fatHi,
    note,
    tags,
    linkedEntryId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NutritionMealRow &&
          other.id == this.id &&
          other.timestamp == this.timestamp &&
          other.slot == this.slot &&
          other.name == this.name &&
          other.source == this.source &&
          other.icon == this.icon &&
          other.confidence == this.confidence &&
          other.calLo == this.calLo &&
          other.calHi == this.calHi &&
          other.proteinLo == this.proteinLo &&
          other.proteinHi == this.proteinHi &&
          other.carbsLo == this.carbsLo &&
          other.carbsHi == this.carbsHi &&
          other.fatLo == this.fatLo &&
          other.fatHi == this.fatHi &&
          other.note == this.note &&
          other.tags == this.tags &&
          other.linkedEntryId == this.linkedEntryId);
}

class NutritionMealsCompanion extends UpdateCompanion<NutritionMealRow> {
  final Value<String> id;
  final Value<DateTime> timestamp;
  final Value<String> slot;
  final Value<String> name;
  final Value<String> source;
  final Value<String> icon;
  final Value<String> confidence;
  final Value<int> calLo;
  final Value<int> calHi;
  final Value<int> proteinLo;
  final Value<int> proteinHi;
  final Value<int> carbsLo;
  final Value<int> carbsHi;
  final Value<int> fatLo;
  final Value<int> fatHi;
  final Value<String?> note;
  final Value<String> tags;
  final Value<String?> linkedEntryId;
  final Value<int> rowid;
  const NutritionMealsCompanion({
    this.id = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.slot = const Value.absent(),
    this.name = const Value.absent(),
    this.source = const Value.absent(),
    this.icon = const Value.absent(),
    this.confidence = const Value.absent(),
    this.calLo = const Value.absent(),
    this.calHi = const Value.absent(),
    this.proteinLo = const Value.absent(),
    this.proteinHi = const Value.absent(),
    this.carbsLo = const Value.absent(),
    this.carbsHi = const Value.absent(),
    this.fatLo = const Value.absent(),
    this.fatHi = const Value.absent(),
    this.note = const Value.absent(),
    this.tags = const Value.absent(),
    this.linkedEntryId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NutritionMealsCompanion.insert({
    required String id,
    required DateTime timestamp,
    required String slot,
    required String name,
    required String source,
    required String icon,
    required String confidence,
    required int calLo,
    required int calHi,
    required int proteinLo,
    required int proteinHi,
    required int carbsLo,
    required int carbsHi,
    required int fatLo,
    required int fatHi,
    this.note = const Value.absent(),
    this.tags = const Value.absent(),
    this.linkedEntryId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       timestamp = Value(timestamp),
       slot = Value(slot),
       name = Value(name),
       source = Value(source),
       icon = Value(icon),
       confidence = Value(confidence),
       calLo = Value(calLo),
       calHi = Value(calHi),
       proteinLo = Value(proteinLo),
       proteinHi = Value(proteinHi),
       carbsLo = Value(carbsLo),
       carbsHi = Value(carbsHi),
       fatLo = Value(fatLo),
       fatHi = Value(fatHi);
  static Insertable<NutritionMealRow> custom({
    Expression<String>? id,
    Expression<DateTime>? timestamp,
    Expression<String>? slot,
    Expression<String>? name,
    Expression<String>? source,
    Expression<String>? icon,
    Expression<String>? confidence,
    Expression<int>? calLo,
    Expression<int>? calHi,
    Expression<int>? proteinLo,
    Expression<int>? proteinHi,
    Expression<int>? carbsLo,
    Expression<int>? carbsHi,
    Expression<int>? fatLo,
    Expression<int>? fatHi,
    Expression<String>? note,
    Expression<String>? tags,
    Expression<String>? linkedEntryId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (timestamp != null) 'timestamp': timestamp,
      if (slot != null) 'slot': slot,
      if (name != null) 'name': name,
      if (source != null) 'source': source,
      if (icon != null) 'icon': icon,
      if (confidence != null) 'confidence': confidence,
      if (calLo != null) 'cal_lo': calLo,
      if (calHi != null) 'cal_hi': calHi,
      if (proteinLo != null) 'protein_lo': proteinLo,
      if (proteinHi != null) 'protein_hi': proteinHi,
      if (carbsLo != null) 'carbs_lo': carbsLo,
      if (carbsHi != null) 'carbs_hi': carbsHi,
      if (fatLo != null) 'fat_lo': fatLo,
      if (fatHi != null) 'fat_hi': fatHi,
      if (note != null) 'note': note,
      if (tags != null) 'tags': tags,
      if (linkedEntryId != null) 'linked_entry_id': linkedEntryId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NutritionMealsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? timestamp,
    Value<String>? slot,
    Value<String>? name,
    Value<String>? source,
    Value<String>? icon,
    Value<String>? confidence,
    Value<int>? calLo,
    Value<int>? calHi,
    Value<int>? proteinLo,
    Value<int>? proteinHi,
    Value<int>? carbsLo,
    Value<int>? carbsHi,
    Value<int>? fatLo,
    Value<int>? fatHi,
    Value<String?>? note,
    Value<String>? tags,
    Value<String?>? linkedEntryId,
    Value<int>? rowid,
  }) {
    return NutritionMealsCompanion(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      slot: slot ?? this.slot,
      name: name ?? this.name,
      source: source ?? this.source,
      icon: icon ?? this.icon,
      confidence: confidence ?? this.confidence,
      calLo: calLo ?? this.calLo,
      calHi: calHi ?? this.calHi,
      proteinLo: proteinLo ?? this.proteinLo,
      proteinHi: proteinHi ?? this.proteinHi,
      carbsLo: carbsLo ?? this.carbsLo,
      carbsHi: carbsHi ?? this.carbsHi,
      fatLo: fatLo ?? this.fatLo,
      fatHi: fatHi ?? this.fatHi,
      note: note ?? this.note,
      tags: tags ?? this.tags,
      linkedEntryId: linkedEntryId ?? this.linkedEntryId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (slot.present) {
      map['slot'] = Variable<String>(slot.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<String>(confidence.value);
    }
    if (calLo.present) {
      map['cal_lo'] = Variable<int>(calLo.value);
    }
    if (calHi.present) {
      map['cal_hi'] = Variable<int>(calHi.value);
    }
    if (proteinLo.present) {
      map['protein_lo'] = Variable<int>(proteinLo.value);
    }
    if (proteinHi.present) {
      map['protein_hi'] = Variable<int>(proteinHi.value);
    }
    if (carbsLo.present) {
      map['carbs_lo'] = Variable<int>(carbsLo.value);
    }
    if (carbsHi.present) {
      map['carbs_hi'] = Variable<int>(carbsHi.value);
    }
    if (fatLo.present) {
      map['fat_lo'] = Variable<int>(fatLo.value);
    }
    if (fatHi.present) {
      map['fat_hi'] = Variable<int>(fatHi.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (linkedEntryId.present) {
      map['linked_entry_id'] = Variable<String>(linkedEntryId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NutritionMealsCompanion(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('slot: $slot, ')
          ..write('name: $name, ')
          ..write('source: $source, ')
          ..write('icon: $icon, ')
          ..write('confidence: $confidence, ')
          ..write('calLo: $calLo, ')
          ..write('calHi: $calHi, ')
          ..write('proteinLo: $proteinLo, ')
          ..write('proteinHi: $proteinHi, ')
          ..write('carbsLo: $carbsLo, ')
          ..write('carbsHi: $carbsHi, ')
          ..write('fatLo: $fatLo, ')
          ..write('fatHi: $fatHi, ')
          ..write('note: $note, ')
          ..write('tags: $tags, ')
          ..write('linkedEntryId: $linkedEntryId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LoopDatabase extends GeneratedDatabase {
  _$LoopDatabase(QueryExecutor e) : super(e);
  $LoopDatabaseManager get managers => $LoopDatabaseManager(this);
  late final $EntriesTable entries = $EntriesTable(this);
  late final $ExercisesTable exercises = $ExercisesTable(this);
  late final $RoutinesTable routines = $RoutinesTable(this);
  late final $RoutineExercisesTable routineExercises = $RoutineExercisesTable(
    this,
  );
  late final $WorkoutsTable workouts = $WorkoutsTable(this);
  late final $SetLogsTable setLogs = $SetLogsTable(this);
  late final $RitualRoutinesTable ritualRoutines = $RitualRoutinesTable(this);
  late final $RitualStepsTable ritualSteps = $RitualStepsTable(this);
  late final $PalNotesTable palNotes = $PalNotesTable(this);
  late final $GoalsTableTable goalsTable = $GoalsTableTable(this);
  late final $SeedMarkersTable seedMarkers = $SeedMarkersTable(this);
  late final $WeeklyPlanDaysTable weeklyPlanDays = $WeeklyPlanDaysTable(this);
  late final $BudgetEnvelopesTable budgetEnvelopes = $BudgetEnvelopesTable(
    this,
  );
  late final $NutritionMealsTable nutritionMeals = $NutritionMealsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    entries,
    exercises,
    routines,
    routineExercises,
    workouts,
    setLogs,
    ritualRoutines,
    ritualSteps,
    palNotes,
    goalsTable,
    seedMarkers,
    weeklyPlanDays,
    budgetEnvelopes,
    nutritionMeals,
  ];
}

typedef $$EntriesTableCreateCompanionBuilder =
    EntriesCompanion Function({
      required String id,
      required DateTime timestamp,
      required String type,
      required String title,
      Value<String?> detail,
      Value<double?> amount,
      Value<int?> duration,
      Value<int?> calories,
      Value<double?> distance,
      Value<String?> category,
      Value<String?> ritualId,
      Value<String?> note,
      required String source,
      Value<String?> sourceRef,
      Value<String?> workoutId,
      Value<int> rowid,
    });
typedef $$EntriesTableUpdateCompanionBuilder =
    EntriesCompanion Function({
      Value<String> id,
      Value<DateTime> timestamp,
      Value<String> type,
      Value<String> title,
      Value<String?> detail,
      Value<double?> amount,
      Value<int?> duration,
      Value<int?> calories,
      Value<double?> distance,
      Value<String?> category,
      Value<String?> ritualId,
      Value<String?> note,
      Value<String> source,
      Value<String?> sourceRef,
      Value<String?> workoutId,
      Value<int> rowid,
    });

class $$EntriesTableFilterComposer
    extends Composer<_$LoopDatabase, $EntriesTable> {
  $$EntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get calories => $composableBuilder(
    column: $table.calories,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get distance => $composableBuilder(
    column: $table.distance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ritualId => $composableBuilder(
    column: $table.ritualId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceRef => $composableBuilder(
    column: $table.sourceRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workoutId => $composableBuilder(
    column: $table.workoutId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EntriesTableOrderingComposer
    extends Composer<_$LoopDatabase, $EntriesTable> {
  $$EntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get calories => $composableBuilder(
    column: $table.calories,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get distance => $composableBuilder(
    column: $table.distance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ritualId => $composableBuilder(
    column: $table.ritualId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceRef => $composableBuilder(
    column: $table.sourceRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workoutId => $composableBuilder(
    column: $table.workoutId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EntriesTableAnnotationComposer
    extends Composer<_$LoopDatabase, $EntriesTable> {
  $$EntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get detail =>
      $composableBuilder(column: $table.detail, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<int> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<int> get calories =>
      $composableBuilder(column: $table.calories, builder: (column) => column);

  GeneratedColumn<double> get distance =>
      $composableBuilder(column: $table.distance, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get ritualId =>
      $composableBuilder(column: $table.ritualId, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get sourceRef =>
      $composableBuilder(column: $table.sourceRef, builder: (column) => column);

  GeneratedColumn<String> get workoutId =>
      $composableBuilder(column: $table.workoutId, builder: (column) => column);
}

class $$EntriesTableTableManager
    extends
        RootTableManager<
          _$LoopDatabase,
          $EntriesTable,
          EntryRow,
          $$EntriesTableFilterComposer,
          $$EntriesTableOrderingComposer,
          $$EntriesTableAnnotationComposer,
          $$EntriesTableCreateCompanionBuilder,
          $$EntriesTableUpdateCompanionBuilder,
          (EntryRow, BaseReferences<_$LoopDatabase, $EntriesTable, EntryRow>),
          EntryRow,
          PrefetchHooks Function()
        > {
  $$EntriesTableTableManager(_$LoopDatabase db, $EntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> detail = const Value.absent(),
                Value<double?> amount = const Value.absent(),
                Value<int?> duration = const Value.absent(),
                Value<int?> calories = const Value.absent(),
                Value<double?> distance = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String?> ritualId = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> sourceRef = const Value.absent(),
                Value<String?> workoutId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntriesCompanion(
                id: id,
                timestamp: timestamp,
                type: type,
                title: title,
                detail: detail,
                amount: amount,
                duration: duration,
                calories: calories,
                distance: distance,
                category: category,
                ritualId: ritualId,
                note: note,
                source: source,
                sourceRef: sourceRef,
                workoutId: workoutId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime timestamp,
                required String type,
                required String title,
                Value<String?> detail = const Value.absent(),
                Value<double?> amount = const Value.absent(),
                Value<int?> duration = const Value.absent(),
                Value<int?> calories = const Value.absent(),
                Value<double?> distance = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String?> ritualId = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required String source,
                Value<String?> sourceRef = const Value.absent(),
                Value<String?> workoutId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntriesCompanion.insert(
                id: id,
                timestamp: timestamp,
                type: type,
                title: title,
                detail: detail,
                amount: amount,
                duration: duration,
                calories: calories,
                distance: distance,
                category: category,
                ritualId: ritualId,
                note: note,
                source: source,
                sourceRef: sourceRef,
                workoutId: workoutId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$LoopDatabase,
      $EntriesTable,
      EntryRow,
      $$EntriesTableFilterComposer,
      $$EntriesTableOrderingComposer,
      $$EntriesTableAnnotationComposer,
      $$EntriesTableCreateCompanionBuilder,
      $$EntriesTableUpdateCompanionBuilder,
      (EntryRow, BaseReferences<_$LoopDatabase, $EntriesTable, EntryRow>),
      EntryRow,
      PrefetchHooks Function()
    >;
typedef $$ExercisesTableCreateCompanionBuilder =
    ExercisesCompanion Function({
      required String id,
      required String name,
      required String group,
      required String muscle,
      required String icon,
      Value<String?> equipment,
      Value<double?> prWeightKg,
      Value<int?> prReps,
      Value<int> rowid,
    });
typedef $$ExercisesTableUpdateCompanionBuilder =
    ExercisesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> group,
      Value<String> muscle,
      Value<String> icon,
      Value<String?> equipment,
      Value<double?> prWeightKg,
      Value<int?> prReps,
      Value<int> rowid,
    });

class $$ExercisesTableFilterComposer
    extends Composer<_$LoopDatabase, $ExercisesTable> {
  $$ExercisesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get group => $composableBuilder(
    column: $table.group,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get muscle => $composableBuilder(
    column: $table.muscle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get equipment => $composableBuilder(
    column: $table.equipment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get prWeightKg => $composableBuilder(
    column: $table.prWeightKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get prReps => $composableBuilder(
    column: $table.prReps,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExercisesTableOrderingComposer
    extends Composer<_$LoopDatabase, $ExercisesTable> {
  $$ExercisesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get group => $composableBuilder(
    column: $table.group,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get muscle => $composableBuilder(
    column: $table.muscle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get equipment => $composableBuilder(
    column: $table.equipment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get prWeightKg => $composableBuilder(
    column: $table.prWeightKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get prReps => $composableBuilder(
    column: $table.prReps,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExercisesTableAnnotationComposer
    extends Composer<_$LoopDatabase, $ExercisesTable> {
  $$ExercisesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get group =>
      $composableBuilder(column: $table.group, builder: (column) => column);

  GeneratedColumn<String> get muscle =>
      $composableBuilder(column: $table.muscle, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get equipment =>
      $composableBuilder(column: $table.equipment, builder: (column) => column);

  GeneratedColumn<double> get prWeightKg => $composableBuilder(
    column: $table.prWeightKg,
    builder: (column) => column,
  );

  GeneratedColumn<int> get prReps =>
      $composableBuilder(column: $table.prReps, builder: (column) => column);
}

class $$ExercisesTableTableManager
    extends
        RootTableManager<
          _$LoopDatabase,
          $ExercisesTable,
          ExerciseRow,
          $$ExercisesTableFilterComposer,
          $$ExercisesTableOrderingComposer,
          $$ExercisesTableAnnotationComposer,
          $$ExercisesTableCreateCompanionBuilder,
          $$ExercisesTableUpdateCompanionBuilder,
          (
            ExerciseRow,
            BaseReferences<_$LoopDatabase, $ExercisesTable, ExerciseRow>,
          ),
          ExerciseRow,
          PrefetchHooks Function()
        > {
  $$ExercisesTableTableManager(_$LoopDatabase db, $ExercisesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExercisesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExercisesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExercisesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> group = const Value.absent(),
                Value<String> muscle = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<String?> equipment = const Value.absent(),
                Value<double?> prWeightKg = const Value.absent(),
                Value<int?> prReps = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExercisesCompanion(
                id: id,
                name: name,
                group: group,
                muscle: muscle,
                icon: icon,
                equipment: equipment,
                prWeightKg: prWeightKg,
                prReps: prReps,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String group,
                required String muscle,
                required String icon,
                Value<String?> equipment = const Value.absent(),
                Value<double?> prWeightKg = const Value.absent(),
                Value<int?> prReps = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExercisesCompanion.insert(
                id: id,
                name: name,
                group: group,
                muscle: muscle,
                icon: icon,
                equipment: equipment,
                prWeightKg: prWeightKg,
                prReps: prReps,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExercisesTableProcessedTableManager =
    ProcessedTableManager<
      _$LoopDatabase,
      $ExercisesTable,
      ExerciseRow,
      $$ExercisesTableFilterComposer,
      $$ExercisesTableOrderingComposer,
      $$ExercisesTableAnnotationComposer,
      $$ExercisesTableCreateCompanionBuilder,
      $$ExercisesTableUpdateCompanionBuilder,
      (
        ExerciseRow,
        BaseReferences<_$LoopDatabase, $ExercisesTable, ExerciseRow>,
      ),
      ExerciseRow,
      PrefetchHooks Function()
    >;
typedef $$RoutinesTableCreateCompanionBuilder =
    RoutinesCompanion Function({
      required String id,
      required String name,
      required String tag,
      Value<int> restSeconds,
      Value<bool> warmupReminder,
      Value<bool> autoProgress,
      Value<int?> estMin,
      Value<double?> distanceKm,
      Value<String?> pace,
      Value<int> rowid,
    });
typedef $$RoutinesTableUpdateCompanionBuilder =
    RoutinesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> tag,
      Value<int> restSeconds,
      Value<bool> warmupReminder,
      Value<bool> autoProgress,
      Value<int?> estMin,
      Value<double?> distanceKm,
      Value<String?> pace,
      Value<int> rowid,
    });

class $$RoutinesTableFilterComposer
    extends Composer<_$LoopDatabase, $RoutinesTable> {
  $$RoutinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get warmupReminder => $composableBuilder(
    column: $table.warmupReminder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoProgress => $composableBuilder(
    column: $table.autoProgress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get estMin => $composableBuilder(
    column: $table.estMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get distanceKm => $composableBuilder(
    column: $table.distanceKm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pace => $composableBuilder(
    column: $table.pace,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RoutinesTableOrderingComposer
    extends Composer<_$LoopDatabase, $RoutinesTable> {
  $$RoutinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get warmupReminder => $composableBuilder(
    column: $table.warmupReminder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoProgress => $composableBuilder(
    column: $table.autoProgress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get estMin => $composableBuilder(
    column: $table.estMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get distanceKm => $composableBuilder(
    column: $table.distanceKm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pace => $composableBuilder(
    column: $table.pace,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RoutinesTableAnnotationComposer
    extends Composer<_$LoopDatabase, $RoutinesTable> {
  $$RoutinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  GeneratedColumn<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get warmupReminder => $composableBuilder(
    column: $table.warmupReminder,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get autoProgress => $composableBuilder(
    column: $table.autoProgress,
    builder: (column) => column,
  );

  GeneratedColumn<int> get estMin =>
      $composableBuilder(column: $table.estMin, builder: (column) => column);

  GeneratedColumn<double> get distanceKm => $composableBuilder(
    column: $table.distanceKm,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pace =>
      $composableBuilder(column: $table.pace, builder: (column) => column);
}

class $$RoutinesTableTableManager
    extends
        RootTableManager<
          _$LoopDatabase,
          $RoutinesTable,
          RoutineRow,
          $$RoutinesTableFilterComposer,
          $$RoutinesTableOrderingComposer,
          $$RoutinesTableAnnotationComposer,
          $$RoutinesTableCreateCompanionBuilder,
          $$RoutinesTableUpdateCompanionBuilder,
          (
            RoutineRow,
            BaseReferences<_$LoopDatabase, $RoutinesTable, RoutineRow>,
          ),
          RoutineRow,
          PrefetchHooks Function()
        > {
  $$RoutinesTableTableManager(_$LoopDatabase db, $RoutinesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoutinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RoutinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RoutinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> tag = const Value.absent(),
                Value<int> restSeconds = const Value.absent(),
                Value<bool> warmupReminder = const Value.absent(),
                Value<bool> autoProgress = const Value.absent(),
                Value<int?> estMin = const Value.absent(),
                Value<double?> distanceKm = const Value.absent(),
                Value<String?> pace = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RoutinesCompanion(
                id: id,
                name: name,
                tag: tag,
                restSeconds: restSeconds,
                warmupReminder: warmupReminder,
                autoProgress: autoProgress,
                estMin: estMin,
                distanceKm: distanceKm,
                pace: pace,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String tag,
                Value<int> restSeconds = const Value.absent(),
                Value<bool> warmupReminder = const Value.absent(),
                Value<bool> autoProgress = const Value.absent(),
                Value<int?> estMin = const Value.absent(),
                Value<double?> distanceKm = const Value.absent(),
                Value<String?> pace = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RoutinesCompanion.insert(
                id: id,
                name: name,
                tag: tag,
                restSeconds: restSeconds,
                warmupReminder: warmupReminder,
                autoProgress: autoProgress,
                estMin: estMin,
                distanceKm: distanceKm,
                pace: pace,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RoutinesTableProcessedTableManager =
    ProcessedTableManager<
      _$LoopDatabase,
      $RoutinesTable,
      RoutineRow,
      $$RoutinesTableFilterComposer,
      $$RoutinesTableOrderingComposer,
      $$RoutinesTableAnnotationComposer,
      $$RoutinesTableCreateCompanionBuilder,
      $$RoutinesTableUpdateCompanionBuilder,
      (RoutineRow, BaseReferences<_$LoopDatabase, $RoutinesTable, RoutineRow>),
      RoutineRow,
      PrefetchHooks Function()
    >;
typedef $$RoutineExercisesTableCreateCompanionBuilder =
    RoutineExercisesCompanion Function({
      required String id,
      required String routineId,
      required String exerciseId,
      required int position,
      Value<int> targetSets,
      Value<int?> targetReps,
      Value<double?> targetWeightKg,
      Value<int> rowid,
    });
typedef $$RoutineExercisesTableUpdateCompanionBuilder =
    RoutineExercisesCompanion Function({
      Value<String> id,
      Value<String> routineId,
      Value<String> exerciseId,
      Value<int> position,
      Value<int> targetSets,
      Value<int?> targetReps,
      Value<double?> targetWeightKg,
      Value<int> rowid,
    });

class $$RoutineExercisesTableFilterComposer
    extends Composer<_$LoopDatabase, $RoutineExercisesTable> {
  $$RoutineExercisesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get routineId => $composableBuilder(
    column: $table.routineId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetSets => $composableBuilder(
    column: $table.targetSets,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetReps => $composableBuilder(
    column: $table.targetReps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get targetWeightKg => $composableBuilder(
    column: $table.targetWeightKg,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RoutineExercisesTableOrderingComposer
    extends Composer<_$LoopDatabase, $RoutineExercisesTable> {
  $$RoutineExercisesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get routineId => $composableBuilder(
    column: $table.routineId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetSets => $composableBuilder(
    column: $table.targetSets,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetReps => $composableBuilder(
    column: $table.targetReps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get targetWeightKg => $composableBuilder(
    column: $table.targetWeightKg,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RoutineExercisesTableAnnotationComposer
    extends Composer<_$LoopDatabase, $RoutineExercisesTable> {
  $$RoutineExercisesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get routineId =>
      $composableBuilder(column: $table.routineId, builder: (column) => column);

  GeneratedColumn<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get targetSets => $composableBuilder(
    column: $table.targetSets,
    builder: (column) => column,
  );

  GeneratedColumn<int> get targetReps => $composableBuilder(
    column: $table.targetReps,
    builder: (column) => column,
  );

  GeneratedColumn<double> get targetWeightKg => $composableBuilder(
    column: $table.targetWeightKg,
    builder: (column) => column,
  );
}

class $$RoutineExercisesTableTableManager
    extends
        RootTableManager<
          _$LoopDatabase,
          $RoutineExercisesTable,
          RoutineExerciseRow,
          $$RoutineExercisesTableFilterComposer,
          $$RoutineExercisesTableOrderingComposer,
          $$RoutineExercisesTableAnnotationComposer,
          $$RoutineExercisesTableCreateCompanionBuilder,
          $$RoutineExercisesTableUpdateCompanionBuilder,
          (
            RoutineExerciseRow,
            BaseReferences<
              _$LoopDatabase,
              $RoutineExercisesTable,
              RoutineExerciseRow
            >,
          ),
          RoutineExerciseRow,
          PrefetchHooks Function()
        > {
  $$RoutineExercisesTableTableManager(
    _$LoopDatabase db,
    $RoutineExercisesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoutineExercisesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RoutineExercisesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RoutineExercisesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> routineId = const Value.absent(),
                Value<String> exerciseId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> targetSets = const Value.absent(),
                Value<int?> targetReps = const Value.absent(),
                Value<double?> targetWeightKg = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RoutineExercisesCompanion(
                id: id,
                routineId: routineId,
                exerciseId: exerciseId,
                position: position,
                targetSets: targetSets,
                targetReps: targetReps,
                targetWeightKg: targetWeightKg,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String routineId,
                required String exerciseId,
                required int position,
                Value<int> targetSets = const Value.absent(),
                Value<int?> targetReps = const Value.absent(),
                Value<double?> targetWeightKg = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RoutineExercisesCompanion.insert(
                id: id,
                routineId: routineId,
                exerciseId: exerciseId,
                position: position,
                targetSets: targetSets,
                targetReps: targetReps,
                targetWeightKg: targetWeightKg,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RoutineExercisesTableProcessedTableManager =
    ProcessedTableManager<
      _$LoopDatabase,
      $RoutineExercisesTable,
      RoutineExerciseRow,
      $$RoutineExercisesTableFilterComposer,
      $$RoutineExercisesTableOrderingComposer,
      $$RoutineExercisesTableAnnotationComposer,
      $$RoutineExercisesTableCreateCompanionBuilder,
      $$RoutineExercisesTableUpdateCompanionBuilder,
      (
        RoutineExerciseRow,
        BaseReferences<
          _$LoopDatabase,
          $RoutineExercisesTable,
          RoutineExerciseRow
        >,
      ),
      RoutineExerciseRow,
      PrefetchHooks Function()
    >;
typedef $$WorkoutsTableCreateCompanionBuilder =
    WorkoutsCompanion Function({
      required String id,
      Value<String?> routineId,
      required String name,
      required DateTime startedAt,
      Value<DateTime?> endedAt,
      Value<int> rowid,
    });
typedef $$WorkoutsTableUpdateCompanionBuilder =
    WorkoutsCompanion Function({
      Value<String> id,
      Value<String?> routineId,
      Value<String> name,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
      Value<int> rowid,
    });

class $$WorkoutsTableFilterComposer
    extends Composer<_$LoopDatabase, $WorkoutsTable> {
  $$WorkoutsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get routineId => $composableBuilder(
    column: $table.routineId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WorkoutsTableOrderingComposer
    extends Composer<_$LoopDatabase, $WorkoutsTable> {
  $$WorkoutsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get routineId => $composableBuilder(
    column: $table.routineId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkoutsTableAnnotationComposer
    extends Composer<_$LoopDatabase, $WorkoutsTable> {
  $$WorkoutsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get routineId =>
      $composableBuilder(column: $table.routineId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);
}

class $$WorkoutsTableTableManager
    extends
        RootTableManager<
          _$LoopDatabase,
          $WorkoutsTable,
          WorkoutRow,
          $$WorkoutsTableFilterComposer,
          $$WorkoutsTableOrderingComposer,
          $$WorkoutsTableAnnotationComposer,
          $$WorkoutsTableCreateCompanionBuilder,
          $$WorkoutsTableUpdateCompanionBuilder,
          (
            WorkoutRow,
            BaseReferences<_$LoopDatabase, $WorkoutsTable, WorkoutRow>,
          ),
          WorkoutRow,
          PrefetchHooks Function()
        > {
  $$WorkoutsTableTableManager(_$LoopDatabase db, $WorkoutsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkoutsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkoutsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkoutsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> routineId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkoutsCompanion(
                id: id,
                routineId: routineId,
                name: name,
                startedAt: startedAt,
                endedAt: endedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> routineId = const Value.absent(),
                required String name,
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkoutsCompanion.insert(
                id: id,
                routineId: routineId,
                name: name,
                startedAt: startedAt,
                endedAt: endedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WorkoutsTableProcessedTableManager =
    ProcessedTableManager<
      _$LoopDatabase,
      $WorkoutsTable,
      WorkoutRow,
      $$WorkoutsTableFilterComposer,
      $$WorkoutsTableOrderingComposer,
      $$WorkoutsTableAnnotationComposer,
      $$WorkoutsTableCreateCompanionBuilder,
      $$WorkoutsTableUpdateCompanionBuilder,
      (WorkoutRow, BaseReferences<_$LoopDatabase, $WorkoutsTable, WorkoutRow>),
      WorkoutRow,
      PrefetchHooks Function()
    >;
typedef $$SetLogsTableCreateCompanionBuilder =
    SetLogsCompanion Function({
      required String id,
      required String workoutId,
      required String exerciseId,
      required double weightKg,
      required int reps,
      Value<bool> done,
      Value<bool> isPR,
      Value<int> position,
      Value<int> rowid,
    });
typedef $$SetLogsTableUpdateCompanionBuilder =
    SetLogsCompanion Function({
      Value<String> id,
      Value<String> workoutId,
      Value<String> exerciseId,
      Value<double> weightKg,
      Value<int> reps,
      Value<bool> done,
      Value<bool> isPR,
      Value<int> position,
      Value<int> rowid,
    });

class $$SetLogsTableFilterComposer
    extends Composer<_$LoopDatabase, $SetLogsTable> {
  $$SetLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workoutId => $composableBuilder(
    column: $table.workoutId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPR => $composableBuilder(
    column: $table.isPR,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SetLogsTableOrderingComposer
    extends Composer<_$LoopDatabase, $SetLogsTable> {
  $$SetLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workoutId => $composableBuilder(
    column: $table.workoutId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPR => $composableBuilder(
    column: $table.isPR,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SetLogsTableAnnotationComposer
    extends Composer<_$LoopDatabase, $SetLogsTable> {
  $$SetLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workoutId =>
      $composableBuilder(column: $table.workoutId, builder: (column) => column);

  GeneratedColumn<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get weightKg =>
      $composableBuilder(column: $table.weightKg, builder: (column) => column);

  GeneratedColumn<int> get reps =>
      $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<bool> get done =>
      $composableBuilder(column: $table.done, builder: (column) => column);

  GeneratedColumn<bool> get isPR =>
      $composableBuilder(column: $table.isPR, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);
}

class $$SetLogsTableTableManager
    extends
        RootTableManager<
          _$LoopDatabase,
          $SetLogsTable,
          SetLogRow,
          $$SetLogsTableFilterComposer,
          $$SetLogsTableOrderingComposer,
          $$SetLogsTableAnnotationComposer,
          $$SetLogsTableCreateCompanionBuilder,
          $$SetLogsTableUpdateCompanionBuilder,
          (SetLogRow, BaseReferences<_$LoopDatabase, $SetLogsTable, SetLogRow>),
          SetLogRow,
          PrefetchHooks Function()
        > {
  $$SetLogsTableTableManager(_$LoopDatabase db, $SetLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SetLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SetLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SetLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> workoutId = const Value.absent(),
                Value<String> exerciseId = const Value.absent(),
                Value<double> weightKg = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<bool> done = const Value.absent(),
                Value<bool> isPR = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SetLogsCompanion(
                id: id,
                workoutId: workoutId,
                exerciseId: exerciseId,
                weightKg: weightKg,
                reps: reps,
                done: done,
                isPR: isPR,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String workoutId,
                required String exerciseId,
                required double weightKg,
                required int reps,
                Value<bool> done = const Value.absent(),
                Value<bool> isPR = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SetLogsCompanion.insert(
                id: id,
                workoutId: workoutId,
                exerciseId: exerciseId,
                weightKg: weightKg,
                reps: reps,
                done: done,
                isPR: isPR,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SetLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$LoopDatabase,
      $SetLogsTable,
      SetLogRow,
      $$SetLogsTableFilterComposer,
      $$SetLogsTableOrderingComposer,
      $$SetLogsTableAnnotationComposer,
      $$SetLogsTableCreateCompanionBuilder,
      $$SetLogsTableUpdateCompanionBuilder,
      (SetLogRow, BaseReferences<_$LoopDatabase, $SetLogsTable, SetLogRow>),
      SetLogRow,
      PrefetchHooks Function()
    >;
typedef $$RitualRoutinesTableCreateCompanionBuilder =
    RitualRoutinesCompanion Function({
      required String id,
      required String name,
      Value<String> time,
      required String tone,
      required String icon,
      Value<String> blurb,
      Value<int> streak,
      Value<int> position,
      Value<int> rowid,
    });
typedef $$RitualRoutinesTableUpdateCompanionBuilder =
    RitualRoutinesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> time,
      Value<String> tone,
      Value<String> icon,
      Value<String> blurb,
      Value<int> streak,
      Value<int> position,
      Value<int> rowid,
    });

class $$RitualRoutinesTableFilterComposer
    extends Composer<_$LoopDatabase, $RitualRoutinesTable> {
  $$RitualRoutinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tone => $composableBuilder(
    column: $table.tone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blurb => $composableBuilder(
    column: $table.blurb,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get streak => $composableBuilder(
    column: $table.streak,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RitualRoutinesTableOrderingComposer
    extends Composer<_$LoopDatabase, $RitualRoutinesTable> {
  $$RitualRoutinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tone => $composableBuilder(
    column: $table.tone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blurb => $composableBuilder(
    column: $table.blurb,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get streak => $composableBuilder(
    column: $table.streak,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RitualRoutinesTableAnnotationComposer
    extends Composer<_$LoopDatabase, $RitualRoutinesTable> {
  $$RitualRoutinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<String> get tone =>
      $composableBuilder(column: $table.tone, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get blurb =>
      $composableBuilder(column: $table.blurb, builder: (column) => column);

  GeneratedColumn<int> get streak =>
      $composableBuilder(column: $table.streak, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);
}

class $$RitualRoutinesTableTableManager
    extends
        RootTableManager<
          _$LoopDatabase,
          $RitualRoutinesTable,
          RitualRoutineRow,
          $$RitualRoutinesTableFilterComposer,
          $$RitualRoutinesTableOrderingComposer,
          $$RitualRoutinesTableAnnotationComposer,
          $$RitualRoutinesTableCreateCompanionBuilder,
          $$RitualRoutinesTableUpdateCompanionBuilder,
          (
            RitualRoutineRow,
            BaseReferences<
              _$LoopDatabase,
              $RitualRoutinesTable,
              RitualRoutineRow
            >,
          ),
          RitualRoutineRow,
          PrefetchHooks Function()
        > {
  $$RitualRoutinesTableTableManager(
    _$LoopDatabase db,
    $RitualRoutinesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RitualRoutinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RitualRoutinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RitualRoutinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> time = const Value.absent(),
                Value<String> tone = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<String> blurb = const Value.absent(),
                Value<int> streak = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RitualRoutinesCompanion(
                id: id,
                name: name,
                time: time,
                tone: tone,
                icon: icon,
                blurb: blurb,
                streak: streak,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> time = const Value.absent(),
                required String tone,
                required String icon,
                Value<String> blurb = const Value.absent(),
                Value<int> streak = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RitualRoutinesCompanion.insert(
                id: id,
                name: name,
                time: time,
                tone: tone,
                icon: icon,
                blurb: blurb,
                streak: streak,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RitualRoutinesTableProcessedTableManager =
    ProcessedTableManager<
      _$LoopDatabase,
      $RitualRoutinesTable,
      RitualRoutineRow,
      $$RitualRoutinesTableFilterComposer,
      $$RitualRoutinesTableOrderingComposer,
      $$RitualRoutinesTableAnnotationComposer,
      $$RitualRoutinesTableCreateCompanionBuilder,
      $$RitualRoutinesTableUpdateCompanionBuilder,
      (
        RitualRoutineRow,
        BaseReferences<_$LoopDatabase, $RitualRoutinesTable, RitualRoutineRow>,
      ),
      RitualRoutineRow,
      PrefetchHooks Function()
    >;
typedef $$RitualStepsTableCreateCompanionBuilder =
    RitualStepsCompanion Function({
      required String id,
      required String routineId,
      required String title,
      Value<String> note,
      required String icon,
      required int position,
      Value<int> rowid,
    });
typedef $$RitualStepsTableUpdateCompanionBuilder =
    RitualStepsCompanion Function({
      Value<String> id,
      Value<String> routineId,
      Value<String> title,
      Value<String> note,
      Value<String> icon,
      Value<int> position,
      Value<int> rowid,
    });

class $$RitualStepsTableFilterComposer
    extends Composer<_$LoopDatabase, $RitualStepsTable> {
  $$RitualStepsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get routineId => $composableBuilder(
    column: $table.routineId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RitualStepsTableOrderingComposer
    extends Composer<_$LoopDatabase, $RitualStepsTable> {
  $$RitualStepsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get routineId => $composableBuilder(
    column: $table.routineId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RitualStepsTableAnnotationComposer
    extends Composer<_$LoopDatabase, $RitualStepsTable> {
  $$RitualStepsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get routineId =>
      $composableBuilder(column: $table.routineId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);
}

class $$RitualStepsTableTableManager
    extends
        RootTableManager<
          _$LoopDatabase,
          $RitualStepsTable,
          RitualStepRow,
          $$RitualStepsTableFilterComposer,
          $$RitualStepsTableOrderingComposer,
          $$RitualStepsTableAnnotationComposer,
          $$RitualStepsTableCreateCompanionBuilder,
          $$RitualStepsTableUpdateCompanionBuilder,
          (
            RitualStepRow,
            BaseReferences<_$LoopDatabase, $RitualStepsTable, RitualStepRow>,
          ),
          RitualStepRow,
          PrefetchHooks Function()
        > {
  $$RitualStepsTableTableManager(_$LoopDatabase db, $RitualStepsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RitualStepsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RitualStepsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RitualStepsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> routineId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RitualStepsCompanion(
                id: id,
                routineId: routineId,
                title: title,
                note: note,
                icon: icon,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String routineId,
                required String title,
                Value<String> note = const Value.absent(),
                required String icon,
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => RitualStepsCompanion.insert(
                id: id,
                routineId: routineId,
                title: title,
                note: note,
                icon: icon,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RitualStepsTableProcessedTableManager =
    ProcessedTableManager<
      _$LoopDatabase,
      $RitualStepsTable,
      RitualStepRow,
      $$RitualStepsTableFilterComposer,
      $$RitualStepsTableOrderingComposer,
      $$RitualStepsTableAnnotationComposer,
      $$RitualStepsTableCreateCompanionBuilder,
      $$RitualStepsTableUpdateCompanionBuilder,
      (
        RitualStepRow,
        BaseReferences<_$LoopDatabase, $RitualStepsTable, RitualStepRow>,
      ),
      RitualStepRow,
      PrefetchHooks Function()
    >;
typedef $$PalNotesTableCreateCompanionBuilder =
    PalNotesCompanion Function({
      required String id,
      required DateTime createdAt,
      required String kind,
      required String category,
      required String icon,
      required String title,
      required String body,
      Value<String?> actionLabel,
      Value<bool> unread,
      Value<int> rowid,
    });
typedef $$PalNotesTableUpdateCompanionBuilder =
    PalNotesCompanion Function({
      Value<String> id,
      Value<DateTime> createdAt,
      Value<String> kind,
      Value<String> category,
      Value<String> icon,
      Value<String> title,
      Value<String> body,
      Value<String?> actionLabel,
      Value<bool> unread,
      Value<int> rowid,
    });

class $$PalNotesTableFilterComposer
    extends Composer<_$LoopDatabase, $PalNotesTable> {
  $$PalNotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actionLabel => $composableBuilder(
    column: $table.actionLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get unread => $composableBuilder(
    column: $table.unread,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PalNotesTableOrderingComposer
    extends Composer<_$LoopDatabase, $PalNotesTable> {
  $$PalNotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actionLabel => $composableBuilder(
    column: $table.actionLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get unread => $composableBuilder(
    column: $table.unread,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PalNotesTableAnnotationComposer
    extends Composer<_$LoopDatabase, $PalNotesTable> {
  $$PalNotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get actionLabel => $composableBuilder(
    column: $table.actionLabel,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get unread =>
      $composableBuilder(column: $table.unread, builder: (column) => column);
}

class $$PalNotesTableTableManager
    extends
        RootTableManager<
          _$LoopDatabase,
          $PalNotesTable,
          PalNoteRow,
          $$PalNotesTableFilterComposer,
          $$PalNotesTableOrderingComposer,
          $$PalNotesTableAnnotationComposer,
          $$PalNotesTableCreateCompanionBuilder,
          $$PalNotesTableUpdateCompanionBuilder,
          (
            PalNoteRow,
            BaseReferences<_$LoopDatabase, $PalNotesTable, PalNoteRow>,
          ),
          PalNoteRow,
          PrefetchHooks Function()
        > {
  $$PalNotesTableTableManager(_$LoopDatabase db, $PalNotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PalNotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PalNotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PalNotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String?> actionLabel = const Value.absent(),
                Value<bool> unread = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PalNotesCompanion(
                id: id,
                createdAt: createdAt,
                kind: kind,
                category: category,
                icon: icon,
                title: title,
                body: body,
                actionLabel: actionLabel,
                unread: unread,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime createdAt,
                required String kind,
                required String category,
                required String icon,
                required String title,
                required String body,
                Value<String?> actionLabel = const Value.absent(),
                Value<bool> unread = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PalNotesCompanion.insert(
                id: id,
                createdAt: createdAt,
                kind: kind,
                category: category,
                icon: icon,
                title: title,
                body: body,
                actionLabel: actionLabel,
                unread: unread,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PalNotesTableProcessedTableManager =
    ProcessedTableManager<
      _$LoopDatabase,
      $PalNotesTable,
      PalNoteRow,
      $$PalNotesTableFilterComposer,
      $$PalNotesTableOrderingComposer,
      $$PalNotesTableAnnotationComposer,
      $$PalNotesTableCreateCompanionBuilder,
      $$PalNotesTableUpdateCompanionBuilder,
      (PalNoteRow, BaseReferences<_$LoopDatabase, $PalNotesTable, PalNoteRow>),
      PalNoteRow,
      PrefetchHooks Function()
    >;
typedef $$GoalsTableTableCreateCompanionBuilder =
    GoalsTableCompanion Function({
      Value<String> id,
      Value<double> dailyBudget,
      Value<int> dailyMoveKcal,
      Value<int> dailyRitualTarget,
      Value<int> rowid,
    });
typedef $$GoalsTableTableUpdateCompanionBuilder =
    GoalsTableCompanion Function({
      Value<String> id,
      Value<double> dailyBudget,
      Value<int> dailyMoveKcal,
      Value<int> dailyRitualTarget,
      Value<int> rowid,
    });

class $$GoalsTableTableFilterComposer
    extends Composer<_$LoopDatabase, $GoalsTableTable> {
  $$GoalsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get dailyBudget => $composableBuilder(
    column: $table.dailyBudget,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dailyMoveKcal => $composableBuilder(
    column: $table.dailyMoveKcal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dailyRitualTarget => $composableBuilder(
    column: $table.dailyRitualTarget,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GoalsTableTableOrderingComposer
    extends Composer<_$LoopDatabase, $GoalsTableTable> {
  $$GoalsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get dailyBudget => $composableBuilder(
    column: $table.dailyBudget,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dailyMoveKcal => $composableBuilder(
    column: $table.dailyMoveKcal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dailyRitualTarget => $composableBuilder(
    column: $table.dailyRitualTarget,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GoalsTableTableAnnotationComposer
    extends Composer<_$LoopDatabase, $GoalsTableTable> {
  $$GoalsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get dailyBudget => $composableBuilder(
    column: $table.dailyBudget,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dailyMoveKcal => $composableBuilder(
    column: $table.dailyMoveKcal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dailyRitualTarget => $composableBuilder(
    column: $table.dailyRitualTarget,
    builder: (column) => column,
  );
}

class $$GoalsTableTableTableManager
    extends
        RootTableManager<
          _$LoopDatabase,
          $GoalsTableTable,
          GoalsRow,
          $$GoalsTableTableFilterComposer,
          $$GoalsTableTableOrderingComposer,
          $$GoalsTableTableAnnotationComposer,
          $$GoalsTableTableCreateCompanionBuilder,
          $$GoalsTableTableUpdateCompanionBuilder,
          (
            GoalsRow,
            BaseReferences<_$LoopDatabase, $GoalsTableTable, GoalsRow>,
          ),
          GoalsRow,
          PrefetchHooks Function()
        > {
  $$GoalsTableTableTableManager(_$LoopDatabase db, $GoalsTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GoalsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GoalsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GoalsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<double> dailyBudget = const Value.absent(),
                Value<int> dailyMoveKcal = const Value.absent(),
                Value<int> dailyRitualTarget = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GoalsTableCompanion(
                id: id,
                dailyBudget: dailyBudget,
                dailyMoveKcal: dailyMoveKcal,
                dailyRitualTarget: dailyRitualTarget,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<double> dailyBudget = const Value.absent(),
                Value<int> dailyMoveKcal = const Value.absent(),
                Value<int> dailyRitualTarget = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GoalsTableCompanion.insert(
                id: id,
                dailyBudget: dailyBudget,
                dailyMoveKcal: dailyMoveKcal,
                dailyRitualTarget: dailyRitualTarget,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GoalsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$LoopDatabase,
      $GoalsTableTable,
      GoalsRow,
      $$GoalsTableTableFilterComposer,
      $$GoalsTableTableOrderingComposer,
      $$GoalsTableTableAnnotationComposer,
      $$GoalsTableTableCreateCompanionBuilder,
      $$GoalsTableTableUpdateCompanionBuilder,
      (GoalsRow, BaseReferences<_$LoopDatabase, $GoalsTableTable, GoalsRow>),
      GoalsRow,
      PrefetchHooks Function()
    >;
typedef $$SeedMarkersTableCreateCompanionBuilder =
    SeedMarkersCompanion Function({required String key, Value<int> rowid});
typedef $$SeedMarkersTableUpdateCompanionBuilder =
    SeedMarkersCompanion Function({Value<String> key, Value<int> rowid});

class $$SeedMarkersTableFilterComposer
    extends Composer<_$LoopDatabase, $SeedMarkersTable> {
  $$SeedMarkersTableFilterComposer({
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
}

class $$SeedMarkersTableOrderingComposer
    extends Composer<_$LoopDatabase, $SeedMarkersTable> {
  $$SeedMarkersTableOrderingComposer({
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
}

class $$SeedMarkersTableAnnotationComposer
    extends Composer<_$LoopDatabase, $SeedMarkersTable> {
  $$SeedMarkersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);
}

class $$SeedMarkersTableTableManager
    extends
        RootTableManager<
          _$LoopDatabase,
          $SeedMarkersTable,
          SeedMarker,
          $$SeedMarkersTableFilterComposer,
          $$SeedMarkersTableOrderingComposer,
          $$SeedMarkersTableAnnotationComposer,
          $$SeedMarkersTableCreateCompanionBuilder,
          $$SeedMarkersTableUpdateCompanionBuilder,
          (
            SeedMarker,
            BaseReferences<_$LoopDatabase, $SeedMarkersTable, SeedMarker>,
          ),
          SeedMarker,
          PrefetchHooks Function()
        > {
  $$SeedMarkersTableTableManager(_$LoopDatabase db, $SeedMarkersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SeedMarkersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SeedMarkersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SeedMarkersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SeedMarkersCompanion(key: key, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                Value<int> rowid = const Value.absent(),
              }) => SeedMarkersCompanion.insert(key: key, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SeedMarkersTableProcessedTableManager =
    ProcessedTableManager<
      _$LoopDatabase,
      $SeedMarkersTable,
      SeedMarker,
      $$SeedMarkersTableFilterComposer,
      $$SeedMarkersTableOrderingComposer,
      $$SeedMarkersTableAnnotationComposer,
      $$SeedMarkersTableCreateCompanionBuilder,
      $$SeedMarkersTableUpdateCompanionBuilder,
      (
        SeedMarker,
        BaseReferences<_$LoopDatabase, $SeedMarkersTable, SeedMarker>,
      ),
      SeedMarker,
      PrefetchHooks Function()
    >;
typedef $$WeeklyPlanDaysTableCreateCompanionBuilder =
    WeeklyPlanDaysCompanion Function({
      Value<int> weekday,
      Value<String?> routineId,
    });
typedef $$WeeklyPlanDaysTableUpdateCompanionBuilder =
    WeeklyPlanDaysCompanion Function({
      Value<int> weekday,
      Value<String?> routineId,
    });

class $$WeeklyPlanDaysTableFilterComposer
    extends Composer<_$LoopDatabase, $WeeklyPlanDaysTable> {
  $$WeeklyPlanDaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get weekday => $composableBuilder(
    column: $table.weekday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get routineId => $composableBuilder(
    column: $table.routineId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WeeklyPlanDaysTableOrderingComposer
    extends Composer<_$LoopDatabase, $WeeklyPlanDaysTable> {
  $$WeeklyPlanDaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get weekday => $composableBuilder(
    column: $table.weekday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get routineId => $composableBuilder(
    column: $table.routineId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WeeklyPlanDaysTableAnnotationComposer
    extends Composer<_$LoopDatabase, $WeeklyPlanDaysTable> {
  $$WeeklyPlanDaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get weekday =>
      $composableBuilder(column: $table.weekday, builder: (column) => column);

  GeneratedColumn<String> get routineId =>
      $composableBuilder(column: $table.routineId, builder: (column) => column);
}

class $$WeeklyPlanDaysTableTableManager
    extends
        RootTableManager<
          _$LoopDatabase,
          $WeeklyPlanDaysTable,
          WeeklyPlanDayRow,
          $$WeeklyPlanDaysTableFilterComposer,
          $$WeeklyPlanDaysTableOrderingComposer,
          $$WeeklyPlanDaysTableAnnotationComposer,
          $$WeeklyPlanDaysTableCreateCompanionBuilder,
          $$WeeklyPlanDaysTableUpdateCompanionBuilder,
          (
            WeeklyPlanDayRow,
            BaseReferences<
              _$LoopDatabase,
              $WeeklyPlanDaysTable,
              WeeklyPlanDayRow
            >,
          ),
          WeeklyPlanDayRow,
          PrefetchHooks Function()
        > {
  $$WeeklyPlanDaysTableTableManager(
    _$LoopDatabase db,
    $WeeklyPlanDaysTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WeeklyPlanDaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WeeklyPlanDaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WeeklyPlanDaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> weekday = const Value.absent(),
                Value<String?> routineId = const Value.absent(),
              }) => WeeklyPlanDaysCompanion(
                weekday: weekday,
                routineId: routineId,
              ),
          createCompanionCallback:
              ({
                Value<int> weekday = const Value.absent(),
                Value<String?> routineId = const Value.absent(),
              }) => WeeklyPlanDaysCompanion.insert(
                weekday: weekday,
                routineId: routineId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WeeklyPlanDaysTableProcessedTableManager =
    ProcessedTableManager<
      _$LoopDatabase,
      $WeeklyPlanDaysTable,
      WeeklyPlanDayRow,
      $$WeeklyPlanDaysTableFilterComposer,
      $$WeeklyPlanDaysTableOrderingComposer,
      $$WeeklyPlanDaysTableAnnotationComposer,
      $$WeeklyPlanDaysTableCreateCompanionBuilder,
      $$WeeklyPlanDaysTableUpdateCompanionBuilder,
      (
        WeeklyPlanDayRow,
        BaseReferences<_$LoopDatabase, $WeeklyPlanDaysTable, WeeklyPlanDayRow>,
      ),
      WeeklyPlanDayRow,
      PrefetchHooks Function()
    >;
typedef $$BudgetEnvelopesTableCreateCompanionBuilder =
    BudgetEnvelopesCompanion Function({
      required String id,
      required String category,
      required double cap,
      required String icon,
      required String colorToken,
      Value<int> position,
      Value<int> rowid,
    });
typedef $$BudgetEnvelopesTableUpdateCompanionBuilder =
    BudgetEnvelopesCompanion Function({
      Value<String> id,
      Value<String> category,
      Value<double> cap,
      Value<String> icon,
      Value<String> colorToken,
      Value<int> position,
      Value<int> rowid,
    });

class $$BudgetEnvelopesTableFilterComposer
    extends Composer<_$LoopDatabase, $BudgetEnvelopesTable> {
  $$BudgetEnvelopesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get cap => $composableBuilder(
    column: $table.cap,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorToken => $composableBuilder(
    column: $table.colorToken,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BudgetEnvelopesTableOrderingComposer
    extends Composer<_$LoopDatabase, $BudgetEnvelopesTable> {
  $$BudgetEnvelopesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get cap => $composableBuilder(
    column: $table.cap,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorToken => $composableBuilder(
    column: $table.colorToken,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BudgetEnvelopesTableAnnotationComposer
    extends Composer<_$LoopDatabase, $BudgetEnvelopesTable> {
  $$BudgetEnvelopesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<double> get cap =>
      $composableBuilder(column: $table.cap, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get colorToken => $composableBuilder(
    column: $table.colorToken,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);
}

class $$BudgetEnvelopesTableTableManager
    extends
        RootTableManager<
          _$LoopDatabase,
          $BudgetEnvelopesTable,
          BudgetEnvelopeRow,
          $$BudgetEnvelopesTableFilterComposer,
          $$BudgetEnvelopesTableOrderingComposer,
          $$BudgetEnvelopesTableAnnotationComposer,
          $$BudgetEnvelopesTableCreateCompanionBuilder,
          $$BudgetEnvelopesTableUpdateCompanionBuilder,
          (
            BudgetEnvelopeRow,
            BaseReferences<
              _$LoopDatabase,
              $BudgetEnvelopesTable,
              BudgetEnvelopeRow
            >,
          ),
          BudgetEnvelopeRow,
          PrefetchHooks Function()
        > {
  $$BudgetEnvelopesTableTableManager(
    _$LoopDatabase db,
    $BudgetEnvelopesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BudgetEnvelopesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BudgetEnvelopesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BudgetEnvelopesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<double> cap = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<String> colorToken = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BudgetEnvelopesCompanion(
                id: id,
                category: category,
                cap: cap,
                icon: icon,
                colorToken: colorToken,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String category,
                required double cap,
                required String icon,
                required String colorToken,
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BudgetEnvelopesCompanion.insert(
                id: id,
                category: category,
                cap: cap,
                icon: icon,
                colorToken: colorToken,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BudgetEnvelopesTableProcessedTableManager =
    ProcessedTableManager<
      _$LoopDatabase,
      $BudgetEnvelopesTable,
      BudgetEnvelopeRow,
      $$BudgetEnvelopesTableFilterComposer,
      $$BudgetEnvelopesTableOrderingComposer,
      $$BudgetEnvelopesTableAnnotationComposer,
      $$BudgetEnvelopesTableCreateCompanionBuilder,
      $$BudgetEnvelopesTableUpdateCompanionBuilder,
      (
        BudgetEnvelopeRow,
        BaseReferences<
          _$LoopDatabase,
          $BudgetEnvelopesTable,
          BudgetEnvelopeRow
        >,
      ),
      BudgetEnvelopeRow,
      PrefetchHooks Function()
    >;
typedef $$NutritionMealsTableCreateCompanionBuilder =
    NutritionMealsCompanion Function({
      required String id,
      required DateTime timestamp,
      required String slot,
      required String name,
      required String source,
      required String icon,
      required String confidence,
      required int calLo,
      required int calHi,
      required int proteinLo,
      required int proteinHi,
      required int carbsLo,
      required int carbsHi,
      required int fatLo,
      required int fatHi,
      Value<String?> note,
      Value<String> tags,
      Value<String?> linkedEntryId,
      Value<int> rowid,
    });
typedef $$NutritionMealsTableUpdateCompanionBuilder =
    NutritionMealsCompanion Function({
      Value<String> id,
      Value<DateTime> timestamp,
      Value<String> slot,
      Value<String> name,
      Value<String> source,
      Value<String> icon,
      Value<String> confidence,
      Value<int> calLo,
      Value<int> calHi,
      Value<int> proteinLo,
      Value<int> proteinHi,
      Value<int> carbsLo,
      Value<int> carbsHi,
      Value<int> fatLo,
      Value<int> fatHi,
      Value<String?> note,
      Value<String> tags,
      Value<String?> linkedEntryId,
      Value<int> rowid,
    });

class $$NutritionMealsTableFilterComposer
    extends Composer<_$LoopDatabase, $NutritionMealsTable> {
  $$NutritionMealsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get calLo => $composableBuilder(
    column: $table.calLo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get calHi => $composableBuilder(
    column: $table.calHi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get proteinLo => $composableBuilder(
    column: $table.proteinLo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get proteinHi => $composableBuilder(
    column: $table.proteinHi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get carbsLo => $composableBuilder(
    column: $table.carbsLo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get carbsHi => $composableBuilder(
    column: $table.carbsHi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fatLo => $composableBuilder(
    column: $table.fatLo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fatHi => $composableBuilder(
    column: $table.fatHi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linkedEntryId => $composableBuilder(
    column: $table.linkedEntryId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NutritionMealsTableOrderingComposer
    extends Composer<_$LoopDatabase, $NutritionMealsTable> {
  $$NutritionMealsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get calLo => $composableBuilder(
    column: $table.calLo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get calHi => $composableBuilder(
    column: $table.calHi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get proteinLo => $composableBuilder(
    column: $table.proteinLo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get proteinHi => $composableBuilder(
    column: $table.proteinHi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get carbsLo => $composableBuilder(
    column: $table.carbsLo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get carbsHi => $composableBuilder(
    column: $table.carbsHi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fatLo => $composableBuilder(
    column: $table.fatLo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fatHi => $composableBuilder(
    column: $table.fatHi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkedEntryId => $composableBuilder(
    column: $table.linkedEntryId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NutritionMealsTableAnnotationComposer
    extends Composer<_$LoopDatabase, $NutritionMealsTable> {
  $$NutritionMealsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get slot =>
      $composableBuilder(column: $table.slot, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<int> get calLo =>
      $composableBuilder(column: $table.calLo, builder: (column) => column);

  GeneratedColumn<int> get calHi =>
      $composableBuilder(column: $table.calHi, builder: (column) => column);

  GeneratedColumn<int> get proteinLo =>
      $composableBuilder(column: $table.proteinLo, builder: (column) => column);

  GeneratedColumn<int> get proteinHi =>
      $composableBuilder(column: $table.proteinHi, builder: (column) => column);

  GeneratedColumn<int> get carbsLo =>
      $composableBuilder(column: $table.carbsLo, builder: (column) => column);

  GeneratedColumn<int> get carbsHi =>
      $composableBuilder(column: $table.carbsHi, builder: (column) => column);

  GeneratedColumn<int> get fatLo =>
      $composableBuilder(column: $table.fatLo, builder: (column) => column);

  GeneratedColumn<int> get fatHi =>
      $composableBuilder(column: $table.fatHi, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get linkedEntryId => $composableBuilder(
    column: $table.linkedEntryId,
    builder: (column) => column,
  );
}

class $$NutritionMealsTableTableManager
    extends
        RootTableManager<
          _$LoopDatabase,
          $NutritionMealsTable,
          NutritionMealRow,
          $$NutritionMealsTableFilterComposer,
          $$NutritionMealsTableOrderingComposer,
          $$NutritionMealsTableAnnotationComposer,
          $$NutritionMealsTableCreateCompanionBuilder,
          $$NutritionMealsTableUpdateCompanionBuilder,
          (
            NutritionMealRow,
            BaseReferences<
              _$LoopDatabase,
              $NutritionMealsTable,
              NutritionMealRow
            >,
          ),
          NutritionMealRow,
          PrefetchHooks Function()
        > {
  $$NutritionMealsTableTableManager(
    _$LoopDatabase db,
    $NutritionMealsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NutritionMealsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NutritionMealsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NutritionMealsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<String> slot = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<String> confidence = const Value.absent(),
                Value<int> calLo = const Value.absent(),
                Value<int> calHi = const Value.absent(),
                Value<int> proteinLo = const Value.absent(),
                Value<int> proteinHi = const Value.absent(),
                Value<int> carbsLo = const Value.absent(),
                Value<int> carbsHi = const Value.absent(),
                Value<int> fatLo = const Value.absent(),
                Value<int> fatHi = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<String?> linkedEntryId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NutritionMealsCompanion(
                id: id,
                timestamp: timestamp,
                slot: slot,
                name: name,
                source: source,
                icon: icon,
                confidence: confidence,
                calLo: calLo,
                calHi: calHi,
                proteinLo: proteinLo,
                proteinHi: proteinHi,
                carbsLo: carbsLo,
                carbsHi: carbsHi,
                fatLo: fatLo,
                fatHi: fatHi,
                note: note,
                tags: tags,
                linkedEntryId: linkedEntryId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime timestamp,
                required String slot,
                required String name,
                required String source,
                required String icon,
                required String confidence,
                required int calLo,
                required int calHi,
                required int proteinLo,
                required int proteinHi,
                required int carbsLo,
                required int carbsHi,
                required int fatLo,
                required int fatHi,
                Value<String?> note = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<String?> linkedEntryId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NutritionMealsCompanion.insert(
                id: id,
                timestamp: timestamp,
                slot: slot,
                name: name,
                source: source,
                icon: icon,
                confidence: confidence,
                calLo: calLo,
                calHi: calHi,
                proteinLo: proteinLo,
                proteinHi: proteinHi,
                carbsLo: carbsLo,
                carbsHi: carbsHi,
                fatLo: fatLo,
                fatHi: fatHi,
                note: note,
                tags: tags,
                linkedEntryId: linkedEntryId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NutritionMealsTableProcessedTableManager =
    ProcessedTableManager<
      _$LoopDatabase,
      $NutritionMealsTable,
      NutritionMealRow,
      $$NutritionMealsTableFilterComposer,
      $$NutritionMealsTableOrderingComposer,
      $$NutritionMealsTableAnnotationComposer,
      $$NutritionMealsTableCreateCompanionBuilder,
      $$NutritionMealsTableUpdateCompanionBuilder,
      (
        NutritionMealRow,
        BaseReferences<_$LoopDatabase, $NutritionMealsTable, NutritionMealRow>,
      ),
      NutritionMealRow,
      PrefetchHooks Function()
    >;

class $LoopDatabaseManager {
  final _$LoopDatabase _db;
  $LoopDatabaseManager(this._db);
  $$EntriesTableTableManager get entries =>
      $$EntriesTableTableManager(_db, _db.entries);
  $$ExercisesTableTableManager get exercises =>
      $$ExercisesTableTableManager(_db, _db.exercises);
  $$RoutinesTableTableManager get routines =>
      $$RoutinesTableTableManager(_db, _db.routines);
  $$RoutineExercisesTableTableManager get routineExercises =>
      $$RoutineExercisesTableTableManager(_db, _db.routineExercises);
  $$WorkoutsTableTableManager get workouts =>
      $$WorkoutsTableTableManager(_db, _db.workouts);
  $$SetLogsTableTableManager get setLogs =>
      $$SetLogsTableTableManager(_db, _db.setLogs);
  $$RitualRoutinesTableTableManager get ritualRoutines =>
      $$RitualRoutinesTableTableManager(_db, _db.ritualRoutines);
  $$RitualStepsTableTableManager get ritualSteps =>
      $$RitualStepsTableTableManager(_db, _db.ritualSteps);
  $$PalNotesTableTableManager get palNotes =>
      $$PalNotesTableTableManager(_db, _db.palNotes);
  $$GoalsTableTableTableManager get goalsTable =>
      $$GoalsTableTableTableManager(_db, _db.goalsTable);
  $$SeedMarkersTableTableManager get seedMarkers =>
      $$SeedMarkersTableTableManager(_db, _db.seedMarkers);
  $$WeeklyPlanDaysTableTableManager get weeklyPlanDays =>
      $$WeeklyPlanDaysTableTableManager(_db, _db.weeklyPlanDays);
  $$BudgetEnvelopesTableTableManager get budgetEnvelopes =>
      $$BudgetEnvelopesTableTableManager(_db, _db.budgetEnvelopes);
  $$NutritionMealsTableTableManager get nutritionMeals =>
      $$NutritionMealsTableTableManager(_db, _db.nutritionMeals);
}
