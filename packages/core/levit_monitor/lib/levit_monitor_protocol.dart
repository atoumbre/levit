/// Platform-independent, immutable wire format for the local Levit inspector.
library;

import 'dart:convert';
import 'dart:collection';

/// A JSON-only envelope. No live reactive, dependency or application object is
/// retained. Redaction must happen before construction, at the producer boundary.
final class LevitEventEnvelope {
  final Map<String, dynamic> data;
  LevitEventEnvelope._(this.data);

  /// Captures a scalar state update using a shared immutable field layout.
  /// Values are already redacted strings; no application object is retained.
  factory LevitEventEnvelope.stateChange({
    required String sessionId,
    required int seq,
    required String timestamp,
    required String reactiveId,
    required String? name,
    required String? ownerId,
    required bool isSensitive,
    required String? oldValue,
    required String? newValue,
    required String valueType,
    String? stackTrace,
  }) => LevitEventEnvelope._(
    _StateChangeFields([
      seq,
      timestamp,
      sessionId,
      reactiveId,
      name,
      ownerId,
      isSensitive,
      'state_change',
      oldValue,
      newValue,
      valueType,
      false,
      'state',
      if (stackTrace != null) stackTrace,
    ]),
  );

  /// Copies and deeply freezes [data]. [category] supplies a default only when
  /// the input has no category, without constructing an intermediate map.
  LevitEventEnvelope(Map<String, dynamic> data, {String? category})
    : data =
          _freeze(data, HashSet<Object>.identity(), category: category)
              as Map<String, dynamic>;

  /// Builds a detached envelope without copying an intermediate root map.
  /// Each field is deeply captured when assigned. The supplied map seals when
  /// [build] returns or throws, so retaining it cannot mutate the envelope.
  /// Returning a different map uses the ordinary defensive-copy constructor.
  factory LevitEventEnvelope.capture(
    Map<String, dynamic> Function(Map<String, dynamic> fields) build, {
    String? category,
  }) {
    final fields = _EnvelopeFields();
    try {
      final result = build(fields);
      if (!identical(result, fields)) {
        return LevitEventEnvelope(result, category: category);
      }
      if (category != null && !fields.containsKey('category')) {
        fields['category'] = category;
      }
      return LevitEventEnvelope._(fields);
    } finally {
      fields._sealed = true;
    }
  }
  String get sessionId => data['sessionId'] as String;
  int get seq => data['seq'] as int;
  String get type => data['type'] as String;
  String get category => data['category'] as String;
  Map<String, dynamic> toJson() => data;
  String encode() => jsonEncode(data);

  static Object? _freeze(
    Object? value,
    Set<Object> active, {
    String? category,
  }) {
    if (value == null ||
        value is String ||
        value is bool ||
        (value is num && value.isFinite)) {
      return value;
    }
    if (value is Map<String, dynamic> || value is List) {
      if (!active.add(value)) throw JsonCyclicError(value);
      try {
        if (value is Map<String, dynamic>) {
          final copy = <String, dynamic>{
            if (category != null) 'category': category,
          };
          value.forEach((key, child) {
            copy[key] = _freeze(child, active);
          });
          // The backing copy is private and never escapes independently.
          return UnmodifiableMapView<String, dynamic>(copy);
        }
        return List<Object?>.unmodifiable(
          (value as List).map((item) => _freeze(item, active)),
        );
      } finally {
        active.remove(value);
      }
    }
    // Preserve JSON's custom toJson conversion and rejection semantics for
    // uncommon values, without encoding/decoding ordinary event payloads.
    return _freeze(jsonDecode(jsonEncode(value)), active);
  }
}

final class _StateChangeFields extends UnmodifiableMapBase<String, dynamic> {
  static const _plainKeys = [
    'seq',
    'timestamp',
    'sessionId',
    'reactiveId',
    'name',
    'ownerId',
    'isSensitive',
    'type',
    'oldValue',
    'newValue',
    'valueType',
    'isBatch',
    'category',
  ];
  static const _stackKeys = [..._plainKeys, 'stackTrace'];
  static const _indices = {
    'seq': 0,
    'timestamp': 1,
    'sessionId': 2,
    'reactiveId': 3,
    'name': 4,
    'ownerId': 5,
    'isSensitive': 6,
    'type': 7,
    'oldValue': 8,
    'newValue': 9,
    'valueType': 10,
    'isBatch': 11,
    'category': 12,
    'stackTrace': 13,
  };
  final List<Object?> _values;
  _StateChangeFields(this._values);
  @override
  Iterable<String> get keys => _values.length == 13 ? _plainKeys : _stackKeys;
  @override
  int get length => _values.length;
  @override
  dynamic operator [](Object? key) {
    final index = _indices[key];
    return index == null || index >= _values.length ? null : _values[index];
  }

  @override
  bool containsKey(Object? key) {
    final index = _indices[key];
    return index != null && index < _values.length;
  }

  @override
  void forEach(void Function(String, dynamic) action) {
    for (var i = 0; i < _values.length; i++) {
      action(_stackKeys[i], _values[i]);
    }
  }
}

final class _EnvelopeFields extends MapBase<String, dynamic> {
  final Map<String, dynamic> _data = {};
  bool _sealed = false;
  void _checkMutable() {
    if (_sealed) throw UnsupportedError('Captured event fields are immutable.');
  }

  @override
  dynamic operator [](Object? key) => _data[key];
  @override
  void operator []=(String key, dynamic value) {
    _checkMutable();
    _data[key] =
        value == null ||
            value is String ||
            value is bool ||
            (value is num && value.isFinite)
        ? value
        : LevitEventEnvelope._freeze(value, HashSet<Object>.identity());
  }

  @override
  Iterable<String> get keys => _data.keys;
  @override
  int get length => _data.length;
  @override
  bool containsKey(Object? key) => _data.containsKey(key);
  @override
  void forEach(void Function(String, dynamic) action) => _data.forEach(action);
  @override
  dynamic remove(Object? key) {
    _checkMutable();
    return _data.remove(key);
  }

  @override
  void clear() {
    _checkMutable();
    _data.clear();
  }
}
