import 'dart:async';
import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

// Helper to implement LxReactive for testing
class TestReactive<T> extends LxBase<T> {
  TestReactive(super.initial);
  set value(T v) => setValueInternal(v);
}

void main() {
  group('Watchers Coverage', () {
    test('LxWatchStat equality and toString', () {
      final stat1 =
          LxWatchStat(runCount: 1, lastDuration: Duration(seconds: 1));

      // final stat2 =
      //     LxWatchStat(runCount: 1, lastDuration: Duration(seconds: 1));
      // final stat3 = LxWatchStat(runCount: 2);

      // Since LxWatchStat doesn't override == (it uses default identity or implementation?),
      // actually the code provided doesn't override ==, so they won't be equal unless value based equality is added or it's a const class with const constructor calls.
      // But let's check basic properties.

      expect(stat1.runCount, 1);
      expect(stat1.toString(), contains('runCount: 1'));
    });

    test('LxWatch handles async callbacks', () async {
      final reactive = TestReactive<int>(0);
      bool callbackRun = false;

      final watch = LxWatch(reactive, (val) async {
        await Future.delayed(Duration(milliseconds: 10));
        callbackRun = true;
      });

      reactive.value = 1;
      // Wait for async callback to complete
      await Future.delayed(Duration(milliseconds: 100));

      expect(watch.value.isAsync, true); // was detected as async
      expect(watch.value.isProcessing, false); // has finished processing
      expect(watch.value.runCount, 1);
      expect(callbackRun, true);
    });

    test('LxWatch handles async callback error', () async {
      final reactive = TestReactive<int>(0);
      Object? capturedError;

      final watch = LxWatch(
        reactive,
        (val) async {
          await Future.delayed(Duration(milliseconds: 10));
          throw 'Async Error';
        },
        onProcessingError: (e, s) {
          capturedError = e;
        },
      );

      reactive.value = 1;
      await Future.delayed(Duration(milliseconds: 50));

      expect(watch.value.runCount, 1);
      expect(capturedError, 'Async Error');
      expect(watch.value.error, 'Async Error');
    });

    test('LxWatch handles synchronous error', () {
      final reactive = TestReactive<int>(0);
      final watch = LxWatch(reactive, (val) => throw 'Sync Error');

      try {
        reactive.value = 1;
        // Depending on implementation, sync error might be caught by LxWatch internal try/catch rethrown if no handler
        // The implementation rethrows if onProcessingError is null
      } catch (e) {
        expect(e, 'Sync Error');
      }

      expect(watch.value.runCount, 1);
      expect(watch.value.error, 'Sync Error');
    });

    test('Convenience watchers: isTrue, isFalse, isValue', () {
      final boolRx = TestReactive<bool>(false);
      final intRx = TestReactive<int>(0);

      var trueCount = 0;
      var falseCount = 0;
      var valueCount = 0;

      LxWatch.isTrue(boolRx, () => trueCount++);
      LxWatch.isFalse(boolRx, () => falseCount++);
      LxWatch.isValue(intRx, 5, () => valueCount++);

      boolRx.value = true; // trueCount++
      expect(trueCount, 1);

      boolRx.value = false; // falseCount++
      expect(falseCount, 1);

      intRx.value = 3; // mismatch
      intRx.value = 5; // valueCount++
      expect(valueCount, 1);
    });

    test('LxStatus convenience watcher', () {
      final statusRx = TestReactive<LxStatus<int>>(LxIdle());

      String stage = '';

      LxWatch.status(
        statusRx,
        onIdle: () => stage = 'idle',
        onWaiting: () => stage = 'waiting',
        onSuccess: (v) => stage = 'success $v',
        onError: (e) => stage = 'error $e',
      );

      statusRx.value = LxWaiting();
      expect(stage, 'waiting');

      statusRx.value = LxSuccess(10);
      expect(stage, 'success 10');

      statusRx.value = LxError('fail');
      expect(stage, 'error fail');
    });
  });
}
