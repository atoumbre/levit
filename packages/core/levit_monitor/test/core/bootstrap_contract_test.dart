import 'dart:async';
import 'package:levit/levit.dart';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:test/test.dart';

class Owner extends LevitController {
  final count = 0.lx;
}

class RecordingTransport extends LevitTransport {
  final events = <LevitMonitorEvent>[];
  final received = Completer<void>();
  @override
  void send(LevitMonitorEvent event) {
    events.add(event);
    if (event.toJson()['type'] == 'state_change' && !received.isCompleted) {
      received.complete();
    }
  }

  @override
  Stream<void> get onConnect => const Stream.empty();
  @override
  Future<void> close() async {}
}

void main() {
  test('documented bootstrap and monitor filtering pattern', () async {
    Levit.enableAutoLinking();
    LevitMonitor.setFilter(
      (event) =>
          event is! LevitReactiveEvent || event.toJson()['name'] != 'secret',
    );
    final transport = RecordingTransport();
    await LevitMonitor.attach(transport: transport);
    final secret = 0.lx.named('secret');
    final visible = 0.lx.named('visible');
    secret.value++;
    visible.value++;
    await transport.received.future;
    final changes = transport.events.where(
      (event) => event.toJson()['type'] == 'state_change',
    );
    expect(changes.map((event) => event.toJson()['name']), ['visible']);
    secret.close();
    visible.close();
    await LevitMonitor.detach();
    LevitMonitor.setFilter(null);
    Levit.disableAutoLinking();
  });
  for (final linking in [false, true]) {
    for (final monitoring in [false, true]) {
      test(
        'ownership follows explicit linking=$linking with monitoring=$monitoring',
        () async {
          Levit.disableAutoLinking();
          if (linking) Levit.enableAutoLinking();
          if (monitoring) {
            await LevitMonitor.attach(transport: RecordingTransport());
          }
          final scope = LevitScope.root();
          final owner = scope.put(Owner.new);
          await scope.dispose();
          expect(owner.count.isDisposed, linking);
          owner.count.close();
          await LevitMonitor.detach();
          Levit.disableAutoLinking();
        },
      );
    }
  }
}
