// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $FarmsTable extends Farms with TableInfo<$FarmsTable, Farm> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FarmsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _areaCodeMeta = const VerificationMeta(
    'areaCode',
  );
  @override
  late final GeneratedColumn<String> areaCode = GeneratedColumn<String>(
    'area_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _farmerCodeMeta = const VerificationMeta(
    'farmerCode',
  );
  @override
  late final GeneratedColumn<String> farmerCode = GeneratedColumn<String>(
    'farmer_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sizeValueMeta = const VerificationMeta(
    'sizeValue',
  );
  @override
  late final GeneratedColumn<double> sizeValue = GeneratedColumn<double>(
    'size_value',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeUnitMeta = const VerificationMeta(
    'sizeUnit',
  );
  @override
  late final GeneratedColumn<String> sizeUnit = GeneratedColumn<String>(
    'size_unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant("ACRE"),
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lngMeta = const VerificationMeta('lng');
  @override
  late final GeneratedColumn<double> lng = GeneratedColumn<double>(
    'lng',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addressTextMeta = const VerificationMeta(
    'addressText',
  );
  @override
  late final GeneratedColumn<String> addressText = GeneratedColumn<String>(
    'address_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locationPublicLevelMeta =
      const VerificationMeta('locationPublicLevel');
  @override
  late final GeneratedColumn<String> locationPublicLevel =
      GeneratedColumn<String>(
        'location_public_level',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant("DISTRICT"),
      );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  @override
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant("LOCAL"),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    areaCode,
    farmerCode,
    sizeValue,
    sizeUnit,
    lat,
    lng,
    addressText,
    locationPublicLevel,
    syncState,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'farms';
  @override
  VerificationContext validateIntegrity(
    Insertable<Farm> instance, {
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
    if (data.containsKey('area_code')) {
      context.handle(
        _areaCodeMeta,
        areaCode.isAcceptableOrUnknown(data['area_code']!, _areaCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_areaCodeMeta);
    }
    if (data.containsKey('farmer_code')) {
      context.handle(
        _farmerCodeMeta,
        farmerCode.isAcceptableOrUnknown(data['farmer_code']!, _farmerCodeMeta),
      );
    }
    if (data.containsKey('size_value')) {
      context.handle(
        _sizeValueMeta,
        sizeValue.isAcceptableOrUnknown(data['size_value']!, _sizeValueMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeValueMeta);
    }
    if (data.containsKey('size_unit')) {
      context.handle(
        _sizeUnitMeta,
        sizeUnit.isAcceptableOrUnknown(data['size_unit']!, _sizeUnitMeta),
      );
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    }
    if (data.containsKey('lng')) {
      context.handle(
        _lngMeta,
        lng.isAcceptableOrUnknown(data['lng']!, _lngMeta),
      );
    }
    if (data.containsKey('address_text')) {
      context.handle(
        _addressTextMeta,
        addressText.isAcceptableOrUnknown(
          data['address_text']!,
          _addressTextMeta,
        ),
      );
    }
    if (data.containsKey('location_public_level')) {
      context.handle(
        _locationPublicLevelMeta,
        locationPublicLevel.isAcceptableOrUnknown(
          data['location_public_level']!,
          _locationPublicLevelMeta,
        ),
      );
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Farm map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Farm(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      areaCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}area_code'],
      )!,
      farmerCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}farmer_code'],
      ),
      sizeValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}size_value'],
      )!,
      sizeUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}size_unit'],
      )!,
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      ),
      lng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lng'],
      ),
      addressText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address_text'],
      ),
      locationPublicLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_public_level'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $FarmsTable createAlias(String alias) {
    return $FarmsTable(attachedDatabase, alias);
  }
}

class Farm extends DataClass implements Insertable<Farm> {
  /// UUIDv7, client-generated so outbox payloads can reference the farm
  /// before the server knows about it.
  final String id;
  final String name;
  final String areaCode;
  final String? farmerCode;
  final double sizeValue;
  final String sizeUnit;
  final double? lat;
  final double? lng;
  final String? addressText;
  final String locationPublicLevel;
  final String syncState;
  final DateTime createdAt;
  const Farm({
    required this.id,
    required this.name,
    required this.areaCode,
    this.farmerCode,
    required this.sizeValue,
    required this.sizeUnit,
    this.lat,
    this.lng,
    this.addressText,
    required this.locationPublicLevel,
    required this.syncState,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['area_code'] = Variable<String>(areaCode);
    if (!nullToAbsent || farmerCode != null) {
      map['farmer_code'] = Variable<String>(farmerCode);
    }
    map['size_value'] = Variable<double>(sizeValue);
    map['size_unit'] = Variable<String>(sizeUnit);
    if (!nullToAbsent || lat != null) {
      map['lat'] = Variable<double>(lat);
    }
    if (!nullToAbsent || lng != null) {
      map['lng'] = Variable<double>(lng);
    }
    if (!nullToAbsent || addressText != null) {
      map['address_text'] = Variable<String>(addressText);
    }
    map['location_public_level'] = Variable<String>(locationPublicLevel);
    map['sync_state'] = Variable<String>(syncState);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  FarmsCompanion toCompanion(bool nullToAbsent) {
    return FarmsCompanion(
      id: Value(id),
      name: Value(name),
      areaCode: Value(areaCode),
      farmerCode: farmerCode == null && nullToAbsent
          ? const Value.absent()
          : Value(farmerCode),
      sizeValue: Value(sizeValue),
      sizeUnit: Value(sizeUnit),
      lat: lat == null && nullToAbsent ? const Value.absent() : Value(lat),
      lng: lng == null && nullToAbsent ? const Value.absent() : Value(lng),
      addressText: addressText == null && nullToAbsent
          ? const Value.absent()
          : Value(addressText),
      locationPublicLevel: Value(locationPublicLevel),
      syncState: Value(syncState),
      createdAt: Value(createdAt),
    );
  }

  factory Farm.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Farm(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      areaCode: serializer.fromJson<String>(json['areaCode']),
      farmerCode: serializer.fromJson<String?>(json['farmerCode']),
      sizeValue: serializer.fromJson<double>(json['sizeValue']),
      sizeUnit: serializer.fromJson<String>(json['sizeUnit']),
      lat: serializer.fromJson<double?>(json['lat']),
      lng: serializer.fromJson<double?>(json['lng']),
      addressText: serializer.fromJson<String?>(json['addressText']),
      locationPublicLevel: serializer.fromJson<String>(
        json['locationPublicLevel'],
      ),
      syncState: serializer.fromJson<String>(json['syncState']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'areaCode': serializer.toJson<String>(areaCode),
      'farmerCode': serializer.toJson<String?>(farmerCode),
      'sizeValue': serializer.toJson<double>(sizeValue),
      'sizeUnit': serializer.toJson<String>(sizeUnit),
      'lat': serializer.toJson<double?>(lat),
      'lng': serializer.toJson<double?>(lng),
      'addressText': serializer.toJson<String?>(addressText),
      'locationPublicLevel': serializer.toJson<String>(locationPublicLevel),
      'syncState': serializer.toJson<String>(syncState),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Farm copyWith({
    String? id,
    String? name,
    String? areaCode,
    Value<String?> farmerCode = const Value.absent(),
    double? sizeValue,
    String? sizeUnit,
    Value<double?> lat = const Value.absent(),
    Value<double?> lng = const Value.absent(),
    Value<String?> addressText = const Value.absent(),
    String? locationPublicLevel,
    String? syncState,
    DateTime? createdAt,
  }) => Farm(
    id: id ?? this.id,
    name: name ?? this.name,
    areaCode: areaCode ?? this.areaCode,
    farmerCode: farmerCode.present ? farmerCode.value : this.farmerCode,
    sizeValue: sizeValue ?? this.sizeValue,
    sizeUnit: sizeUnit ?? this.sizeUnit,
    lat: lat.present ? lat.value : this.lat,
    lng: lng.present ? lng.value : this.lng,
    addressText: addressText.present ? addressText.value : this.addressText,
    locationPublicLevel: locationPublicLevel ?? this.locationPublicLevel,
    syncState: syncState ?? this.syncState,
    createdAt: createdAt ?? this.createdAt,
  );
  Farm copyWithCompanion(FarmsCompanion data) {
    return Farm(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      areaCode: data.areaCode.present ? data.areaCode.value : this.areaCode,
      farmerCode: data.farmerCode.present
          ? data.farmerCode.value
          : this.farmerCode,
      sizeValue: data.sizeValue.present ? data.sizeValue.value : this.sizeValue,
      sizeUnit: data.sizeUnit.present ? data.sizeUnit.value : this.sizeUnit,
      lat: data.lat.present ? data.lat.value : this.lat,
      lng: data.lng.present ? data.lng.value : this.lng,
      addressText: data.addressText.present
          ? data.addressText.value
          : this.addressText,
      locationPublicLevel: data.locationPublicLevel.present
          ? data.locationPublicLevel.value
          : this.locationPublicLevel,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Farm(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('areaCode: $areaCode, ')
          ..write('farmerCode: $farmerCode, ')
          ..write('sizeValue: $sizeValue, ')
          ..write('sizeUnit: $sizeUnit, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('addressText: $addressText, ')
          ..write('locationPublicLevel: $locationPublicLevel, ')
          ..write('syncState: $syncState, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    areaCode,
    farmerCode,
    sizeValue,
    sizeUnit,
    lat,
    lng,
    addressText,
    locationPublicLevel,
    syncState,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Farm &&
          other.id == this.id &&
          other.name == this.name &&
          other.areaCode == this.areaCode &&
          other.farmerCode == this.farmerCode &&
          other.sizeValue == this.sizeValue &&
          other.sizeUnit == this.sizeUnit &&
          other.lat == this.lat &&
          other.lng == this.lng &&
          other.addressText == this.addressText &&
          other.locationPublicLevel == this.locationPublicLevel &&
          other.syncState == this.syncState &&
          other.createdAt == this.createdAt);
}

class FarmsCompanion extends UpdateCompanion<Farm> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> areaCode;
  final Value<String?> farmerCode;
  final Value<double> sizeValue;
  final Value<String> sizeUnit;
  final Value<double?> lat;
  final Value<double?> lng;
  final Value<String?> addressText;
  final Value<String> locationPublicLevel;
  final Value<String> syncState;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const FarmsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.areaCode = const Value.absent(),
    this.farmerCode = const Value.absent(),
    this.sizeValue = const Value.absent(),
    this.sizeUnit = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.addressText = const Value.absent(),
    this.locationPublicLevel = const Value.absent(),
    this.syncState = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FarmsCompanion.insert({
    required String id,
    required String name,
    required String areaCode,
    this.farmerCode = const Value.absent(),
    required double sizeValue,
    this.sizeUnit = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.addressText = const Value.absent(),
    this.locationPublicLevel = const Value.absent(),
    this.syncState = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       areaCode = Value(areaCode),
       sizeValue = Value(sizeValue),
       createdAt = Value(createdAt);
  static Insertable<Farm> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? areaCode,
    Expression<String>? farmerCode,
    Expression<double>? sizeValue,
    Expression<String>? sizeUnit,
    Expression<double>? lat,
    Expression<double>? lng,
    Expression<String>? addressText,
    Expression<String>? locationPublicLevel,
    Expression<String>? syncState,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (areaCode != null) 'area_code': areaCode,
      if (farmerCode != null) 'farmer_code': farmerCode,
      if (sizeValue != null) 'size_value': sizeValue,
      if (sizeUnit != null) 'size_unit': sizeUnit,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (addressText != null) 'address_text': addressText,
      if (locationPublicLevel != null)
        'location_public_level': locationPublicLevel,
      if (syncState != null) 'sync_state': syncState,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FarmsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? areaCode,
    Value<String?>? farmerCode,
    Value<double>? sizeValue,
    Value<String>? sizeUnit,
    Value<double?>? lat,
    Value<double?>? lng,
    Value<String?>? addressText,
    Value<String>? locationPublicLevel,
    Value<String>? syncState,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return FarmsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      areaCode: areaCode ?? this.areaCode,
      farmerCode: farmerCode ?? this.farmerCode,
      sizeValue: sizeValue ?? this.sizeValue,
      sizeUnit: sizeUnit ?? this.sizeUnit,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      addressText: addressText ?? this.addressText,
      locationPublicLevel: locationPublicLevel ?? this.locationPublicLevel,
      syncState: syncState ?? this.syncState,
      createdAt: createdAt ?? this.createdAt,
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
    if (areaCode.present) {
      map['area_code'] = Variable<String>(areaCode.value);
    }
    if (farmerCode.present) {
      map['farmer_code'] = Variable<String>(farmerCode.value);
    }
    if (sizeValue.present) {
      map['size_value'] = Variable<double>(sizeValue.value);
    }
    if (sizeUnit.present) {
      map['size_unit'] = Variable<String>(sizeUnit.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lng.present) {
      map['lng'] = Variable<double>(lng.value);
    }
    if (addressText.present) {
      map['address_text'] = Variable<String>(addressText.value);
    }
    if (locationPublicLevel.present) {
      map['location_public_level'] = Variable<String>(
        locationPublicLevel.value,
      );
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FarmsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('areaCode: $areaCode, ')
          ..write('farmerCode: $farmerCode, ')
          ..write('sizeValue: $sizeValue, ')
          ..write('sizeUnit: $sizeUnit, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('addressText: $addressText, ')
          ..write('locationPublicLevel: $locationPublicLevel, ')
          ..write('syncState: $syncState, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BatchesTable extends Batches with TableInfo<$BatchesTable, Batch> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BatchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _batchNoMeta = const VerificationMeta(
    'batchNo',
  );
  @override
  late final GeneratedColumn<String> batchNo = GeneratedColumn<String>(
    'batch_no',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _farmIdMeta = const VerificationMeta('farmId');
  @override
  late final GeneratedColumn<String> farmId = GeneratedColumn<String>(
    'farm_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _harvestTypeMeta = const VerificationMeta(
    'harvestType',
  );
  @override
  late final GeneratedColumn<String> harvestType = GeneratedColumn<String>(
    'harvest_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _harvestDateMeta = const VerificationMeta(
    'harvestDate',
  );
  @override
  late final GeneratedColumn<String> harvestDate = GeneratedColumn<String>(
    'harvest_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _treeCountMeta = const VerificationMeta(
    'treeCount',
  );
  @override
  late final GeneratedColumn<int> treeCount = GeneratedColumn<int>(
    'tree_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant("HARVESTED"),
  );
  static const VerificationMeta _currentHolderIdMeta = const VerificationMeta(
    'currentHolderId',
  );
  @override
  late final GeneratedColumn<String> currentHolderId = GeneratedColumn<String>(
    'current_holder_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currentHolderRoleMeta = const VerificationMeta(
    'currentHolderRole',
  );
  @override
  late final GeneratedColumn<String> currentHolderRole =
      GeneratedColumn<String>(
        'current_holder_role',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _rootBatchNoMeta = const VerificationMeta(
    'rootBatchNo',
  );
  @override
  late final GeneratedColumn<String> rootBatchNo = GeneratedColumn<String>(
    'root_batch_no',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stageSuffixMeta = const VerificationMeta(
    'stageSuffix',
  );
  @override
  late final GeneratedColumn<String> stageSuffix = GeneratedColumn<String>(
    'stage_suffix',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(""),
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  @override
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant("LOCAL"),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    batchNo,
    farmId,
    harvestType,
    harvestDate,
    treeCount,
    weightKg,
    status,
    currentHolderId,
    currentHolderRole,
    rootBatchNo,
    stageSuffix,
    syncState,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'batches';
  @override
  VerificationContext validateIntegrity(
    Insertable<Batch> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('batch_no')) {
      context.handle(
        _batchNoMeta,
        batchNo.isAcceptableOrUnknown(data['batch_no']!, _batchNoMeta),
      );
    } else if (isInserting) {
      context.missing(_batchNoMeta);
    }
    if (data.containsKey('farm_id')) {
      context.handle(
        _farmIdMeta,
        farmId.isAcceptableOrUnknown(data['farm_id']!, _farmIdMeta),
      );
    } else if (isInserting) {
      context.missing(_farmIdMeta);
    }
    if (data.containsKey('harvest_type')) {
      context.handle(
        _harvestTypeMeta,
        harvestType.isAcceptableOrUnknown(
          data['harvest_type']!,
          _harvestTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_harvestTypeMeta);
    }
    if (data.containsKey('harvest_date')) {
      context.handle(
        _harvestDateMeta,
        harvestDate.isAcceptableOrUnknown(
          data['harvest_date']!,
          _harvestDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_harvestDateMeta);
    }
    if (data.containsKey('tree_count')) {
      context.handle(
        _treeCountMeta,
        treeCount.isAcceptableOrUnknown(data['tree_count']!, _treeCountMeta),
      );
    } else if (isInserting) {
      context.missing(_treeCountMeta);
    }
    if (data.containsKey('weight_kg')) {
      context.handle(
        _weightKgMeta,
        weightKg.isAcceptableOrUnknown(data['weight_kg']!, _weightKgMeta),
      );
    } else if (isInserting) {
      context.missing(_weightKgMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('current_holder_id')) {
      context.handle(
        _currentHolderIdMeta,
        currentHolderId.isAcceptableOrUnknown(
          data['current_holder_id']!,
          _currentHolderIdMeta,
        ),
      );
    }
    if (data.containsKey('current_holder_role')) {
      context.handle(
        _currentHolderRoleMeta,
        currentHolderRole.isAcceptableOrUnknown(
          data['current_holder_role']!,
          _currentHolderRoleMeta,
        ),
      );
    }
    if (data.containsKey('root_batch_no')) {
      context.handle(
        _rootBatchNoMeta,
        rootBatchNo.isAcceptableOrUnknown(
          data['root_batch_no']!,
          _rootBatchNoMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rootBatchNoMeta);
    }
    if (data.containsKey('stage_suffix')) {
      context.handle(
        _stageSuffixMeta,
        stageSuffix.isAcceptableOrUnknown(
          data['stage_suffix']!,
          _stageSuffixMeta,
        ),
      );
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Batch map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Batch(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      batchNo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}batch_no'],
      )!,
      farmId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}farm_id'],
      )!,
      harvestType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}harvest_type'],
      )!,
      harvestDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}harvest_date'],
      )!,
      treeCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tree_count'],
      )!,
      weightKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight_kg'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      currentHolderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_holder_id'],
      ),
      currentHolderRole: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_holder_role'],
      ),
      rootBatchNo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}root_batch_no'],
      )!,
      stageSuffix: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stage_suffix'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BatchesTable createAlias(String alias) {
    return $BatchesTable(attachedDatabase, alias);
  }
}

class Batch extends DataClass implements Insertable<Batch> {
  /// UUIDv7, client-generated.
  final String id;

  /// Unique locally too — catches same-device dupes; collisions with other
  /// devices surface as 409 BATCH_NO_TAKEN and are regenerated by the worker.
  final String batchNo;
  final String farmId;
  final String harvestType;
  final String harvestDate;
  final int treeCount;
  final double weightKg;
  final String status;
  final String? currentHolderId;
  final String? currentHolderRole;
  final String rootBatchNo;
  final String stageSuffix;
  final String syncState;
  final DateTime createdAt;
  const Batch({
    required this.id,
    required this.batchNo,
    required this.farmId,
    required this.harvestType,
    required this.harvestDate,
    required this.treeCount,
    required this.weightKg,
    required this.status,
    this.currentHolderId,
    this.currentHolderRole,
    required this.rootBatchNo,
    required this.stageSuffix,
    required this.syncState,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['batch_no'] = Variable<String>(batchNo);
    map['farm_id'] = Variable<String>(farmId);
    map['harvest_type'] = Variable<String>(harvestType);
    map['harvest_date'] = Variable<String>(harvestDate);
    map['tree_count'] = Variable<int>(treeCount);
    map['weight_kg'] = Variable<double>(weightKg);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || currentHolderId != null) {
      map['current_holder_id'] = Variable<String>(currentHolderId);
    }
    if (!nullToAbsent || currentHolderRole != null) {
      map['current_holder_role'] = Variable<String>(currentHolderRole);
    }
    map['root_batch_no'] = Variable<String>(rootBatchNo);
    map['stage_suffix'] = Variable<String>(stageSuffix);
    map['sync_state'] = Variable<String>(syncState);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BatchesCompanion toCompanion(bool nullToAbsent) {
    return BatchesCompanion(
      id: Value(id),
      batchNo: Value(batchNo),
      farmId: Value(farmId),
      harvestType: Value(harvestType),
      harvestDate: Value(harvestDate),
      treeCount: Value(treeCount),
      weightKg: Value(weightKg),
      status: Value(status),
      currentHolderId: currentHolderId == null && nullToAbsent
          ? const Value.absent()
          : Value(currentHolderId),
      currentHolderRole: currentHolderRole == null && nullToAbsent
          ? const Value.absent()
          : Value(currentHolderRole),
      rootBatchNo: Value(rootBatchNo),
      stageSuffix: Value(stageSuffix),
      syncState: Value(syncState),
      createdAt: Value(createdAt),
    );
  }

  factory Batch.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Batch(
      id: serializer.fromJson<String>(json['id']),
      batchNo: serializer.fromJson<String>(json['batchNo']),
      farmId: serializer.fromJson<String>(json['farmId']),
      harvestType: serializer.fromJson<String>(json['harvestType']),
      harvestDate: serializer.fromJson<String>(json['harvestDate']),
      treeCount: serializer.fromJson<int>(json['treeCount']),
      weightKg: serializer.fromJson<double>(json['weightKg']),
      status: serializer.fromJson<String>(json['status']),
      currentHolderId: serializer.fromJson<String?>(json['currentHolderId']),
      currentHolderRole: serializer.fromJson<String?>(
        json['currentHolderRole'],
      ),
      rootBatchNo: serializer.fromJson<String>(json['rootBatchNo']),
      stageSuffix: serializer.fromJson<String>(json['stageSuffix']),
      syncState: serializer.fromJson<String>(json['syncState']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'batchNo': serializer.toJson<String>(batchNo),
      'farmId': serializer.toJson<String>(farmId),
      'harvestType': serializer.toJson<String>(harvestType),
      'harvestDate': serializer.toJson<String>(harvestDate),
      'treeCount': serializer.toJson<int>(treeCount),
      'weightKg': serializer.toJson<double>(weightKg),
      'status': serializer.toJson<String>(status),
      'currentHolderId': serializer.toJson<String?>(currentHolderId),
      'currentHolderRole': serializer.toJson<String?>(currentHolderRole),
      'rootBatchNo': serializer.toJson<String>(rootBatchNo),
      'stageSuffix': serializer.toJson<String>(stageSuffix),
      'syncState': serializer.toJson<String>(syncState),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Batch copyWith({
    String? id,
    String? batchNo,
    String? farmId,
    String? harvestType,
    String? harvestDate,
    int? treeCount,
    double? weightKg,
    String? status,
    Value<String?> currentHolderId = const Value.absent(),
    Value<String?> currentHolderRole = const Value.absent(),
    String? rootBatchNo,
    String? stageSuffix,
    String? syncState,
    DateTime? createdAt,
  }) => Batch(
    id: id ?? this.id,
    batchNo: batchNo ?? this.batchNo,
    farmId: farmId ?? this.farmId,
    harvestType: harvestType ?? this.harvestType,
    harvestDate: harvestDate ?? this.harvestDate,
    treeCount: treeCount ?? this.treeCount,
    weightKg: weightKg ?? this.weightKg,
    status: status ?? this.status,
    currentHolderId: currentHolderId.present
        ? currentHolderId.value
        : this.currentHolderId,
    currentHolderRole: currentHolderRole.present
        ? currentHolderRole.value
        : this.currentHolderRole,
    rootBatchNo: rootBatchNo ?? this.rootBatchNo,
    stageSuffix: stageSuffix ?? this.stageSuffix,
    syncState: syncState ?? this.syncState,
    createdAt: createdAt ?? this.createdAt,
  );
  Batch copyWithCompanion(BatchesCompanion data) {
    return Batch(
      id: data.id.present ? data.id.value : this.id,
      batchNo: data.batchNo.present ? data.batchNo.value : this.batchNo,
      farmId: data.farmId.present ? data.farmId.value : this.farmId,
      harvestType: data.harvestType.present
          ? data.harvestType.value
          : this.harvestType,
      harvestDate: data.harvestDate.present
          ? data.harvestDate.value
          : this.harvestDate,
      treeCount: data.treeCount.present ? data.treeCount.value : this.treeCount,
      weightKg: data.weightKg.present ? data.weightKg.value : this.weightKg,
      status: data.status.present ? data.status.value : this.status,
      currentHolderId: data.currentHolderId.present
          ? data.currentHolderId.value
          : this.currentHolderId,
      currentHolderRole: data.currentHolderRole.present
          ? data.currentHolderRole.value
          : this.currentHolderRole,
      rootBatchNo: data.rootBatchNo.present
          ? data.rootBatchNo.value
          : this.rootBatchNo,
      stageSuffix: data.stageSuffix.present
          ? data.stageSuffix.value
          : this.stageSuffix,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Batch(')
          ..write('id: $id, ')
          ..write('batchNo: $batchNo, ')
          ..write('farmId: $farmId, ')
          ..write('harvestType: $harvestType, ')
          ..write('harvestDate: $harvestDate, ')
          ..write('treeCount: $treeCount, ')
          ..write('weightKg: $weightKg, ')
          ..write('status: $status, ')
          ..write('currentHolderId: $currentHolderId, ')
          ..write('currentHolderRole: $currentHolderRole, ')
          ..write('rootBatchNo: $rootBatchNo, ')
          ..write('stageSuffix: $stageSuffix, ')
          ..write('syncState: $syncState, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    batchNo,
    farmId,
    harvestType,
    harvestDate,
    treeCount,
    weightKg,
    status,
    currentHolderId,
    currentHolderRole,
    rootBatchNo,
    stageSuffix,
    syncState,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Batch &&
          other.id == this.id &&
          other.batchNo == this.batchNo &&
          other.farmId == this.farmId &&
          other.harvestType == this.harvestType &&
          other.harvestDate == this.harvestDate &&
          other.treeCount == this.treeCount &&
          other.weightKg == this.weightKg &&
          other.status == this.status &&
          other.currentHolderId == this.currentHolderId &&
          other.currentHolderRole == this.currentHolderRole &&
          other.rootBatchNo == this.rootBatchNo &&
          other.stageSuffix == this.stageSuffix &&
          other.syncState == this.syncState &&
          other.createdAt == this.createdAt);
}

class BatchesCompanion extends UpdateCompanion<Batch> {
  final Value<String> id;
  final Value<String> batchNo;
  final Value<String> farmId;
  final Value<String> harvestType;
  final Value<String> harvestDate;
  final Value<int> treeCount;
  final Value<double> weightKg;
  final Value<String> status;
  final Value<String?> currentHolderId;
  final Value<String?> currentHolderRole;
  final Value<String> rootBatchNo;
  final Value<String> stageSuffix;
  final Value<String> syncState;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const BatchesCompanion({
    this.id = const Value.absent(),
    this.batchNo = const Value.absent(),
    this.farmId = const Value.absent(),
    this.harvestType = const Value.absent(),
    this.harvestDate = const Value.absent(),
    this.treeCount = const Value.absent(),
    this.weightKg = const Value.absent(),
    this.status = const Value.absent(),
    this.currentHolderId = const Value.absent(),
    this.currentHolderRole = const Value.absent(),
    this.rootBatchNo = const Value.absent(),
    this.stageSuffix = const Value.absent(),
    this.syncState = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BatchesCompanion.insert({
    required String id,
    required String batchNo,
    required String farmId,
    required String harvestType,
    required String harvestDate,
    required int treeCount,
    required double weightKg,
    this.status = const Value.absent(),
    this.currentHolderId = const Value.absent(),
    this.currentHolderRole = const Value.absent(),
    required String rootBatchNo,
    this.stageSuffix = const Value.absent(),
    this.syncState = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       batchNo = Value(batchNo),
       farmId = Value(farmId),
       harvestType = Value(harvestType),
       harvestDate = Value(harvestDate),
       treeCount = Value(treeCount),
       weightKg = Value(weightKg),
       rootBatchNo = Value(rootBatchNo),
       createdAt = Value(createdAt);
  static Insertable<Batch> custom({
    Expression<String>? id,
    Expression<String>? batchNo,
    Expression<String>? farmId,
    Expression<String>? harvestType,
    Expression<String>? harvestDate,
    Expression<int>? treeCount,
    Expression<double>? weightKg,
    Expression<String>? status,
    Expression<String>? currentHolderId,
    Expression<String>? currentHolderRole,
    Expression<String>? rootBatchNo,
    Expression<String>? stageSuffix,
    Expression<String>? syncState,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (batchNo != null) 'batch_no': batchNo,
      if (farmId != null) 'farm_id': farmId,
      if (harvestType != null) 'harvest_type': harvestType,
      if (harvestDate != null) 'harvest_date': harvestDate,
      if (treeCount != null) 'tree_count': treeCount,
      if (weightKg != null) 'weight_kg': weightKg,
      if (status != null) 'status': status,
      if (currentHolderId != null) 'current_holder_id': currentHolderId,
      if (currentHolderRole != null) 'current_holder_role': currentHolderRole,
      if (rootBatchNo != null) 'root_batch_no': rootBatchNo,
      if (stageSuffix != null) 'stage_suffix': stageSuffix,
      if (syncState != null) 'sync_state': syncState,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BatchesCompanion copyWith({
    Value<String>? id,
    Value<String>? batchNo,
    Value<String>? farmId,
    Value<String>? harvestType,
    Value<String>? harvestDate,
    Value<int>? treeCount,
    Value<double>? weightKg,
    Value<String>? status,
    Value<String?>? currentHolderId,
    Value<String?>? currentHolderRole,
    Value<String>? rootBatchNo,
    Value<String>? stageSuffix,
    Value<String>? syncState,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return BatchesCompanion(
      id: id ?? this.id,
      batchNo: batchNo ?? this.batchNo,
      farmId: farmId ?? this.farmId,
      harvestType: harvestType ?? this.harvestType,
      harvestDate: harvestDate ?? this.harvestDate,
      treeCount: treeCount ?? this.treeCount,
      weightKg: weightKg ?? this.weightKg,
      status: status ?? this.status,
      currentHolderId: currentHolderId ?? this.currentHolderId,
      currentHolderRole: currentHolderRole ?? this.currentHolderRole,
      rootBatchNo: rootBatchNo ?? this.rootBatchNo,
      stageSuffix: stageSuffix ?? this.stageSuffix,
      syncState: syncState ?? this.syncState,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (batchNo.present) {
      map['batch_no'] = Variable<String>(batchNo.value);
    }
    if (farmId.present) {
      map['farm_id'] = Variable<String>(farmId.value);
    }
    if (harvestType.present) {
      map['harvest_type'] = Variable<String>(harvestType.value);
    }
    if (harvestDate.present) {
      map['harvest_date'] = Variable<String>(harvestDate.value);
    }
    if (treeCount.present) {
      map['tree_count'] = Variable<int>(treeCount.value);
    }
    if (weightKg.present) {
      map['weight_kg'] = Variable<double>(weightKg.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (currentHolderId.present) {
      map['current_holder_id'] = Variable<String>(currentHolderId.value);
    }
    if (currentHolderRole.present) {
      map['current_holder_role'] = Variable<String>(currentHolderRole.value);
    }
    if (rootBatchNo.present) {
      map['root_batch_no'] = Variable<String>(rootBatchNo.value);
    }
    if (stageSuffix.present) {
      map['stage_suffix'] = Variable<String>(stageSuffix.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BatchesCompanion(')
          ..write('id: $id, ')
          ..write('batchNo: $batchNo, ')
          ..write('farmId: $farmId, ')
          ..write('harvestType: $harvestType, ')
          ..write('harvestDate: $harvestDate, ')
          ..write('treeCount: $treeCount, ')
          ..write('weightKg: $weightKg, ')
          ..write('status: $status, ')
          ..write('currentHolderId: $currentHolderId, ')
          ..write('currentHolderRole: $currentHolderRole, ')
          ..write('rootBatchNo: $rootBatchNo, ')
          ..write('stageSuffix: $stageSuffix, ')
          ..write('syncState: $syncState, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SeqCountersTable extends SeqCounters
    with TableInfo<$SeqCountersTable, SeqCounter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SeqCountersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _farmIdMeta = const VerificationMeta('farmId');
  @override
  late final GeneratedColumn<String> farmId = GeneratedColumn<String>(
    'farm_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayKeyMeta = const VerificationMeta('dayKey');
  @override
  late final GeneratedColumn<String> dayKey = GeneratedColumn<String>(
    'day_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeqMeta = const VerificationMeta(
    'lastSeq',
  );
  @override
  late final GeneratedColumn<int> lastSeq = GeneratedColumn<int>(
    'last_seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [farmId, dayKey, lastSeq];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'seq_counters';
  @override
  VerificationContext validateIntegrity(
    Insertable<SeqCounter> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('farm_id')) {
      context.handle(
        _farmIdMeta,
        farmId.isAcceptableOrUnknown(data['farm_id']!, _farmIdMeta),
      );
    } else if (isInserting) {
      context.missing(_farmIdMeta);
    }
    if (data.containsKey('day_key')) {
      context.handle(
        _dayKeyMeta,
        dayKey.isAcceptableOrUnknown(data['day_key']!, _dayKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dayKeyMeta);
    }
    if (data.containsKey('last_seq')) {
      context.handle(
        _lastSeqMeta,
        lastSeq.isAcceptableOrUnknown(data['last_seq']!, _lastSeqMeta),
      );
    } else if (isInserting) {
      context.missing(_lastSeqMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {farmId, dayKey};
  @override
  SeqCounter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SeqCounter(
      farmId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}farm_id'],
      )!,
      dayKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_key'],
      )!,
      lastSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_seq'],
      )!,
    );
  }

  @override
  $SeqCountersTable createAlias(String alias) {
    return $SeqCountersTable(attachedDatabase, alias);
  }
}

class SeqCounter extends DataClass implements Insertable<SeqCounter> {
  final String farmId;
  final String dayKey;
  final int lastSeq;
  const SeqCounter({
    required this.farmId,
    required this.dayKey,
    required this.lastSeq,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['farm_id'] = Variable<String>(farmId);
    map['day_key'] = Variable<String>(dayKey);
    map['last_seq'] = Variable<int>(lastSeq);
    return map;
  }

  SeqCountersCompanion toCompanion(bool nullToAbsent) {
    return SeqCountersCompanion(
      farmId: Value(farmId),
      dayKey: Value(dayKey),
      lastSeq: Value(lastSeq),
    );
  }

  factory SeqCounter.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SeqCounter(
      farmId: serializer.fromJson<String>(json['farmId']),
      dayKey: serializer.fromJson<String>(json['dayKey']),
      lastSeq: serializer.fromJson<int>(json['lastSeq']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'farmId': serializer.toJson<String>(farmId),
      'dayKey': serializer.toJson<String>(dayKey),
      'lastSeq': serializer.toJson<int>(lastSeq),
    };
  }

  SeqCounter copyWith({String? farmId, String? dayKey, int? lastSeq}) =>
      SeqCounter(
        farmId: farmId ?? this.farmId,
        dayKey: dayKey ?? this.dayKey,
        lastSeq: lastSeq ?? this.lastSeq,
      );
  SeqCounter copyWithCompanion(SeqCountersCompanion data) {
    return SeqCounter(
      farmId: data.farmId.present ? data.farmId.value : this.farmId,
      dayKey: data.dayKey.present ? data.dayKey.value : this.dayKey,
      lastSeq: data.lastSeq.present ? data.lastSeq.value : this.lastSeq,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SeqCounter(')
          ..write('farmId: $farmId, ')
          ..write('dayKey: $dayKey, ')
          ..write('lastSeq: $lastSeq')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(farmId, dayKey, lastSeq);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SeqCounter &&
          other.farmId == this.farmId &&
          other.dayKey == this.dayKey &&
          other.lastSeq == this.lastSeq);
}

class SeqCountersCompanion extends UpdateCompanion<SeqCounter> {
  final Value<String> farmId;
  final Value<String> dayKey;
  final Value<int> lastSeq;
  final Value<int> rowid;
  const SeqCountersCompanion({
    this.farmId = const Value.absent(),
    this.dayKey = const Value.absent(),
    this.lastSeq = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SeqCountersCompanion.insert({
    required String farmId,
    required String dayKey,
    required int lastSeq,
    this.rowid = const Value.absent(),
  }) : farmId = Value(farmId),
       dayKey = Value(dayKey),
       lastSeq = Value(lastSeq);
  static Insertable<SeqCounter> custom({
    Expression<String>? farmId,
    Expression<String>? dayKey,
    Expression<int>? lastSeq,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (farmId != null) 'farm_id': farmId,
      if (dayKey != null) 'day_key': dayKey,
      if (lastSeq != null) 'last_seq': lastSeq,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SeqCountersCompanion copyWith({
    Value<String>? farmId,
    Value<String>? dayKey,
    Value<int>? lastSeq,
    Value<int>? rowid,
  }) {
    return SeqCountersCompanion(
      farmId: farmId ?? this.farmId,
      dayKey: dayKey ?? this.dayKey,
      lastSeq: lastSeq ?? this.lastSeq,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (farmId.present) {
      map['farm_id'] = Variable<String>(farmId.value);
    }
    if (dayKey.present) {
      map['day_key'] = Variable<String>(dayKey.value);
    }
    if (lastSeq.present) {
      map['last_seq'] = Variable<int>(lastSeq.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SeqCountersCompanion(')
          ..write('farmId: $farmId, ')
          ..write('dayKey: $dayKey, ')
          ..write('lastSeq: $lastSeq, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<String> method = GeneratedColumn<String>(
    'method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idempotencyKeyMeta = const VerificationMeta(
    'idempotencyKey',
  );
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
    'idempotency_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dependsOnMeta = const VerificationMeta(
    'dependsOn',
  );
  @override
  late final GeneratedColumn<int> dependsOn = GeneratedColumn<int>(
    'depends_on',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant("PENDING"),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _regenCountMeta = const VerificationMeta(
    'regenCount',
  );
  @override
  late final GeneratedColumn<int> regenCount = GeneratedColumn<int>(
    'regen_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextRetryAtMeta = const VerificationMeta(
    'nextRetryAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextRetryAt = GeneratedColumn<DateTime>(
    'next_retry_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorCodeMeta = const VerificationMeta(
    'lastErrorCode',
  );
  @override
  late final GeneratedColumn<String> lastErrorCode = GeneratedColumn<String>(
    'last_error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entityType,
    entityId,
    method,
    path,
    payloadJson,
    idempotencyKey,
    dependsOn,
    status,
    attempts,
    regenCount,
    nextRetryAt,
    lastErrorCode,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('method')) {
      context.handle(
        _methodMeta,
        method.isAcceptableOrUnknown(data['method']!, _methodMeta),
      );
    } else if (isInserting) {
      context.missing(_methodMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
        _idempotencyKeyMeta,
        idempotencyKey.isAcceptableOrUnknown(
          data['idempotency_key']!,
          _idempotencyKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_idempotencyKeyMeta);
    }
    if (data.containsKey('depends_on')) {
      context.handle(
        _dependsOnMeta,
        dependsOn.isAcceptableOrUnknown(data['depends_on']!, _dependsOnMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('regen_count')) {
      context.handle(
        _regenCountMeta,
        regenCount.isAcceptableOrUnknown(data['regen_count']!, _regenCountMeta),
      );
    }
    if (data.containsKey('next_retry_at')) {
      context.handle(
        _nextRetryAtMeta,
        nextRetryAt.isAcceptableOrUnknown(
          data['next_retry_at']!,
          _nextRetryAtMeta,
        ),
      );
    }
    if (data.containsKey('last_error_code')) {
      context.handle(
        _lastErrorCodeMeta,
        lastErrorCode.isAcceptableOrUnknown(
          data['last_error_code']!,
          _lastErrorCodeMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      method: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}method'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      idempotencyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idempotency_key'],
      )!,
      dependsOn: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}depends_on'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      regenCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}regen_count'],
      )!,
      nextRetryAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_retry_at'],
      ),
      lastErrorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error_code'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxRow extends DataClass implements Insertable<OutboxRow> {
  final int id;
  final String entityType;
  final String entityId;
  final String method;
  final String path;
  final String payloadJson;

  /// uuid v4, stable per entry; rotated when a 409 regenerates the payload.
  final String idempotencyKey;

  /// outbox.id of a prerequisite entry that must reach SYNCED first.
  final int? dependsOn;
  final String status;
  final int attempts;
  final int regenCount;
  final DateTime? nextRetryAt;
  final String? lastErrorCode;
  final DateTime createdAt;
  const OutboxRow({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.method,
    required this.path,
    required this.payloadJson,
    required this.idempotencyKey,
    this.dependsOn,
    required this.status,
    required this.attempts,
    required this.regenCount,
    this.nextRetryAt,
    this.lastErrorCode,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['method'] = Variable<String>(method);
    map['path'] = Variable<String>(path);
    map['payload_json'] = Variable<String>(payloadJson);
    map['idempotency_key'] = Variable<String>(idempotencyKey);
    if (!nullToAbsent || dependsOn != null) {
      map['depends_on'] = Variable<int>(dependsOn);
    }
    map['status'] = Variable<String>(status);
    map['attempts'] = Variable<int>(attempts);
    map['regen_count'] = Variable<int>(regenCount);
    if (!nullToAbsent || nextRetryAt != null) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt);
    }
    if (!nullToAbsent || lastErrorCode != null) {
      map['last_error_code'] = Variable<String>(lastErrorCode);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      id: Value(id),
      entityType: Value(entityType),
      entityId: Value(entityId),
      method: Value(method),
      path: Value(path),
      payloadJson: Value(payloadJson),
      idempotencyKey: Value(idempotencyKey),
      dependsOn: dependsOn == null && nullToAbsent
          ? const Value.absent()
          : Value(dependsOn),
      status: Value(status),
      attempts: Value(attempts),
      regenCount: Value(regenCount),
      nextRetryAt: nextRetryAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextRetryAt),
      lastErrorCode: lastErrorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(lastErrorCode),
      createdAt: Value(createdAt),
    );
  }

  factory OutboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxRow(
      id: serializer.fromJson<int>(json['id']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      method: serializer.fromJson<String>(json['method']),
      path: serializer.fromJson<String>(json['path']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      idempotencyKey: serializer.fromJson<String>(json['idempotencyKey']),
      dependsOn: serializer.fromJson<int?>(json['dependsOn']),
      status: serializer.fromJson<String>(json['status']),
      attempts: serializer.fromJson<int>(json['attempts']),
      regenCount: serializer.fromJson<int>(json['regenCount']),
      nextRetryAt: serializer.fromJson<DateTime?>(json['nextRetryAt']),
      lastErrorCode: serializer.fromJson<String?>(json['lastErrorCode']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'method': serializer.toJson<String>(method),
      'path': serializer.toJson<String>(path),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'idempotencyKey': serializer.toJson<String>(idempotencyKey),
      'dependsOn': serializer.toJson<int?>(dependsOn),
      'status': serializer.toJson<String>(status),
      'attempts': serializer.toJson<int>(attempts),
      'regenCount': serializer.toJson<int>(regenCount),
      'nextRetryAt': serializer.toJson<DateTime?>(nextRetryAt),
      'lastErrorCode': serializer.toJson<String?>(lastErrorCode),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  OutboxRow copyWith({
    int? id,
    String? entityType,
    String? entityId,
    String? method,
    String? path,
    String? payloadJson,
    String? idempotencyKey,
    Value<int?> dependsOn = const Value.absent(),
    String? status,
    int? attempts,
    int? regenCount,
    Value<DateTime?> nextRetryAt = const Value.absent(),
    Value<String?> lastErrorCode = const Value.absent(),
    DateTime? createdAt,
  }) => OutboxRow(
    id: id ?? this.id,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    method: method ?? this.method,
    path: path ?? this.path,
    payloadJson: payloadJson ?? this.payloadJson,
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    dependsOn: dependsOn.present ? dependsOn.value : this.dependsOn,
    status: status ?? this.status,
    attempts: attempts ?? this.attempts,
    regenCount: regenCount ?? this.regenCount,
    nextRetryAt: nextRetryAt.present ? nextRetryAt.value : this.nextRetryAt,
    lastErrorCode: lastErrorCode.present
        ? lastErrorCode.value
        : this.lastErrorCode,
    createdAt: createdAt ?? this.createdAt,
  );
  OutboxRow copyWithCompanion(OutboxCompanion data) {
    return OutboxRow(
      id: data.id.present ? data.id.value : this.id,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      method: data.method.present ? data.method.value : this.method,
      path: data.path.present ? data.path.value : this.path,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      dependsOn: data.dependsOn.present ? data.dependsOn.value : this.dependsOn,
      status: data.status.present ? data.status.value : this.status,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      regenCount: data.regenCount.present
          ? data.regenCount.value
          : this.regenCount,
      nextRetryAt: data.nextRetryAt.present
          ? data.nextRetryAt.value
          : this.nextRetryAt,
      lastErrorCode: data.lastErrorCode.present
          ? data.lastErrorCode.value
          : this.lastErrorCode,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxRow(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('method: $method, ')
          ..write('path: $path, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('dependsOn: $dependsOn, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('regenCount: $regenCount, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('lastErrorCode: $lastErrorCode, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entityType,
    entityId,
    method,
    path,
    payloadJson,
    idempotencyKey,
    dependsOn,
    status,
    attempts,
    regenCount,
    nextRetryAt,
    lastErrorCode,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxRow &&
          other.id == this.id &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.method == this.method &&
          other.path == this.path &&
          other.payloadJson == this.payloadJson &&
          other.idempotencyKey == this.idempotencyKey &&
          other.dependsOn == this.dependsOn &&
          other.status == this.status &&
          other.attempts == this.attempts &&
          other.regenCount == this.regenCount &&
          other.nextRetryAt == this.nextRetryAt &&
          other.lastErrorCode == this.lastErrorCode &&
          other.createdAt == this.createdAt);
}

class OutboxCompanion extends UpdateCompanion<OutboxRow> {
  final Value<int> id;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> method;
  final Value<String> path;
  final Value<String> payloadJson;
  final Value<String> idempotencyKey;
  final Value<int?> dependsOn;
  final Value<String> status;
  final Value<int> attempts;
  final Value<int> regenCount;
  final Value<DateTime?> nextRetryAt;
  final Value<String?> lastErrorCode;
  final Value<DateTime> createdAt;
  const OutboxCompanion({
    this.id = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.method = const Value.absent(),
    this.path = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.dependsOn = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.regenCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.lastErrorCode = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  OutboxCompanion.insert({
    this.id = const Value.absent(),
    required String entityType,
    required String entityId,
    required String method,
    required String path,
    required String payloadJson,
    required String idempotencyKey,
    this.dependsOn = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.regenCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.lastErrorCode = const Value.absent(),
    required DateTime createdAt,
  }) : entityType = Value(entityType),
       entityId = Value(entityId),
       method = Value(method),
       path = Value(path),
       payloadJson = Value(payloadJson),
       idempotencyKey = Value(idempotencyKey),
       createdAt = Value(createdAt);
  static Insertable<OutboxRow> custom({
    Expression<int>? id,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? method,
    Expression<String>? path,
    Expression<String>? payloadJson,
    Expression<String>? idempotencyKey,
    Expression<int>? dependsOn,
    Expression<String>? status,
    Expression<int>? attempts,
    Expression<int>? regenCount,
    Expression<DateTime>? nextRetryAt,
    Expression<String>? lastErrorCode,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (method != null) 'method': method,
      if (path != null) 'path': path,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (dependsOn != null) 'depends_on': dependsOn,
      if (status != null) 'status': status,
      if (attempts != null) 'attempts': attempts,
      if (regenCount != null) 'regen_count': regenCount,
      if (nextRetryAt != null) 'next_retry_at': nextRetryAt,
      if (lastErrorCode != null) 'last_error_code': lastErrorCode,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  OutboxCompanion copyWith({
    Value<int>? id,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? method,
    Value<String>? path,
    Value<String>? payloadJson,
    Value<String>? idempotencyKey,
    Value<int?>? dependsOn,
    Value<String>? status,
    Value<int>? attempts,
    Value<int>? regenCount,
    Value<DateTime?>? nextRetryAt,
    Value<String?>? lastErrorCode,
    Value<DateTime>? createdAt,
  }) {
    return OutboxCompanion(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      method: method ?? this.method,
      path: path ?? this.path,
      payloadJson: payloadJson ?? this.payloadJson,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      dependsOn: dependsOn ?? this.dependsOn,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      regenCount: regenCount ?? this.regenCount,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      lastErrorCode: lastErrorCode ?? this.lastErrorCode,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(method.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (dependsOn.present) {
      map['depends_on'] = Variable<int>(dependsOn.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (regenCount.present) {
      map['regen_count'] = Variable<int>(regenCount.value);
    }
    if (nextRetryAt.present) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt.value);
    }
    if (lastErrorCode.present) {
      map['last_error_code'] = Variable<String>(lastErrorCode.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('method: $method, ')
          ..write('path: $path, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('dependsOn: $dependsOn, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('regenCount: $regenCount, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('lastErrorCode: $lastErrorCode, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $MetaKvTable extends MetaKv with TableInfo<$MetaKvTable, MetaKvEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetaKvTable(this.attachedDatabase, [this._alias]);
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
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meta_kv';
  @override
  VerificationContext validateIntegrity(
    Insertable<MetaKvEntry> instance, {
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
  MetaKvEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetaKvEntry(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $MetaKvTable createAlias(String alias) {
    return $MetaKvTable(attachedDatabase, alias);
  }
}

class MetaKvEntry extends DataClass implements Insertable<MetaKvEntry> {
  final String key;
  final String value;
  const MetaKvEntry({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  MetaKvCompanion toCompanion(bool nullToAbsent) {
    return MetaKvCompanion(key: Value(key), value: Value(value));
  }

  factory MetaKvEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetaKvEntry(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  MetaKvEntry copyWith({String? key, String? value}) =>
      MetaKvEntry(key: key ?? this.key, value: value ?? this.value);
  MetaKvEntry copyWithCompanion(MetaKvCompanion data) {
    return MetaKvEntry(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetaKvEntry(')
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
      (other is MetaKvEntry &&
          other.key == this.key &&
          other.value == this.value);
}

class MetaKvCompanion extends UpdateCompanion<MetaKvEntry> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const MetaKvCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MetaKvCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<MetaKvEntry> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MetaKvCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return MetaKvCompanion(
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
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetaKvCompanion(')
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
  late final $FarmsTable farms = $FarmsTable(this);
  late final $BatchesTable batches = $BatchesTable(this);
  late final $SeqCountersTable seqCounters = $SeqCountersTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $MetaKvTable metaKv = $MetaKvTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    farms,
    batches,
    seqCounters,
    outbox,
    metaKv,
  ];
}

typedef $$FarmsTableCreateCompanionBuilder =
    FarmsCompanion Function({
      required String id,
      required String name,
      required String areaCode,
      Value<String?> farmerCode,
      required double sizeValue,
      Value<String> sizeUnit,
      Value<double?> lat,
      Value<double?> lng,
      Value<String?> addressText,
      Value<String> locationPublicLevel,
      Value<String> syncState,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$FarmsTableUpdateCompanionBuilder =
    FarmsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> areaCode,
      Value<String?> farmerCode,
      Value<double> sizeValue,
      Value<String> sizeUnit,
      Value<double?> lat,
      Value<double?> lng,
      Value<String?> addressText,
      Value<String> locationPublicLevel,
      Value<String> syncState,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$FarmsTableFilterComposer extends Composer<_$AppDatabase, $FarmsTable> {
  $$FarmsTableFilterComposer({
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

  ColumnFilters<String> get areaCode => $composableBuilder(
    column: $table.areaCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get farmerCode => $composableBuilder(
    column: $table.farmerCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sizeValue => $composableBuilder(
    column: $table.sizeValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sizeUnit => $composableBuilder(
    column: $table.sizeUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get addressText => $composableBuilder(
    column: $table.addressText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locationPublicLevel => $composableBuilder(
    column: $table.locationPublicLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FarmsTableOrderingComposer
    extends Composer<_$AppDatabase, $FarmsTable> {
  $$FarmsTableOrderingComposer({
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

  ColumnOrderings<String> get areaCode => $composableBuilder(
    column: $table.areaCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get farmerCode => $composableBuilder(
    column: $table.farmerCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sizeValue => $composableBuilder(
    column: $table.sizeValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sizeUnit => $composableBuilder(
    column: $table.sizeUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get addressText => $composableBuilder(
    column: $table.addressText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locationPublicLevel => $composableBuilder(
    column: $table.locationPublicLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FarmsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FarmsTable> {
  $$FarmsTableAnnotationComposer({
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

  GeneratedColumn<String> get areaCode =>
      $composableBuilder(column: $table.areaCode, builder: (column) => column);

  GeneratedColumn<String> get farmerCode => $composableBuilder(
    column: $table.farmerCode,
    builder: (column) => column,
  );

  GeneratedColumn<double> get sizeValue =>
      $composableBuilder(column: $table.sizeValue, builder: (column) => column);

  GeneratedColumn<String> get sizeUnit =>
      $composableBuilder(column: $table.sizeUnit, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lng =>
      $composableBuilder(column: $table.lng, builder: (column) => column);

  GeneratedColumn<String> get addressText => $composableBuilder(
    column: $table.addressText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get locationPublicLevel => $composableBuilder(
    column: $table.locationPublicLevel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$FarmsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FarmsTable,
          Farm,
          $$FarmsTableFilterComposer,
          $$FarmsTableOrderingComposer,
          $$FarmsTableAnnotationComposer,
          $$FarmsTableCreateCompanionBuilder,
          $$FarmsTableUpdateCompanionBuilder,
          (Farm, BaseReferences<_$AppDatabase, $FarmsTable, Farm>),
          Farm,
          PrefetchHooks Function()
        > {
  $$FarmsTableTableManager(_$AppDatabase db, $FarmsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FarmsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FarmsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FarmsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> areaCode = const Value.absent(),
                Value<String?> farmerCode = const Value.absent(),
                Value<double> sizeValue = const Value.absent(),
                Value<String> sizeUnit = const Value.absent(),
                Value<double?> lat = const Value.absent(),
                Value<double?> lng = const Value.absent(),
                Value<String?> addressText = const Value.absent(),
                Value<String> locationPublicLevel = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FarmsCompanion(
                id: id,
                name: name,
                areaCode: areaCode,
                farmerCode: farmerCode,
                sizeValue: sizeValue,
                sizeUnit: sizeUnit,
                lat: lat,
                lng: lng,
                addressText: addressText,
                locationPublicLevel: locationPublicLevel,
                syncState: syncState,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String areaCode,
                Value<String?> farmerCode = const Value.absent(),
                required double sizeValue,
                Value<String> sizeUnit = const Value.absent(),
                Value<double?> lat = const Value.absent(),
                Value<double?> lng = const Value.absent(),
                Value<String?> addressText = const Value.absent(),
                Value<String> locationPublicLevel = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => FarmsCompanion.insert(
                id: id,
                name: name,
                areaCode: areaCode,
                farmerCode: farmerCode,
                sizeValue: sizeValue,
                sizeUnit: sizeUnit,
                lat: lat,
                lng: lng,
                addressText: addressText,
                locationPublicLevel: locationPublicLevel,
                syncState: syncState,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FarmsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FarmsTable,
      Farm,
      $$FarmsTableFilterComposer,
      $$FarmsTableOrderingComposer,
      $$FarmsTableAnnotationComposer,
      $$FarmsTableCreateCompanionBuilder,
      $$FarmsTableUpdateCompanionBuilder,
      (Farm, BaseReferences<_$AppDatabase, $FarmsTable, Farm>),
      Farm,
      PrefetchHooks Function()
    >;
typedef $$BatchesTableCreateCompanionBuilder =
    BatchesCompanion Function({
      required String id,
      required String batchNo,
      required String farmId,
      required String harvestType,
      required String harvestDate,
      required int treeCount,
      required double weightKg,
      Value<String> status,
      Value<String?> currentHolderId,
      Value<String?> currentHolderRole,
      required String rootBatchNo,
      Value<String> stageSuffix,
      Value<String> syncState,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$BatchesTableUpdateCompanionBuilder =
    BatchesCompanion Function({
      Value<String> id,
      Value<String> batchNo,
      Value<String> farmId,
      Value<String> harvestType,
      Value<String> harvestDate,
      Value<int> treeCount,
      Value<double> weightKg,
      Value<String> status,
      Value<String?> currentHolderId,
      Value<String?> currentHolderRole,
      Value<String> rootBatchNo,
      Value<String> stageSuffix,
      Value<String> syncState,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$BatchesTableFilterComposer
    extends Composer<_$AppDatabase, $BatchesTable> {
  $$BatchesTableFilterComposer({
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

  ColumnFilters<String> get batchNo => $composableBuilder(
    column: $table.batchNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get farmId => $composableBuilder(
    column: $table.farmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get harvestType => $composableBuilder(
    column: $table.harvestType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get harvestDate => $composableBuilder(
    column: $table.harvestDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get treeCount => $composableBuilder(
    column: $table.treeCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currentHolderId => $composableBuilder(
    column: $table.currentHolderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currentHolderRole => $composableBuilder(
    column: $table.currentHolderRole,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rootBatchNo => $composableBuilder(
    column: $table.rootBatchNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stageSuffix => $composableBuilder(
    column: $table.stageSuffix,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BatchesTableOrderingComposer
    extends Composer<_$AppDatabase, $BatchesTable> {
  $$BatchesTableOrderingComposer({
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

  ColumnOrderings<String> get batchNo => $composableBuilder(
    column: $table.batchNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get farmId => $composableBuilder(
    column: $table.farmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get harvestType => $composableBuilder(
    column: $table.harvestType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get harvestDate => $composableBuilder(
    column: $table.harvestDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get treeCount => $composableBuilder(
    column: $table.treeCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currentHolderId => $composableBuilder(
    column: $table.currentHolderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currentHolderRole => $composableBuilder(
    column: $table.currentHolderRole,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rootBatchNo => $composableBuilder(
    column: $table.rootBatchNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stageSuffix => $composableBuilder(
    column: $table.stageSuffix,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BatchesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BatchesTable> {
  $$BatchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get batchNo =>
      $composableBuilder(column: $table.batchNo, builder: (column) => column);

  GeneratedColumn<String> get farmId =>
      $composableBuilder(column: $table.farmId, builder: (column) => column);

  GeneratedColumn<String> get harvestType => $composableBuilder(
    column: $table.harvestType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get harvestDate => $composableBuilder(
    column: $table.harvestDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get treeCount =>
      $composableBuilder(column: $table.treeCount, builder: (column) => column);

  GeneratedColumn<double> get weightKg =>
      $composableBuilder(column: $table.weightKg, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get currentHolderId => $composableBuilder(
    column: $table.currentHolderId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currentHolderRole => $composableBuilder(
    column: $table.currentHolderRole,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rootBatchNo => $composableBuilder(
    column: $table.rootBatchNo,
    builder: (column) => column,
  );

  GeneratedColumn<String> get stageSuffix => $composableBuilder(
    column: $table.stageSuffix,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$BatchesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BatchesTable,
          Batch,
          $$BatchesTableFilterComposer,
          $$BatchesTableOrderingComposer,
          $$BatchesTableAnnotationComposer,
          $$BatchesTableCreateCompanionBuilder,
          $$BatchesTableUpdateCompanionBuilder,
          (Batch, BaseReferences<_$AppDatabase, $BatchesTable, Batch>),
          Batch,
          PrefetchHooks Function()
        > {
  $$BatchesTableTableManager(_$AppDatabase db, $BatchesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BatchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BatchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BatchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> batchNo = const Value.absent(),
                Value<String> farmId = const Value.absent(),
                Value<String> harvestType = const Value.absent(),
                Value<String> harvestDate = const Value.absent(),
                Value<int> treeCount = const Value.absent(),
                Value<double> weightKg = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> currentHolderId = const Value.absent(),
                Value<String?> currentHolderRole = const Value.absent(),
                Value<String> rootBatchNo = const Value.absent(),
                Value<String> stageSuffix = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BatchesCompanion(
                id: id,
                batchNo: batchNo,
                farmId: farmId,
                harvestType: harvestType,
                harvestDate: harvestDate,
                treeCount: treeCount,
                weightKg: weightKg,
                status: status,
                currentHolderId: currentHolderId,
                currentHolderRole: currentHolderRole,
                rootBatchNo: rootBatchNo,
                stageSuffix: stageSuffix,
                syncState: syncState,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String batchNo,
                required String farmId,
                required String harvestType,
                required String harvestDate,
                required int treeCount,
                required double weightKg,
                Value<String> status = const Value.absent(),
                Value<String?> currentHolderId = const Value.absent(),
                Value<String?> currentHolderRole = const Value.absent(),
                required String rootBatchNo,
                Value<String> stageSuffix = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => BatchesCompanion.insert(
                id: id,
                batchNo: batchNo,
                farmId: farmId,
                harvestType: harvestType,
                harvestDate: harvestDate,
                treeCount: treeCount,
                weightKg: weightKg,
                status: status,
                currentHolderId: currentHolderId,
                currentHolderRole: currentHolderRole,
                rootBatchNo: rootBatchNo,
                stageSuffix: stageSuffix,
                syncState: syncState,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BatchesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BatchesTable,
      Batch,
      $$BatchesTableFilterComposer,
      $$BatchesTableOrderingComposer,
      $$BatchesTableAnnotationComposer,
      $$BatchesTableCreateCompanionBuilder,
      $$BatchesTableUpdateCompanionBuilder,
      (Batch, BaseReferences<_$AppDatabase, $BatchesTable, Batch>),
      Batch,
      PrefetchHooks Function()
    >;
typedef $$SeqCountersTableCreateCompanionBuilder =
    SeqCountersCompanion Function({
      required String farmId,
      required String dayKey,
      required int lastSeq,
      Value<int> rowid,
    });
typedef $$SeqCountersTableUpdateCompanionBuilder =
    SeqCountersCompanion Function({
      Value<String> farmId,
      Value<String> dayKey,
      Value<int> lastSeq,
      Value<int> rowid,
    });

class $$SeqCountersTableFilterComposer
    extends Composer<_$AppDatabase, $SeqCountersTable> {
  $$SeqCountersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get farmId => $composableBuilder(
    column: $table.farmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dayKey => $composableBuilder(
    column: $table.dayKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSeq => $composableBuilder(
    column: $table.lastSeq,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SeqCountersTableOrderingComposer
    extends Composer<_$AppDatabase, $SeqCountersTable> {
  $$SeqCountersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get farmId => $composableBuilder(
    column: $table.farmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dayKey => $composableBuilder(
    column: $table.dayKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSeq => $composableBuilder(
    column: $table.lastSeq,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SeqCountersTableAnnotationComposer
    extends Composer<_$AppDatabase, $SeqCountersTable> {
  $$SeqCountersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get farmId =>
      $composableBuilder(column: $table.farmId, builder: (column) => column);

  GeneratedColumn<String> get dayKey =>
      $composableBuilder(column: $table.dayKey, builder: (column) => column);

  GeneratedColumn<int> get lastSeq =>
      $composableBuilder(column: $table.lastSeq, builder: (column) => column);
}

class $$SeqCountersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SeqCountersTable,
          SeqCounter,
          $$SeqCountersTableFilterComposer,
          $$SeqCountersTableOrderingComposer,
          $$SeqCountersTableAnnotationComposer,
          $$SeqCountersTableCreateCompanionBuilder,
          $$SeqCountersTableUpdateCompanionBuilder,
          (
            SeqCounter,
            BaseReferences<_$AppDatabase, $SeqCountersTable, SeqCounter>,
          ),
          SeqCounter,
          PrefetchHooks Function()
        > {
  $$SeqCountersTableTableManager(_$AppDatabase db, $SeqCountersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SeqCountersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SeqCountersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SeqCountersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> farmId = const Value.absent(),
                Value<String> dayKey = const Value.absent(),
                Value<int> lastSeq = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SeqCountersCompanion(
                farmId: farmId,
                dayKey: dayKey,
                lastSeq: lastSeq,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String farmId,
                required String dayKey,
                required int lastSeq,
                Value<int> rowid = const Value.absent(),
              }) => SeqCountersCompanion.insert(
                farmId: farmId,
                dayKey: dayKey,
                lastSeq: lastSeq,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SeqCountersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SeqCountersTable,
      SeqCounter,
      $$SeqCountersTableFilterComposer,
      $$SeqCountersTableOrderingComposer,
      $$SeqCountersTableAnnotationComposer,
      $$SeqCountersTableCreateCompanionBuilder,
      $$SeqCountersTableUpdateCompanionBuilder,
      (
        SeqCounter,
        BaseReferences<_$AppDatabase, $SeqCountersTable, SeqCounter>,
      ),
      SeqCounter,
      PrefetchHooks Function()
    >;
typedef $$OutboxTableCreateCompanionBuilder =
    OutboxCompanion Function({
      Value<int> id,
      required String entityType,
      required String entityId,
      required String method,
      required String path,
      required String payloadJson,
      required String idempotencyKey,
      Value<int?> dependsOn,
      Value<String> status,
      Value<int> attempts,
      Value<int> regenCount,
      Value<DateTime?> nextRetryAt,
      Value<String?> lastErrorCode,
      required DateTime createdAt,
    });
typedef $$OutboxTableUpdateCompanionBuilder =
    OutboxCompanion Function({
      Value<int> id,
      Value<String> entityType,
      Value<String> entityId,
      Value<String> method,
      Value<String> path,
      Value<String> payloadJson,
      Value<String> idempotencyKey,
      Value<int?> dependsOn,
      Value<String> status,
      Value<int> attempts,
      Value<int> regenCount,
      Value<DateTime?> nextRetryAt,
      Value<String?> lastErrorCode,
      Value<DateTime> createdAt,
    });

class $$OutboxTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
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

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dependsOn => $composableBuilder(
    column: $table.dependsOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get regenCount => $composableBuilder(
    column: $table.regenCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
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

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dependsOn => $composableBuilder(
    column: $table.dependsOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get regenCount => $composableBuilder(
    column: $table.regenCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dependsOn =>
      $composableBuilder(column: $table.dependsOn, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<int> get regenCount => $composableBuilder(
    column: $table.regenCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxTable,
          OutboxRow,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (OutboxRow, BaseReferences<_$AppDatabase, $OutboxTable, OutboxRow>),
          OutboxRow,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$AppDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> method = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String> idempotencyKey = const Value.absent(),
                Value<int?> dependsOn = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int> regenCount = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
                Value<String?> lastErrorCode = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => OutboxCompanion(
                id: id,
                entityType: entityType,
                entityId: entityId,
                method: method,
                path: path,
                payloadJson: payloadJson,
                idempotencyKey: idempotencyKey,
                dependsOn: dependsOn,
                status: status,
                attempts: attempts,
                regenCount: regenCount,
                nextRetryAt: nextRetryAt,
                lastErrorCode: lastErrorCode,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String entityType,
                required String entityId,
                required String method,
                required String path,
                required String payloadJson,
                required String idempotencyKey,
                Value<int?> dependsOn = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int> regenCount = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
                Value<String?> lastErrorCode = const Value.absent(),
                required DateTime createdAt,
              }) => OutboxCompanion.insert(
                id: id,
                entityType: entityType,
                entityId: entityId,
                method: method,
                path: path,
                payloadJson: payloadJson,
                idempotencyKey: idempotencyKey,
                dependsOn: dependsOn,
                status: status,
                attempts: attempts,
                regenCount: regenCount,
                nextRetryAt: nextRetryAt,
                lastErrorCode: lastErrorCode,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxTable,
      OutboxRow,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (OutboxRow, BaseReferences<_$AppDatabase, $OutboxTable, OutboxRow>),
      OutboxRow,
      PrefetchHooks Function()
    >;
typedef $$MetaKvTableCreateCompanionBuilder =
    MetaKvCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$MetaKvTableUpdateCompanionBuilder =
    MetaKvCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$MetaKvTableFilterComposer
    extends Composer<_$AppDatabase, $MetaKvTable> {
  $$MetaKvTableFilterComposer({
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

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MetaKvTableOrderingComposer
    extends Composer<_$AppDatabase, $MetaKvTable> {
  $$MetaKvTableOrderingComposer({
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

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MetaKvTableAnnotationComposer
    extends Composer<_$AppDatabase, $MetaKvTable> {
  $$MetaKvTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$MetaKvTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MetaKvTable,
          MetaKvEntry,
          $$MetaKvTableFilterComposer,
          $$MetaKvTableOrderingComposer,
          $$MetaKvTableAnnotationComposer,
          $$MetaKvTableCreateCompanionBuilder,
          $$MetaKvTableUpdateCompanionBuilder,
          (
            MetaKvEntry,
            BaseReferences<_$AppDatabase, $MetaKvTable, MetaKvEntry>,
          ),
          MetaKvEntry,
          PrefetchHooks Function()
        > {
  $$MetaKvTableTableManager(_$AppDatabase db, $MetaKvTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetaKvTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetaKvTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MetaKvTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MetaKvCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) =>
                  MetaKvCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MetaKvTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MetaKvTable,
      MetaKvEntry,
      $$MetaKvTableFilterComposer,
      $$MetaKvTableOrderingComposer,
      $$MetaKvTableAnnotationComposer,
      $$MetaKvTableCreateCompanionBuilder,
      $$MetaKvTableUpdateCompanionBuilder,
      (MetaKvEntry, BaseReferences<_$AppDatabase, $MetaKvTable, MetaKvEntry>),
      MetaKvEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$FarmsTableTableManager get farms =>
      $$FarmsTableTableManager(_db, _db.farms);
  $$BatchesTableTableManager get batches =>
      $$BatchesTableTableManager(_db, _db.batches);
  $$SeqCountersTableTableManager get seqCounters =>
      $$SeqCountersTableTableManager(_db, _db.seqCounters);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$MetaKvTableTableManager get metaKv =>
      $$MetaKvTableTableManager(_db, _db.metaKv);
}
