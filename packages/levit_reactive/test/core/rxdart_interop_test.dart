import 'dart:async';
import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';
import 'package:rxdart/rxdart.dart';

void main() {
  group('RxDart Interop', () {
    test('works with built-in transformer', () async {
      final query = ''.lx;
      final values = <String>[];

      // Using a local StreamTransformer (built-in style)
      LxWatch(
          query.transform((stream) =>
              stream.transform(_debounceBuiltIn(Duration(milliseconds: 50)))),
          (status) {
        if (status is LxSuccess<String>) {
          values.add(status.value);
        }
      });

      query.value = 'a';
      query.value = 'ab';
      query.value = 'abc';

      await Future.delayed(Duration(milliseconds: 100));
      expect(values, equals(['abc']));
    });

    test('works with RxDart transformer', () async {
      final query = ''.lx;
      final values = <String>[];

      // Using RxDart's DebounceStreamTransformer
      // Note: LxReactive.transform(transformer) expects StreamTransformer<T, R>
      LxWatch(
          query.transform((s) => s.debounceTime(Duration(milliseconds: 50))),
          (status) {
        if (status is LxSuccess<String>) {
          values.add(status.value);
        }
      });

      query.value = 'a';
      query.value = 'ab';
      query.value = 'abc';

      await Future.delayed(Duration(milliseconds: 100));
      expect(values, equals(['abc']));
    });

    test('works with RxDart via extension-style (conversion)', () async {
      final query = ''.lx;
      final values = <String>[];

      // We can also just transform the value stream directly if we want
      // and wrap it back into an LxStream.
      final rxStream = query.stream.debounceTime(Duration(milliseconds: 50)).lx;

      LxWatch(rxStream, (status) {
        if (status is LxSuccess<String>) {
          values.add(status.value);
        }
      });

      query.value = 'a';
      query.value = 'ab';
      query.value = 'abc';

      await Future.delayed(Duration(milliseconds: 100));
      expect(values, equals(['abc']));
    });
  });
}

// Simple built-in debounce transformer helper
StreamTransformer<T, T> _debounceBuiltIn<T>(Duration d) {
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
        sync: true,
      );
      return controller.stream.listen(null);
    },
  );
}
