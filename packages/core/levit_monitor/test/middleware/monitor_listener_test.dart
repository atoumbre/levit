import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:test/test.dart';
import 'package:levit_monitor/spi.dart';
import 'package:levit_dart_core/spi.dart';

class MockTransport extends LevitTransport {
  final List<LevitMonitorEvent> events = [];

  @override
  void send(LevitMonitorEvent event) {
    events.add(event);
  }

  @override
  Stream<void> get onConnect => const Stream<void>.empty();

  @override
  Future<void> close() async {}
}

void main() {
  group('LevitMonitorMiddleware Listeners', () {
    late LevitMonitorMiddleware middleware;
    late MockTransport transport;

    setUp(() {
      transport = MockTransport();
      middleware = LevitMonitorMiddleware(transport: transport);
      middleware.enable();
    });

    tearDown(() {
      middleware.disable();
    });

    test('captures listener added event with context', () async {
      final reactive = 0.lx;
      final ctx = const LxListenerContext(
        type: 'Test',
        id: 1,
        data: {'test_key': 'test_value'},
      );

      LxSpi.runWithContext(ctx, () {
        reactive.addListener(() {});
      });

      await Future.delayed(Duration.zero);

      final event = transport.events
          .where((event) => event.toJson()['type'] == 'listener_add')
          .first;
      expect(event.toJson()['reactiveId'], equals(reactive.id.toString()));
      expect(event.toJson()['context'], equals(ctx.toJson()));
    });

    test('captures listener removed event with context', () async {
      final reactive = 0.lx;
      void listener() {}
      final addCtx = const LxListenerContext(
        type: 'Test',
        id: 1,
        data: {'ctx': 'add'},
      );

      LxSpi.runWithContext(addCtx, () {
        reactive.addListener(listener);
      });

      await Future.delayed(Duration.zero);
      transport.events.clear();

      final removeCtx = const LxListenerContext(
        type: 'Test',
        id: 2,
        data: {'ctx': 'remove'},
      );
      LxSpi.runWithContext(removeCtx, () {
        reactive.removeListener(listener);
      });

      await Future.delayed(Duration.zero);

      final event = transport.events
          .where((event) => event.toJson()['type'] == 'listener_remove')
          .first;
      expect(event.toJson()['reactiveId'], equals(reactive.id.toString()));
      expect(event.toJson()['context'], equals(removeCtx.toJson()));
    });

    test('captures partial context when runWithContext is nested', () async {
      final reactive = 0.lx;
      final outerCtx = const LxListenerContext(type: 'Outer', id: 1);
      final innerCtx = const LxListenerContext(type: 'Inner', id: 2);

      LxSpi.runWithContext(outerCtx, () {
        LxSpi.runWithContext(innerCtx, () {
          reactive.addListener(() {});
        });
      });

      await Future.delayed(Duration.zero);

      final event = transport.events
          .where((event) => event.toJson()['type'] == 'listener_add')
          .first;
      // Should capture the immediate context (inner)
      // Note: Current implementation replaces context, doesn't merge.
      expect(event.toJson()['context'], equals(innerCtx.toJson()));
      expect(event.toJson()['context']?['type'], equals('Inner'));
    });
  });
}
