import 'dart:convert';

import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:logger/logger.dart' show Level;
import 'package:test/test.dart';

class _WireTimestamp extends LogEvent {
  _WireTimestamp() : super(sessionId: 'custom', level: Level.info);
  @override
  Map<String, dynamic> toJson() => super.toJson()
    ..['timestamp'] = '2026-01-02T03:04:05.123456Z'
    ..['category'] = 'overridden';
}

class _CustomChange extends ReactiveChangeEvent {
  _CustomChange({required super.reactive, required super.change})
    : super(sessionId: 'custom');
  @override
  Map<String, dynamic> toJson() => super.toJson()
    ..['timestamp'] = '2026-01-02T03:04:05.123456Z'
    ..['extra'] = 'preserved';
}

void main() {
  test('scalar capture preserves wire data, redaction and custom events', () {
    for (final sensitive in [false, true]) {
      final source = 'secret'.lx..isSensitive = sensitive;
      for (final stack in [null, StackTrace.fromString('private stack')]) {
        final change = LevitReactiveChange<String?>(
          timestamp: DateTime.now(),
          valueType: String,
          oldValue: null,
          newValue: 'secret "quoted"',
        );
        final event = ReactiveChangeEvent(
          sessionId: 'session',
          reactive: source,
          change: change,
          stackTrace: stack,
        );
        final captured = event.freeze();
        final expected = event.toJson()..['category'] = 'state';
        expect(captured.toJson(), expected);
        expect(jsonDecode(captured.envelope.encode()), expected);
        expect(captured.toJson().length, expected.length);
        expect(captured.toJson().keys.toSet(), expected.keys.toSet());
        expect(captured.toJson().containsKey('oldValue'), isTrue);
        expect(captured.toJson().containsKey('stackTrace'), stack != null);
        expect(captured.toJson()['unknown'], isNull);
        expect(captured.toJson().containsKey('unknown'), isFalse);
        expect(
          () => captured.toJson()['newValue'] = 'changed',
          throwsUnsupportedError,
        );
        if (sensitive) {
          expect(captured.envelope.encode(), isNot(contains('secret')));
          expect(captured.envelope.encode(), isNot(contains('private stack')));
        }
        final custom = _CustomChange(reactive: source, change: change).freeze();
        expect(custom.toJson()['extra'], 'preserved');
        expect(custom.timestamp, DateTime.utc(2026, 1, 2, 3, 4, 5, 123, 456));
      }
      source.close();
    }
  });

  test('capture builder seals retained fields and freezes at assignment', () {
    late Map<String, dynamic> retained;
    final nested = <int>[1];
    final envelope = LevitEventEnvelope.capture((fields) {
      retained = fields;
      fields['discard'] = true;
      expect(fields.remove('discard'), isTrue);
      fields['temporary'] = 1;
      fields.clear();
      fields['nested'] = nested;
      nested.add(2);
      return fields;
    }, category: 'custom');
    expect(envelope.data['nested'], [1]);
    expect(envelope.data.keys, containsAll(['nested', 'category']));
    expect(envelope.data.length, 2);
    expect(() => retained['late'] = 1, throwsUnsupportedError);
    expect(() => retained.remove('nested'), throwsUnsupportedError);
    expect(retained.clear, throwsUnsupportedError);
    expect(() => (retained['nested'] as List).add(3), throwsUnsupportedError);
    final copied = LevitEventEnvelope.capture((fields) {
      fields['abandoned'] = false;
      return {'category': 'explicit', 'data': nested};
    }, category: 'custom');
    nested.add(3);
    expect(copied.category, 'explicit');
    expect(copied.data['data'], [1, 2]);
    expect(
      () => LevitEventEnvelope.capture((fields) {
        retained = fields;
        throw StateError('builder failed');
      }),
      throwsStateError,
    );
    expect(() => retained['late'] = true, throwsUnsupportedError);
  });

  test('captured timestamps retain precision and custom serialization', () {
    final ordinary = LogEvent(sessionId: 'ordinary', level: Level.info);
    final frozen = ordinary.freeze();
    expect(frozen.timestamp, same(ordinary.timestamp));
    expect(
      frozen.envelope.data['timestamp'],
      ordinary.timestamp.toIso8601String(),
    );
    expect(frozen.freeze(), same(frozen));
    final overridden = _WireTimestamp().freeze();
    expect(overridden.timestamp, DateTime.utc(2026, 1, 2, 3, 4, 5, 123, 456));
    expect(overridden.envelope.category, 'overridden');
  });

  test(
    'default envelope categories preserve explicit fields and detached data',
    () {
      final input = <String, dynamic>{
        'values': <int>[1],
      };
      final captured = LevitEventEnvelope(input, category: 'state');
      expect(captured.category, 'state');
      expect(input.containsKey('category'), isFalse);
      (input['values'] as List).add(2);
      expect(captured.data['values'], [1]);
      expect(() => captured.data.clear(), throwsUnsupportedError);
      expect(
        LevitEventEnvelope({'category': 'custom'}, category: 'state').category,
        'custom',
      );
    },
  );
}
