import 'dart:async';
import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('LxStream Transformations', () {
    test('map transforms values', () async {
      final controller = StreamController<int>();
      final stream = LxStream(controller.stream);

      final doubled = stream.map((x) => x * 2);
      doubled.addListener(() {}); // Activate stream

      expect(doubled.status, isA<LxWaiting>());

      controller.add(10);
      await Future.delayed(Duration.zero);

      expect(doubled.value.valueOrNull, 20);
      expect(doubled.status, isA<LxSuccess<int>>());

      controller.close();
    });

    test('where filters values', () async {
      final controller = StreamController<int>();
      final stream = LxStream(controller.stream);

      final even = stream.where((x) => x.isEven);
      even.addListener(() {}); // Activate stream

      controller.add(1);
      await Future.delayed(Duration.zero);
      expect(even.status, isA<LxWaiting>()); // Should not update

      controller.add(2);
      await Future.delayed(Duration.zero);
      expect(even.value.valueOrNull, 2);

      controller.close();
    });

    test('asyncMap handles async transformations', () async {
      final controller = StreamController<int>();
      final stream = LxStream(controller.stream);

      final stringified = stream.asyncMap((x) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return 'Value: $x';
      });
      stringified.addListener(() {}); // Activate stream

      controller.add(5);
      await Future.delayed(Duration.zero);
      expect(stringified.status, isA<LxWaiting>());

      await Future.delayed(const Duration(milliseconds: 20));
      expect(stringified.value.valueOrNull, 'Value: 5');

      controller.close();
    });

    test('distinct filters duplicates', () async {
      final controller = StreamController<int>();
      final stream = LxStream(controller.stream);

      var updateCount = 0;
      final distinct = stream.distinct();
      distinct.addListener(() {
        if (distinct.status.hasValue) updateCount++;
      });
      // Listener already added above, so stream is active!

      controller.add(1);
      await Future.delayed(Duration.zero);
      expect(updateCount, 1);

      controller.add(1); // Duplicate
      await Future.delayed(Duration.zero);
      expect(updateCount, 1); // Should not increment

      controller.add(2);
      await Future.delayed(Duration.zero);
      expect(updateCount, 2);

      controller.close();
    });

    test('expand flats iterables', () async {
      final controller = StreamController<List<int>>();
      final stream = LxStream(controller.stream);

      final flattened = stream.expand((list) => list);

      final values = <int>[];
      flattened.addListener(() {
        if (flattened.status.hasValue) values.add(flattened.value.valueOrNull!);
      });
      // Listener added above.

      controller.add([1, 2, 3]);
      await Future.delayed(Duration.zero);

      // Note: LxStream usually holds ONE current value.
      // expand emits multiple events. LxStream will update its value 3 times rapidly.
      expect(values, [1, 2, 3]);
      expect(flattened.value.valueOrNull, 3); // Last value

      controller.close();
    });

    test('reduce accumulates to Future', () async {
      final controller = StreamController<int>();
      final stream = LxStream(controller.stream);

      final sumFuture = stream.reduce((a, b) => a + b);

      controller.add(1);
      controller.add(2);
      controller.add(3);
      controller.close();

      final result = await sumFuture.wait;
      expect(result, 6);
    });

    test('LxFuture converts to LxStream', () async {
      final future =
          LxFuture(Future.delayed(const Duration(milliseconds: 10), () => 42));
      final stream = future.asLxStream;
      stream.addListener(() {}); // Activate

      expect(stream.status, isA<LxWaiting>());

      await Future.delayed(const Duration(milliseconds: 20));
      expect(stream.value.valueOrNull, 42);
      expect(stream.status, isA<LxSuccess<int>>());
    });
  });
}
