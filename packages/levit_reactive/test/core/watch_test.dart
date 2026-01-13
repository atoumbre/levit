import 'dart:async';
import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('watch function', () {
    test('watch fires on every change', () async {
      final count = 0.lx;
      final values = <int>[];
      LxWatch(count, (v) => values.add(v));

      count.value = 1;
      count.value = 2;
      count.value = 3;

      await Future.delayed(Duration.zero);
      expect(values, equals([1, 2, 3]));
    });

    test('watch with takeFirst fires only on first change', () async {
      final count = 0.lx;
      final values = <int>[];
      LxWatch(count.transform((s) => s.transform(_takeFirst())), (v) {
        if (v is LxSuccess<int>) values.add(v.value);
      });

      count.value = 1;
      count.value = 2;
      count.value = 3;

      await Future.delayed(Duration.zero);
      expect(values, equals([1]));
    });

    test('debounce transform waits for value to settle', () async {
      final query = ''.lx;
      final values = <String>[];
      LxWatch(
          query.transform(
              (s) => s.transform(_debounce(Duration(milliseconds: 50)))), (v) {
        if (v is LxSuccess<String>) values.add(v.value);
      });

      query.value = 'a';
      query.value = 'ab';
      query.value = 'abc';

      // Before debounce duration
      await Future.delayed(Duration(milliseconds: 30));
      expect(values, isEmpty);

      // After debounce duration
      await Future.delayed(Duration(milliseconds: 50));
      expect(values, equals(['abc']));
    });

    test('throttle transform limits callback frequency', () async {
      final scroll = 0.lx;
      final values = <int>[];
      LxWatch(
          scroll.transform(
              (s) => s.transform(_throttle(Duration(milliseconds: 50)))), (v) {
        if (v is LxSuccess<int>) values.add(v.value);
      });

      scroll.value = 1;
      scroll.value = 2; // Ignored
      scroll.value = 3; // Ignored

      await Future.delayed(Duration(milliseconds: 60));

      scroll.value = 4; // Should fire

      await Future.delayed(Duration(milliseconds: 10));
      expect(values, equals([1, 4]));
    });

    test('watch returns dispose closure', () async {
      final count = 0.lx;
      final values = <int>[];
      final watcher = LxWatch(count, (v) {
        values.add(v);
      });

      count.value = 1;
      await Future.delayed(Duration.zero);
      expect(values, equals([1]));

      watcher.close();

      count.value = 2;
      await Future.delayed(Duration.zero);
      expect(values, equals([1])); // No new value added
    });

    test('debounce dispose cancels timer', () async {
      final count = 0.lx;
      final values = <int>[];
      final dispose = LxWatch(
        count.transform(
            (s) => s.transform(_debounce(Duration(milliseconds: 50)))),
        (v) {
          if (v is LxSuccess<int>) values.add(v.value);
        },
      );

      count.value = 1;
      dispose.close();

      await Future.delayed(Duration(milliseconds: 100));
      expect(values, isEmpty); // Debounce was cancelled
    });

    test('watch with onError coverage', () async {
      final source = _ErrorReactive<int>(0);

      Object? receivedError;
      final unwatch = LxWatch(
        source,
        (_) {},
        onError: (e, s) => receivedError = e,
      );

      source.addError('test error');
      await Future.delayed(Duration.zero);
      expect(receivedError, 'test error');

      unwatch.close();
      source.close();
    });
  });

  group('watch functions (advanced)', () {
    test('watch with skip skips first N events', () async {
      final count = 0.lx;
      final values = <int>[];

      final dispose =
          LxWatch(count.transform((s) => s.transform(_skip(2))), (v) {
        if (v is LxSuccess<int>) values.add(v.value);
      });

      count.value = 1;
      count.value = 2;
      count.value = 3;
      count.value = 4;

      await Future.delayed(Duration.zero);

      expect(values, equals([3, 4])); // First 2 skipped

      dispose.close();
    });

    test('watch with distinct emits only distinct values', () async {
      final count = 0.lx;
      final values = <int>[];

      final dispose =
          LxWatch(count.transform((s) => s.transform(_distinct())), (v) {
        if (v is LxSuccess<int>) values.add(v.value);
      });

      count.value = 1;
      count.refresh(); // Same value, should be ignored
      count.value = 2;
      count.value = 2; // Same value, ignored
      count.value = 3;

      await Future.delayed(Duration.zero);

      expect(values, equals([1, 2, 3]));

      dispose.close();
    });

    test('debounce handles source stream completion', () async {
      final controller = StreamController<int>.broadcast();

      // Create a custom stream that we can close
      final values = <int>[];
      final transformed =
          controller.stream.transform(_debounce(Duration(milliseconds: 20)));
      transformed.listen((v) => values.add(v));

      controller.add(1);

      // Close stream before debounce fires
      await controller.close();

      // The onDone should have cancelled the timer
      await Future.delayed(Duration(milliseconds: 50));
      // Value may or may not be added depending on timing, just verify no crash
    });

    test('throttle handles source stream completion', () async {
      final controller = StreamController<int>.broadcast();
      final values = <int>[];

      final transformed =
          controller.stream.transform(_throttle(Duration(milliseconds: 20)));
      transformed.listen((v) => values.add(v));

      controller.add(1);
      await controller.close();

      // Should have handled onDone properly
      expect(values, equals([1]));
    });
  });
}

// Helper transformers for tests
StreamTransformer<T, T> _takeFirst<T>() =>
    StreamTransformer<T, T>.fromBind((s) => s.take(1));
StreamTransformer<T, T> _skip<T>(int n) =>
    StreamTransformer<T, T>.fromBind((s) => s.skip(n));
StreamTransformer<T, T> _distinct<T>() =>
    StreamTransformer<T, T>.fromBind((s) => s.distinct());

// Wait, I should probably just use better StreamTransformer implementations.
// I'll implement them properly below.

StreamTransformer<T, T> _debounce<T>(Duration d) {
  Timer? timer;
  return StreamTransformer<T, T>(
    (Stream<T> input, bool cancelOnError) {
      late StreamController<T> controller;
      StreamSubscription<T>? subscription;

      controller = StreamController<T>(
        onListen: () {
          subscription = input.listen(
            (data) {
              timer?.cancel();
              timer = Timer(d, () => controller.add(data));
            },
            onError: controller.addError,
            onDone: () {
              timer?.cancel();
              controller.close();
            },
            cancelOnError: cancelOnError,
          );
        },
        onPause: () => subscription?.pause(),
        onResume: () => subscription?.resume(),
        onCancel: () {
          timer?.cancel();
          return subscription?.cancel();
        },
      );
      return controller.stream.listen(null);
    },
  );
}

StreamTransformer<T, T> _throttle<T>(Duration d) {
  bool canFire = true;
  return StreamTransformer<T, T>(
    (Stream<T> input, bool cancelOnError) {
      late StreamController<T> controller;
      StreamSubscription<T>? subscription;

      controller = StreamController<T>(
        onListen: () {
          subscription = input.listen(
            (data) {
              if (canFire) {
                canFire = false;
                controller.add(data);
                Timer(d, () => canFire = true);
              }
            },
            onError: controller.addError,
            onDone: controller.close,
            cancelOnError: cancelOnError,
          );
        },
        onPause: () => subscription?.pause(),
        onResume: () => subscription?.resume(),
        onCancel: () => subscription?.cancel(),
      );
      return controller.stream.listen(null);
    },
  );
}

class _ErrorReactive<T> implements LxReactive<T> {
  final _controller = StreamController<T>.broadcast();
  T _value;

  _ErrorReactive(this._value);

  @override
  T get value => _value;
  set value(T v) {
    _value = v;
    _controller.add(v);
  }

  @override
  Stream<T> get stream => _controller.stream;

  @override
  void addListener(void Function() l) {}

  @override
  void removeListener(void Function() l) {}

  @override
  void close() => _controller.close();

  void addError(Object e) => _controller.addError(e, StackTrace.current);

  @override
  String? name;

  @override
  String? ownerId;

  @override
  final int id = 0;
}
