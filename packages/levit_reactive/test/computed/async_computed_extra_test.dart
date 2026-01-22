import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  group('LxAsyncComputed & LxComputed Extra Tests', () {
    group('LxAsyncComputed', () {
      test('getters verify state delegates', () async {
        final c = LxComputed.async(() async => 42);

        // Add listener to activate
        c.stream.listen((_) {});

        // Initial state is waiting (async)
        expect(c.isWaiting, true);
        expect(c.isLoading, true);
        expect(c.value, isA<LxWaiting>());

        await Future.delayed(Duration(milliseconds: 50));

        expect(c.isSuccess, true);
        expect(c.hasValue, true);
        expect(c.valueOrNull, 42);

        expect(c.toString(), contains('LxSuccess'));
      });

      test('listener API coverage', () async {
        final c = LxComputed.async(() async => 1);
        var calls = 0;
        void l() => calls++;

        // Activate with listener
        c.addListener(l);
        c.stream.listen((_) {});
        await Future.delayed(Duration(milliseconds: 50));
        expect(calls, greaterThan(0)); // Status changed

        c.removeListener(l);
        c.refresh(); // Should trigger update
        final callsBefore = calls;
        await Future.delayed(Duration(milliseconds: 50));
        expect(calls, callsBefore); // No new calls
      });

      test('handle synchronous error in compute', () async {
        final c = LxComputed.async<int>(() {
          throw 'sync error';
        });

        // Add listener to activate
        c.stream.listen((_) {});
        await Future.delayed(Duration(milliseconds: 20));

        expect(c.value, isA<LxError>());
        expect(c.errorOrNull, 'sync error');
      });

      test('error getters', () async {
        final c = LxComputed.async<int>(() async => throw 'fail');

        // Add listener to activate
        c.stream.listen((_) {});
        await Future.delayed(Duration(milliseconds: 50));

        expect(c.value, isA<LxError>());
        expect(c.errorOrNull, 'fail');
        expect(c.stackTraceOrNull, isNotNull);
      });

      test('close invalidates pending result', () async {
        final c = LxComputed.async(() async {
          await Future.delayed(Duration(milliseconds: 50));
          return 42;
        });

        c.close();
        await Future.delayed(Duration(milliseconds: 100));
        expect(c.status, isA<LxWaiting>()); // Remains waiting
      });

      test('close cancels subscriptions', () async {
        final s = 0.lx;
        final c = LxComputed.async(() async => s.value);
        await Future.delayed(
            Duration(milliseconds: 10)); // let it run and track

        c.close();
      });

      test('executionId prevents race condition', () async {
        final toggle = true.lx;
        final c = LxComputed.async(() async {
          final val = toggle.value;
          await Future.delayed(Duration(milliseconds: val ? 50 : 10));
          return val ? 'slow' : 'fast';
        });

        // Add listener to activate
        c.stream.listen((_) {});

        toggle.value = true;
        await Future.delayed(Duration(milliseconds: 1));
        toggle.value = false;

        await Future.delayed(Duration(milliseconds: 100));
        expect(c.valueOrNull, 'fast');
      });
    });

    group('LxComputed (Sync)', () {
      test('getters coverage', () {
        final c = LxComputed(() => 42);
        // Sync computed returns value directly via computedValue
        expect(c.value, 42);
      });
    });
  });
}
