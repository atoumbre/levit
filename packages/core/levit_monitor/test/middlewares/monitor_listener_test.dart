import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:test/test.dart';

class MockTransport implements LevitTransport {
  final List<MonitorEvent> events = [];

  @override
  void send(MonitorEvent event) {
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
          type: 'Test', id: 1, data: {'test_key': 'test_value'});

      Lx.runWithContext(ctx, () {
        reactive.addListener(() {});
      });

      await Future.delayed(Duration.zero);

      final event =
          transport.events.whereType<ReactiveListenerAddedEvent>().first;
      expect(event.reactive, equals(reactive));
      expect(event.context, equals(ctx));
    });

    test('captures listener removed event with context', () async {
      final reactive = 0.lx;
      void listener() {}
      final addCtx =
          const LxListenerContext(type: 'Test', id: 1, data: {'ctx': 'add'});

      Lx.runWithContext(addCtx, () {
        reactive.addListener(listener);
      });

      await Future.delayed(Duration.zero);
      transport.events.clear();

      final removeCtx =
          const LxListenerContext(type: 'Test', id: 2, data: {'ctx': 'remove'});
      Lx.runWithContext(removeCtx, () {
        reactive.removeListener(listener);
      });

      await Future.delayed(Duration.zero);

      final event =
          transport.events.whereType<ReactiveListenerRemovedEvent>().first;
      expect(event.reactive, equals(reactive));
      expect(event.context, equals(removeCtx));
    });

    test('captures partial context when runWithContext is nested', () async {
      final reactive = 0.lx;
      final outerCtx = const LxListenerContext(type: 'Outer', id: 1);
      final innerCtx = const LxListenerContext(type: 'Inner', id: 2);

      Lx.runWithContext(outerCtx, () {
        Lx.runWithContext(innerCtx, () {
          reactive.addListener(() {});
        });
      });

      await Future.delayed(Duration.zero);

      final event =
          transport.events.whereType<ReactiveListenerAddedEvent>().first;
      // Should capture the immediate context (inner)
      // Note: Current implementation replaces context, doesn't merge.
      expect(event.context, equals(innerCtx));
      expect(event.context?.type, equals('Inner'));
    });
  });
}
