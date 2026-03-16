import 'package:levit_monitor/levit_monitor.dart';
import 'package:logger/logger.dart' hide LogEvent;
import 'package:test/test.dart';

class _TestSerializable {
  final String key;
  final int value;

  _TestSerializable(this.key, this.value);

  Map<String, dynamic> toJson() => {
        'key': key,
        'value': value,
      };
}

void main() {
  group('LogEvent serialization', () {
    test('serializes primitive log data properly', () {
      final event = LogEvent(
        sessionId: 'test-session',
        level: Level.info,
        data: 'Simple message',
      );

      final json = event.toJson();
      expect(json['type'], 'log');
      expect(json['level'], 'info');
      expect(json['data'], 'Simple message');
    });

    test('serializes Map and List data properly', () {
      final eventMap = LogEvent(
        sessionId: 'test-session',
        level: Level.debug,
        data: {'foo': 'bar', 'count': 42},
      );
      expect(eventMap.toJson()['data'], {'foo': 'bar', 'count': 42});

      final eventList = LogEvent(
        sessionId: 'test-session',
        level: Level.debug,
        data: [1, 2, 3],
      );
      expect(eventList.toJson()['data'], [1, 2, 3]);
    });

    test('serializes object with toJson method', () {
      final obj = _TestSerializable('my-key', 100);
      final event = LogEvent(
        sessionId: 'test',
        level: Level.info,
        data: obj,
      );
      
      final jsonOutput = event.toJson();
      expect(jsonOutput['data'], same(obj));
    });

    test('falls back to stringification for non-serializable objects', () {
      final obj = Object();
      final event = LogEvent(
        sessionId: 'test-session',
        level: Level.debug,
        data: obj,
      );

      final json = event.toJson();
      expect(json['data'], contains('Instance of'));
    });

    test('includes error and stack trace conditionally', () {
      final event1 = LogEvent(
        sessionId: 'test-session',
        level: Level.error,
        data: 'Oops',
        error: StateError('Bad state'),
      );

      final json1 = event1.toJson();
      expect(json1.containsKey('error'), isTrue);
      expect(json1['error'], contains('Bad state'));
      expect(json1.containsKey('stackTrace'), isFalse);

      final event2 = LogEvent(
        sessionId: 'test-session',
        level: Level.error,
        data: 'Oops',
        stackTrace: StackTrace.fromString('stack_frame_1'),
      );

      final json2 = event2.toJson();
      expect(json2.containsKey('error'), isFalse);
      expect(json2.containsKey('stackTrace'), isTrue);
      expect(json2['stackTrace'], contains('stack_frame_1'));
    });

    test('serialization handles null data', () {
      final event = LogEvent(
        sessionId: 'test',
        level: Level.info,
        data: null,
      );
      expect(event.toJson()['data'], isNull);
    });

    test('serializes custom object without toJson properly fallback to toString', () {
      final obj = _CustomObjectWithoutToJson();
      final event = LogEvent(
        sessionId: 'test',
        level: Level.info,
        data: obj,
      );
      // It will fail jsonEncode(obj) because it lacks toJson.
      // Then it will fail (obj as dynamic).toJson() with NoSuchMethodError.
      // Then it falls back to toString.
      expect(event.toJson()['data'], 'custom-toString-value');
    });

    test('serializes object whose toJson throws safely back to stringify', () {
      final obj = _CustomObjectThatThrowsOnToJson();
      final event = LogEvent(
        sessionId: 'test',
        level: Level.info,
        data: obj,
      );
      // It will fail jsonEncode(obj) because toJson throws.
      // Then it attempts obj.toJson() directly and catches the same exception.
      // Then falls back to toString.
      expect(event.toJson()['data'], 'throw-toString-value');
    });

    test('serializes object whose toJson is valid but complex to jsonEncode directly', () {
      final nestedObj = _CustomObjectToJsonReturnsNested();
      final event = LogEvent(
        sessionId: 'test',
        level: Level.info,
        data: nestedObj,
      );
      
      final result = event.toJson()['data'];
      expect(result, same(nestedObj));
    });

    test('serializes error and stackTrace if present', () {
      final error = StateError('some error');
      final stackTrace = StackTrace.fromString('some stack');
      final event = LogEvent(
        sessionId: 'test',
        level: Level.error,
        data: 'failed',
        error: error,
        stackTrace: stackTrace,
      );
      final json = event.toJson();
      expect(json['error'], contains('Bad state: some error'));
      expect(json['stackTrace'], 'some stack');
    });
  });
}

class _CustomObjectWithoutToJson {
  @override
  String toString() => 'custom-toString-value';
}

class _CustomObjectThatThrowsOnToJson {
  Map<String, dynamic> toJson() {
    throw Exception('Error encoding');
  }

  @override
  String toString() => 'throw-toString-value';
}

class _CustomObjectToJsonReturnsNested {
  // Returns a map but also throws when encoded initially if we didn\'t handle it correctly?
  // Our goal is to hit `(data as dynamic).toJson()`.
  // Actually, jsonEncode on a custom object directly calls its `toJson()` method.
  // Wait, if jsonEncode calls toJson() and succeeds, we never hit the catch block.
  // To hit the first catch block but succeed the second try block:
  // jsonEncode MUST fail, but `(data as dynamic).toJson()` MUST NOT fail.
  // This happens when the object has `toJson` that returns an object that jsonEncode ALSO rejects.
  // Wait, if toJson returns it, why wouldn\'t jsonEncode reject the result too?
  // Because the second try block just returns the result of `toJson()`!
  // So returning an object that can\'t be encoded from `toJson()` will hit the catch block!
  dynamic toJson() {
    return {'custom': 'valid'};
  }
}
