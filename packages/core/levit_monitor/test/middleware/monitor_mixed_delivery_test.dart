import 'dart:async';
import 'package:levit_monitor/levit_monitor.dart';
import 'package:test/test.dart';
import 'package:levit_monitor/spi.dart';

class _MixedTransport extends LevitTransport {
  final release = Completer<void>();
  final names = <String>[];
  @override
  FutureOr<void> send(LevitMonitorEvent event) {
    final name = event.toJson()['scopeName'] as String;
    names.add(name);
    if (name == 'second') return release.future;
  }
}

void main() {
  test(
    'synchronous sends preserve order around asynchronous sends and close',
    () async {
      final transport = _MixedTransport();
      final monitor = LevitMonitorMiddleware(transport: transport)..enable();
      monitor.onScopeCreate(1, 'first', null);
      monitor.onScopeCreate(2, 'second', null);
      monitor.onScopeCreate(3, 'third', null);
      var finished = false;
      final closing = monitor.close().then((_) => finished = true);
      await Future<void>.delayed(Duration.zero);
      expect(transport.names, ['first', 'second']);
      expect(finished, isFalse);
      transport.release.complete();
      await closing;
      expect(transport.names, ['first', 'second', 'third']);
      expect(finished, isTrue);
    },
  );
}
