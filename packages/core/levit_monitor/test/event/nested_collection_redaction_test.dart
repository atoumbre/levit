import 'package:levit_monitor/levit_monitor.dart';
import 'package:levit_monitor/spi.dart';
import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  group('Nested collection redaction in monitor events', () {
    test(
      'LevitReactiveChangeEvent formats nested maps, iterables, nulls, sensitive reactives, and deep graphs without leaking secrets',
      () async {
        final secret = LxVar('top-secret', isSensitive: true);
        final secretKey = LxVar('secret-key', isSensitive: true);
        final rx = LxVar<Object?>(null);

        dynamic deep = 'leaf';
        for (var i = 0; i < 18; i++) {
          deep = <Object?>[deep];
        }

        final payload = <Object?, Object?>{
          'empty': null,
          'items': <Object?>[1, secret, null],
          secretKey: 'value',
          'deep': deep,
        };

        final event = LevitReactiveChangeEvent(
          sessionId: 'session',
          reactive: rx,
          change: LevitReactiveChange<Object?>(
            valueType: Object,
            oldValue: null,
            newValue: payload,
            restore: (_) {},
          ),
        );

        final json = event.toJson();
        final rendered = json['newValue'] as String;
        expect(rendered, contains('empty: null'));
        expect(rendered, contains('[1, '));
        expect(rendered, contains('***'));
        expect(rendered, isNot(contains('top-secret')));
        expect(rendered, isNot(contains('secret-key')));

        // Log event serialization redacts sensitive reactive map keys too.
        final logEvent = LevitLogEvent(
          sessionId: 'session',
          level: LevitLogLevel.info,
          data: <Object?, Object?>{secretKey: 'visible'},
        );
        final logJson = logEvent.toJson();
        final serialized = logJson['data'] as Map<dynamic, dynamic>;
        expect(serialized.keys.single, isNot(contains('secret-key')));
        expect(serialized.values.single, 'visible');

        await rx.close();
        await secret.close();
        await secretKey.close();
      },
    );
  });
}
