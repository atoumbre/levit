import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

Future<void> pump() => Future.delayed(Duration.zero);

void main() {
  group('LxComputed.deferred', () {
    test('converts sync computation to async status-wrapped flow', () async {
      final count = 0.lx;
      final deferred = LxComputed.deferred(() => count.value * 2);
      final sub = deferred.stream.listen((_) {});

      expect(deferred.value, isA<LxWaiting<int>>());

      // Wait for execution
      await pump();
      expect(deferred.value, isA<LxSuccess<int>>());
      expect(deferred.value.lastValue, 0);

      count.value = 10;
      await pump();
      expect(deferred.value.lastValue, 20);

      await sub.cancel();
    });

    test('handles errors by wrapping in LxError', () async {
      final shouldFail = false.lx;
      final deferred = LxComputed.deferred(() {
        if (shouldFail.value) throw Exception('sync error');
        return 'ok';
      });
      final sub = deferred.stream.listen((_) {});

      await pump();
      expect(deferred.value, isA<LxSuccess<String>>());

      shouldFail.value = true;
      await pump();
      expect(deferred.value, isA<LxError<String>>());
      expect(
          (deferred.value as LxError).error.toString(), contains('sync error'));

      await sub.cancel();
    });

    test('respects showWaiting flag', () async {
      final count = 0.lx;
      final deferred = LxComputed.deferred(
        () => count.value * 2,
        showWaiting: true,
      );
      final sub = deferred.stream.listen((_) {});

      expect(deferred.value, isA<LxWaiting<int>>());

      await pump();
      expect(deferred.value, isA<LxSuccess<int>>());

      count.value = 5;
      // With showWaiting: true, it should flip to LxWaiting immediately on dependency change
      expect(deferred.value, isA<LxWaiting<int>>());

      await pump();
      expect(deferred.value, isA<LxSuccess<int>>());
      expect(deferred.value.lastValue, 10);

      await sub.cancel();
    });
  });
}
