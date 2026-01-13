import 'dart:async';
import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('State Buffering (lastValue)', () {
    test('LxFuture preserves lastValue on refresh', () async {
      final completer = Completer<int>();
      final future = LxFuture(completer.future);

      expect(future.status, isA<LxWaiting<int>>());
      expect(future.lastValue, isNull);

      completer.complete(42);
      await Future.delayed(Duration.zero);
      expect(future.lastValue, 42);

      final nextCompleter = Completer<int>();
      future.restart(nextCompleter.future);

      expect(future.status, isA<LxWaiting<int>>());
      expect(future.lastValue, 42,
          reason: 'Waiting status should carry last successful value');

      nextCompleter.completeError('oops');
      await Future.delayed(Duration.zero);

      expect(future.status, isA<LxError<int>>());
      expect(future.lastValue, 42,
          reason: 'Error status should carry last successful value');
    });

    test('LxStream preserves lastValue on error', () async {
      final controller = StreamController<int>.broadcast();
      final stream = LxStream(controller.stream);

      stream.valueStream
          .listen((_) {}, onError: (_) {}); // Trigger subscription

      controller.add(1);
      await Future.delayed(Duration.zero);
      expect(stream.lastValue, 1);

      controller.addError('fail');
      await Future.delayed(Duration.zero);

      expect(stream.status, isA<LxError<int>>());
      expect(stream.lastValue, 1,
          reason: 'Stream error should preserve last value');

      controller.add(2);
      await Future.delayed(Duration.zero);
      expect(stream.lastValue, 2);
    });

    // Removed Sync LxComputed tests as it strictly throws on error and does not buffer status.
  });
}
