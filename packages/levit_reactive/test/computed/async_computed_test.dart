import 'dart:async';
import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('LxAsyncComputed', () {
    test('computes initial value asynchronously', () async {
      final count = 10.lx;
      final doubled = LxComputed.async(() async {
        await Future.delayed(Duration(milliseconds: 10));
        return count.value * 2;
      });

      // Add listener to activate
      doubled.stream.listen((_) {});
      expect(doubled.value, isA<LxWaiting<int>>());

      await Future.delayed(Duration(milliseconds: 50));
      expect(doubled.valueOrNull, 20);
    });

    test('recomputes when dependency changes', () async {
      final count = 1.lx;
      int computeCount = 0;

      final doubled = LxComputed.async(() async {
        final currentCount = count.value; // Access before await
        computeCount++;
        await Future.delayed(Duration(milliseconds: 10));
        return currentCount * 2;
      });

      // Add listener to activate
      doubled.stream.listen((_) {});

      await Future.delayed(Duration(milliseconds: 50));
      expect(doubled.valueOrNull, 2);
      expect(computeCount, greaterThan(0));

      count.value = 5;
      await Future.delayed(Duration(milliseconds: 50));
      expect(doubled.valueOrNull, 10);
    });

    test('handles race conditions by discarding old results', () async {
      final count = 1.lx;
      final results = <int>[];

      final doubled = LxComputed.async(() async {
        final currentVal = count.value; // Access before await
        // Simulating varying network speeds
        if (currentVal == 1) {
          await Future.delayed(Duration(milliseconds: 50));
        } else {
          await Future.delayed(Duration(milliseconds: 10));
        }
        return currentVal * 2;
      });

      doubled.stream.listen((status) {
        if (status is LxSuccess<int>) {
          results.add(status.value);
        }
      });

      // Change value while first computation is still pending
      await Future.delayed(Duration(milliseconds: 20));
      count.value = 5;

      // Wait for all to finish
      await Future.delayed(Duration(milliseconds: 100));

      expect(results, [10],
          reason: 'Old result (2) should have been discarded');
      expect(doubled.valueOrNull, 10);
    });

    test('handles async errors and preserves lastValue', () async {
      final count = 1.lx;
      final computed = LxComputed.async(() async {
        final currentVal = count.value; // Access before await
        await Future.delayed(Duration(milliseconds: 10));
        if (currentVal < 0) throw 'negative';
        return currentVal * 2;
      });

      // Add listener to activate
      computed.stream.listen((_) {});

      await Future.delayed(Duration(milliseconds: 50));
      expect(computed.valueOrNull, 2);

      count.value = -1;
      await Future.delayed(Duration(milliseconds: 50));

      expect(computed.value, isA<LxError<int>>());
      expect(computed.lastValue, 2,
          reason: 'Should preserve last successful value on error');
    });

    test('manual refresh works', () async {
      int count = 0;
      final asyncVal = LxComputed.async(() async {
        count++;
        return count;
      });

      // Add listener to activate
      asyncVal.stream.listen((_) {});

      await Future.delayed(Duration(milliseconds: 20));
      expect(asyncVal.valueOrNull, greaterThan(0));

      asyncVal.refresh();
      await Future.delayed(Duration(milliseconds: 20));
      expect(asyncVal.valueOrNull, greaterThan(1));
    });

    test('LxAsyncComputed constructor coverage', () {
      final computed = _TestAsyncComputed();
      expect(computed, isA<LxAsyncComputed<int>>());
    });
  });
}

class _TestAsyncComputed extends LxAsyncComputed<int> {
  _TestAsyncComputed() : super(() async => 0);

  @override
  LxStatus<int> get status => LxIdle();

  @override
  bool get hasListener => false;

  @override
  void refresh() {}

  @override
  void close() {}

  @override
  LxStatus<int> get value => status;

  @override
  Stream<LxStatus<int>> get stream => const Stream.empty();

  @override
  Function() addListener(void Function() listener) => () {};

  @override
  void removeListener(void Function() listener) {}

  @override
  LxStream<R> transform<R>(
      Stream<R> Function(Stream<LxStatus<int>> stream) transformer) {
    throw UnimplementedError();
  }

  @override
  String? name;

  @override
  String? ownerId;
}
