import 'dart:async';
import 'dart:mirrors';

import 'package:levit_monitor/levit_monitor.dart';
import 'package:test/test.dart';

void main() {
  group('LevitMonitorMiddleware close() (hasListener branch)', () {
    test('close awaits controller close when an external listener exists',
        () async {
      final transport = _TestTransport();
      final middleware = LevitMonitorMiddleware(transport: transport);

      // Attach an extra listener to the internal StreamController so
      // StreamController.hasListener remains true even after the middleware
      // cancels its own subscription.
      final controller = _getEventControllerViaMirrors(middleware);
      final extraSub = controller.stream.listen((_) {});

      await middleware.close();
      expect(transport.closeCalled, isTrue);

      await extraSub.cancel();
    });
  });
}

StreamController<MonitorEvent> _getEventControllerViaMirrors(
    LevitMonitorMiddleware middleware) {
  final mirror = reflect(middleware);
  final lib = mirror.type.owner as LibraryMirror;
  final symbol = MirrorSystem.getSymbol('_eventStream', lib);
  return mirror.getField(symbol).reflectee as StreamController<MonitorEvent>;
}

class _TestTransport implements LevitTransport {
  bool closeCalled = false;

  @override
  Stream<void> get onConnect => const Stream<void>.empty();

  @override
  void send(MonitorEvent event) {}

  @override
  Future<void> close() async {
    closeCalled = true;
  }
}
