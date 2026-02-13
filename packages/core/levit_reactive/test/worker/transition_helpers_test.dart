import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  group('LxWorker transition helpers', () {
    test('onRising fires only on false -> true transitions', () async {
      final flag = false.lx;
      var fireCount = 0;

      final worker = LxWorker.onRising(flag, () => fireCount++);

      flag.value = true;
      flag.value = false;
      flag.value = true;
      await Future<void>.delayed(Duration.zero);

      expect(fireCount, 2);
      worker.close();
    });

    test('onFalling fires only on true -> false transitions', () async {
      final flag = true.lx;
      var fireCount = 0;

      final worker = LxWorker.onFalling(flag, () => fireCount++);

      flag.value = false;
      flag.value = true;
      flag.value = false;
      await Future<void>.delayed(Duration.zero);

      expect(fireCount, 2);
      worker.close();
    });

    test('onChangeDistinct ignores duplicate notifications', () async {
      final count = 0.lx;
      final values = <int>[];

      final worker = LxWorker.onChangeDistinct(count, values.add);

      count.refresh();
      count.value = 1;
      count.refresh();
      count.value = 2;
      await Future<void>.delayed(Duration.zero);

      expect(values, [1, 2]);
      worker.close();
    });
  });

  group('LxWorker timing helpers', () {
    test('debounce emits only final value in burst', () async {
      final query = ''.lx;
      final values = <String>[];

      final worker = LxWorker.debounce(
          query, const Duration(milliseconds: 30), values.add);

      query.value = 'a';
      query.value = 'ab';
      query.value = 'abc';

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(values, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 35));
      expect(values, ['abc']);
      worker.close();
    });

    test('debounce close cancels pending callback', () async {
      final source = 0.lx;
      var fireCount = 0;

      final worker = LxWorker.debounce(
        source,
        const Duration(milliseconds: 30),
        (_) => fireCount++,
      );

      source.value = 1;
      worker.close();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(fireCount, 0);
    });

    test('throttle emits leading value then suppresses until window ends',
        () async {
      final source = 0.lx;
      final values = <int>[];

      final worker = LxWorker.throttle(
          source, const Duration(milliseconds: 30), values.add);

      source.value = 1;
      source.value = 2;
      source.value = 3;
      await Future<void>.delayed(const Duration(milliseconds: 35));
      source.value = 4;
      await Future<void>.delayed(Duration.zero);

      expect(values, [1, 4]);
      worker.close();
    });
  });
}
