import 'dart:convert';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:test/test.dart';

class _JsonValue {
  final Object? value;
  int calls = 0;
  _JsonValue(this.value);
  Object? toJson() {
    calls++;
    return value;
  }
}

void main() {
  test(
    'envelopes detach and freeze nested JSON without changing wire data',
    () {
      final shared = <Object?>[null, true, 7, 1.5, 'text'];
      final input = <String, dynamic>{
        'sessionId': 'session',
        'seq': 1,
        'type': 'custom',
        'category': 'custom',
        'nested': <String, dynamic>{'first': shared, 'second': shared},
      };
      final expected = jsonEncode(input);
      final envelope = LevitEventEnvelope(input);
      shared.add('later');
      input['seq'] = 2;
      expect(envelope.encode(), expected);
      expect(envelope.sessionId, 'session');
      expect(envelope.seq, 1);
      expect(envelope.type, 'custom');
      expect(envelope.category, 'custom');
      expect(() => envelope.data['seq'] = 3, throwsUnsupportedError);
      final nested = envelope.data['nested'] as Map;
      expect(() => nested['first'] = null, throwsUnsupportedError);
      expect(
        () => (nested['first'] as List).add('mutation'),
        throwsUnsupportedError,
      );
    },
  );

  test('custom JSON conversion and dynamically typed maps stay compatible', () {
    final items = <Object?>[3];
    final custom = _JsonValue(<String, dynamic>{'items': items});
    final envelope = LevitEventEnvelope({
      'custom': custom,
      'dynamicMap': <dynamic, dynamic>{'key': false},
    });
    expect(custom.calls, 1);
    items.add(4);
    expect(jsonDecode(envelope.encode()), {
      'custom': {
        'items': [3],
      },
      'dynamicMap': {'key': false},
    });
  });

  test(
    'cycles fail at capture while repeated noncyclic containers are valid',
    () {
      final list = <Object?>[];
      list.add(list);
      final map = <String, dynamic>{};
      map['self'] = map;
      for (final value in [list, map]) {
        expect(
          () => LevitEventEnvelope({'value': value}),
          throwsA(isA<JsonCyclicError>()),
        );
      }
      final shared = <Object?>[];
      expect(LevitEventEnvelope({'a': shared, 'b': shared}).data, {
        'a': [],
        'b': [],
      });
    },
  );

  test('unsupported objects, keys and nonfinite numbers fail at capture', () {
    for (final value in [
      Object(),
      double.nan,
      double.infinity,
      <int, String>{1: 'x'},
    ]) {
      expect(
        () => LevitEventEnvelope({'value': value}),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
    }
  });
}
