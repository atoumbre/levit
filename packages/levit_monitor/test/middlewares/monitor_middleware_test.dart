import 'package:levit_dart/levit_dart.dart';
import 'package:levit_monitor/src/core/event.dart';
import 'package:levit_monitor/src/core/transport.dart';
import 'package:levit_monitor/src/middlewares/state.dart';
import 'package:test/test.dart';

class MockTransport implements LevitTransport {
  final List<MonitorEvent> events = [];

  @override
  void send(MonitorEvent event) {
    events.add(event);
  }

  @override
  void close() {}
}

void main() {
  group('LevitMonitorMiddleware', () {
    late LevitMonitorMiddleware middleware;
    late MockTransport transport;

    setUp(() {
      transport = MockTransport();
      middleware = LevitMonitorMiddleware(transport: transport);
      middleware.enable();
    });

    tearDown(() {
      middleware.disable();
      Levit.reset(force: true);
    });

    test('captures reactive registration as ReactiveInitEvent', () async {
      final reactive = 0.lx.named('test').register('owner');
      await Future.delayed(Duration.zero);

      final event = transport.events.whereType<ReactiveInitEvent>().first;
      expect(event.reactive, same(reactive));
      expect(event.reactive.name, equals('test'));
      expect(event.reactive.ownerId, equals('owner'));
    });

    test('captures state changes as ReactiveChangeEvent', () async {
      final reactive = 0.lx.named('r');
      reactive.value++;
      await Future.delayed(Duration.zero);

      final event = transport.events.whereType<ReactiveChangeEvent>().first;
      expect(event.reactive.name, equals('r'));
      expect(event.change.newValue, equals(1));
    });

    test('captures DI registration as DependencyRegisterEvent', () async {
      Levit.put(() => 'di_value', tag: 'di_test');
      await Future.delayed(Duration.zero);

      final event = transport.events.whereType<DependencyRegisterEvent>().first;
      expect(event.key, contains('String_di_test'));
      expect(event.scopeName, equals('root'));
    });

    test('captures DI resolution as DependencyResolveEvent', () async {
      Levit.lazyPut(() => 'di_value', tag: 'di_test');
      Levit.find<String>(tag: 'di_test');
      await Future.delayed(Duration.zero);

      final event = transport.events.whereType<DependencyResolveEvent>().first;
      expect(event.key, contains('String_di_test'));
    });

    test('updateTransport changes transport and settings', () async {
      final newTransport = MockTransport();

      middleware.updateTransport(
        transport: newTransport,
        includeStackTrace: true,
      );

      expect(middleware.transport, same(newTransport));
      expect(middleware.includeStackTrace, isTrue);

      // Verify new transport receives events
      final reactive = 0.lx.named('new_transport_test');
      await Future.delayed(Duration.zero);

      expect(newTransport.events, isNotEmpty);
      expect(reactive.value, 0);
    });

    test('captures batch events (sync)', () async {
      final rx1 = 0.lx;
      final rx2 = 0.lx;

      Lx.batch(() {
        rx1.value = 1;
        rx2.value = 2;
      });

      await Future.delayed(Duration.zero);

      final batchEvents = transport.events.whereType<ReactiveBatchEvent>();
      expect(batchEvents, isNotEmpty);
      expect(batchEvents.first.change.length, 2);
    });

    test('captures batch events (async)', () async {
      final rx1 = 0.lx;
      final rx2 = 0.lx;

      await Lx.batchAsync(() async {
        rx1.value = 1;
        await Future.delayed(Duration(milliseconds: 10));
        rx2.value = 2;
      });

      await Future.delayed(Duration.zero);

      final batchEvents = transport.events.whereType<ReactiveBatchEvent>();
      expect(batchEvents, isNotEmpty);
    });

    test('captures DI deletion as DependencyDeleteEvent', () async {
      Levit.put(() => 'value_to_delete', tag: 'delete_test');
      await Future.delayed(Duration.zero);

      Levit.delete<String>(tag: 'delete_test', force: true);
      await Future.delayed(Duration.zero);

      final deleteEvents = transport.events.whereType<DependencyDeleteEvent>();
      expect(deleteEvents, isNotEmpty);
      expect(deleteEvents.first.key, contains('String_delete_test'));
    });

    test('captures DI instance creation as DependencyInstanceCreateEvent',
        () async {
      Levit.put(() => 'created_instance', tag: 'create_test');
      await Future.delayed(Duration.zero);

      final createEvents =
          transport.events.whereType<DependencyInstanceCreateEvent>();
      expect(createEvents, isNotEmpty);
      expect(createEvents.first.key, contains('String_create_test'));
    });

    test('captures DI instance init as DependencyInstanceReadyEvent', () async {
      // Register controller with DI to trigger init event
      Levit.put(() => TestController(), tag: 'test_controller');
      await Future.delayed(Duration.zero);

      final initEvents =
          transport.events.whereType<DependencyInstanceReadyEvent>();
      expect(initEvents, isNotEmpty);
    });

    test('captures graph change events', () async {
      final source = 0.lx;
      final computed = (() => source.value * 2).lx;

      // Trigger computation to establish dependency
      computed.value;
      await Future.delayed(Duration.zero);

      final graphEvents =
          transport.events.whereType<ReactiveGraphChangeEvent>();
      expect(graphEvents, isNotEmpty);
    });

    test('captures reactive dispose events', () async {
      final reactive = 0.lx.named('disposable');
      await Future.delayed(Duration.zero);

      reactive.close();
      await Future.delayed(Duration.zero);

      final disposeEvents = transport.events.whereType<ReactiveDisposeEvent>();
      expect(disposeEvents, isNotEmpty);
      expect(disposeEvents.first.reactive.name, 'disposable');
    });

    test('onDependencyInit captures instance information', () async {
      // Create a controller with async onInit to trigger onDependencyInit
      final controller = TestControllerWithAsyncInit();
      Levit.put(() => controller, tag: 'async_init_test');

      await Future.delayed(Duration(milliseconds: 100));

      final initEvents =
          transport.events.whereType<DependencyInstanceReadyEvent>();
      expect(initEvents, isNotEmpty);

      // Verify instance is captured
      final event = initEvents.firstWhere(
        (e) => e.key.contains('TestControllerWithAsyncInit'),
        orElse: () => initEvents.first,
      );
      expect(event.instance, isNotNull);
    });
  });
}

class TestController extends LevitController {
  @override
  Future<void> onInit() async {
    super.onInit();
  }
}

class TestControllerWithAsyncInit extends LevitController {
  @override
  Future<void> onInit() async {
    super.onInit();
    await Future.delayed(Duration(milliseconds: 10));
  }
}
