import 'dart:async';
import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:test/test.dart';
import 'package:levit_monitor/spi.dart';

class MockTransport extends LevitTransport {
  final List<LevitMonitorEvent> events = [];
  void Function(LevitMonitorEvent)? onSend;

  @override
  void send(LevitMonitorEvent event) {
    events.add(event);
    onSend?.call(event);
  }

  @override
  Stream<void> get onConnect => const Stream<void>.empty();

  @override
  Future<void> close() async {}
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

    tearDown(() async {
      await middleware.close();
      await Levit.reset(force: true);
    });

    test('captures reactive registration', () async {
      final reactive = LxVar(0, name: 'test')..ownerId = 'owner';
      await Future.delayed(Duration.zero);

      final event = transport.events
          .where((event) => event.toJson()['type'] == 'reactive_init')
          .first;
      expect(event.toJson()['reactiveId'], reactive.id.toString());
      expect(event.toJson()['name'], equals('test'));
      expect(
        transport.events
            .lastWhere((event) => event.toJson()['type'] == 'reactive_metadata')
            .toJson()['ownerId'],
        'owner',
      );
    });

    test('captures state changes', () async {
      final reactive = 0.lx.named('r');
      reactive.value++;
      await Future.delayed(Duration.zero);

      final event = transport.events
          .where((event) => event.toJson()['type'] == 'state_change')
          .first;
      expect(event.toJson()['reactiveId'], reactive.id.toString());
      expect(event.toJson()['name'], equals('r'));
      expect(event.toJson()['newValue'], equals('1'));
    });

    test('captures DI registration', () async {
      Levit.put(() => 'di_value', tag: 'di_test');
      await Future.delayed(Duration.zero);

      final event = transport.events
          .where((event) => event.toJson()['type'] == 'di_register')
          .first;
      expect(event.toJson()['key'], contains('String_di_test'));
      expect(event.toJson()['scopeName'], equals('root'));
    });

    test('captures DI resolution', () async {
      Levit.lazyPut(() => 'di_value', tag: 'di_test');
      Levit.find<String>(tag: 'di_test');
      await Future.delayed(Duration.zero);

      final event = transport.events
          .where((event) => event.toJson()['type'] == 'di_resolve')
          .first;
      expect(event.toJson()['key'], contains('String_di_test'));
    });

    test('updateTransport changes transport and settings', () async {
      final newTransport = MockTransport();

      await middleware.updateTransport(
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

      final batchEvents = transport.events.where(
        (event) => event.toJson()['type'] == 'batch',
      );
      expect(batchEvents, isNotEmpty);
      expect(batchEvents.first.toJson()['count'], 2);
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

      final batchEvents = transport.events.where(
        (event) => event.toJson()['type'] == 'batch',
      );
      expect(batchEvents, isNotEmpty);
    });

    test(
      'batch boundaries include sync errors and exclude returned async work',
      () async {
        final source = 0.lx;
        final batchesDelivered = Completer<void>();
        var delivered = 0;
        transport.onSend = (event) {
          if (event.toJson()['type'] == 'batch' && ++delivered == 2) {
            batchesDelivered.complete();
          }
        };
        expect(
          () => Lx.batch(() {
            source.value = 1;
            throw StateError('batch');
          }),
          throwsStateError,
        );
        final release = Completer<void>();
        final work = Lx.batch(() {
          source.value = 2;
          return release.future.then((_) => source.value = 3);
        });
        await batchesDelivered.future;
        expect(
          transport.events
              .where((event) => event.toJson()['type'] == 'batch')
              .length,
          2,
        );
        release.complete();
        await work;
        source.close();
      },
    );

    test('captures DI deletion', () async {
      Levit.put(() => 'value_to_delete', tag: 'delete_test');
      await Future.delayed(Duration.zero);

      Levit.delete<String>(tag: 'delete_test', force: true);
      await Future.delayed(Duration.zero);

      final deleteEvents = transport.events.where(
        (event) => event.toJson()['type'] == 'di_delete',
      );
      expect(deleteEvents, isNotEmpty);
      expect(
        deleteEvents.first.toJson()['key'],
        contains('String_delete_test'),
      );
    });

    test('captures DI instance creation', () async {
      Levit.put(() => 'created_instance', tag: 'create_test');
      await Future.delayed(Duration.zero);

      final createEvents = transport.events.where(
        (event) => event.toJson()['type'] == 'di_instance_create',
      );
      expect(createEvents, isNotEmpty);
      expect(
        createEvents.first.toJson()['key'],
        contains('String_create_test'),
      );
    });

    test('captures DI instance init', () async {
      // Register controller with DI to trigger init event
      Levit.put(() => TestController(), tag: 'test_controller');
      await Future.delayed(Duration.zero);

      final initEvents = transport.events.where(
        (event) => event.toJson()['type'] == 'di_instance_init',
      );
      expect(initEvents, isNotEmpty);
    });

    test('captures graph change events', () async {
      final source = 0.lx;
      final computed = (() => source.value * 2).lx;

      // Trigger computation to establish dependency
      computed.value;
      await Future.delayed(Duration.zero);

      final graphEvents = transport.events.where(
        (event) => event.toJson()['type'] == 'graph_change',
      );
      expect(graphEvents, isNotEmpty);
    });

    test('captures reactive dispose events', () async {
      final reactive = 0.lx.named('disposable');
      await Future.delayed(Duration.zero);

      reactive.close();
      await Future.delayed(Duration.zero);

      final disposeEvents = transport.events.where(
        (event) => event.toJson()['type'] == 'reactive_dispose',
      );
      expect(disposeEvents, isNotEmpty);
      expect(disposeEvents.first.toJson()['name'], 'disposable');
    });

    test('onDependencyInit captures instance information', () async {
      // Create a controller with async onInit to trigger onDependencyInit
      final controller = TestControllerWithAsyncInit();
      Levit.put(() => controller, tag: 'async_init_test');

      await Future.delayed(Duration(milliseconds: 100));

      final initEvents = transport.events.where(
        (event) => event.toJson()['type'] == 'di_instance_init',
      );
      expect(initEvents, isNotEmpty);

      // Verify instance is captured
      final event = initEvents.firstWhere(
        (e) => e.toJson()['key'].contains('TestControllerWithAsyncInit'),
        orElse: () => initEvents.first,
      );
      expect(event.toJson()['instance'], isNotNull);
    });

    test('reactive errors omit stack trace by default', () async {
      final reactive = 0.lx.named('stack-less');
      reactive.addListener(() {
        throw StateError('boom');
      });

      reactive.value = 1;
      await Future<void>.delayed(Duration.zero);

      final errorEvent = transport.events
          .where((event) => event.toJson()['type'] == 'reactive_error')
          .first;
      expect(errorEvent.toJson()['stack'], isNull);
    });

    test('reactive errors include stack trace when enabled', () async {
      await middleware.updateTransport(includeStackTrace: true);
      transport.events.clear();

      final reactive = 0.lx.named('with_stack');
      reactive.addListener(() {
        throw StateError('boom');
      });

      reactive.value = 1;
      await Future<void>.delayed(Duration.zero);

      final errorEvent = transport.events
          .where((event) => event.toJson()['type'] == 'reactive_error')
          .first;
      expect(errorEvent.toJson()['stack'], isNotNull);
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
