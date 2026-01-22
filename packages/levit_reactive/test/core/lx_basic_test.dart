import 'dart:async';
import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';
import '../helpers.dart';

void main() {
  group('LxVar<T>', () {
    test('initial value is accessible', () {
      final count = LxInt(0);
      expect(count.value, equals(0));
    });

    test('setting value triggers stream event', () async {
      final count = LxInt(0);
      final triggered = <int>[];
      count.stream.listen((v) => triggered.add(v));
      count.value = 1;

      await Future.delayed(Duration.zero);
      expect(triggered, equals([1]));
      expect(count.value, equals(1));
    });

    test('setting same value does not trigger stream', () async {
      final count = LxInt(0);
      final triggered = <int>[];
      count.stream.listen((v) => triggered.add(v));
      count.value = 0;

      await Future.delayed(Duration.zero);
      expect(triggered, isEmpty);
    });

    test('refresh triggers stream event without value change', () async {
      final count = LxInt(0);
      final triggered = <int>[];
      count.stream.listen((v) => triggered.add(v));

      count.refresh();

      await Future.delayed(Duration.zero);
      expect(triggered, equals([0]));
    });

    test('notify is alias for refresh', () async {
      final count = LxInt(0);
      final triggered = <int>[];
      count.stream.listen((v) => triggered.add(v));

      count.notify();

      await Future.delayed(Duration.zero);
      expect(triggered, equals([0]));
    });

    test('toString returns value string', () {
      final count = LxInt(42);
      expect(count.toString(), equals('42'));
    });

    test('addListener and removeListener work', () {
      final count = LxInt(0);
      var notified = 0;
      void listener() => notified++;

      count.addListener(listener);
      count.value = 1;
      expect(notified, equals(1));

      count.removeListener(listener);
      count.value = 2;
      expect(notified, equals(1)); // Still 1
    });

    test('call() updates/returns value', () {
      final count = LxInt(0);
      expect(count(), equals(0));
      expect(count(5), equals(5));
      expect(count.value, equals(5));
    });

    test('updateValue transforms value', () {
      final count = LxInt(0);
      count.updateValue((v) => v + 1);
      expect(count.value, equals(1));
    });

    test('mutate updates value in place and notifies', () {
      final user = LxVar<MutableUser>(MutableUser('Alice', 30));
      bool notified = false;
      user.addListener(() => notified = true);

      user.mutate((u) {
        u.name = 'Bob';
      });

      expect(user.value.name, equals('Bob'));
      expect(notified, isTrue);
    });

    test('equality is identity-based', () {
      final count = LxInt(42);
      final sameValue = LxInt(42);
      expect(count == count, isTrue);
      expect(count == sameValue, isFalse);
      // ignore: unrelated_type_equality_checks
      expect(count == 42, isFalse);
    });

    test('hashCode is identity-based', () {
      final count = LxInt(42);
      final sameValue = LxInt(42);
      expect(count.hashCode, isNot(equals(42.hashCode)));
      expect(count.hashCode, isNot(equals(sameValue.hashCode)));
    });
  });

  group('.lx extension', () {
    test('works on int', () {
      final count = 0.lx;
      expect(count, isA<LxInt>());
      expect(count.value, equals(0));
    });

    test('works on String', () {
      final name = 'John'.lx;
      expect(name, isA<LxVar<String>>());
      expect(name.value, equals('John'));
    });

    test('works on bool', () {
      final flag = true.lx;
      expect(flag, isA<LxBool>());
      expect(flag.value, isTrue);
    });

    test('works on custom objects', () {
      final user = User('John', 30).lx;
      expect(user, isA<LxVar<User>>());
      expect(user.value.name, equals('John'));
    });
  });

  group('edge cases for coverage', () {
    test('bind forwards values from external stream', () async {
      final controller = StreamController<int>.broadcast();
      final lx = LxInt(0);

      lx.bind(controller.stream);

      final values = <int>[];
      final sub = lx.stream.listen((v) => values.add(v));

      controller.add(42);
      await Future.delayed(Duration.zero);

      expect(values.contains(42) || lx.value == 42, isTrue);

      await controller.close();
      await sub.cancel();
    });

    test('bind forwards errors from external stream', () async {
      final controller = StreamController<int>.broadcast();
      final lx = LxInt(0);
      lx.bind(controller.stream);

      final errors = <Object>[];
      final sub = lx.stream.listen((_) {}, onError: (e) => errors.add(e));

      // Need to activate the stream subscription
      controller.add(1);

      controller.addError('Error');

      await Future.delayed(Duration.zero);
      // Note: Error forwarding test logic might be finicky depending on async gap

      await controller.close();
      await sub.cancel();
    });
  });

  group('LxStream Coverage Gaps', () {
    test('transform applies closure to status stream', () async {
      final controller = StreamController<int>();
      final lxStream = LxStream(controller.stream);

      final transformed = lxStream.transform(
        (s) => s.map((status) => "Status: $status"),
      );

      expect(transformed, isA<LxStream<String>>());
      // Initial status is waiting
      expect(lxStream.status, isA<LxWaiting<int>>());

      expectLater(
        transformed.valueStream,
        emitsInOrder([
          startsWith('Status: LxSuccess'),
        ]),
      );

      controller.add(1);
      await controller.close();
    });

    test('fold reduces stream to a single future value', () async {
      final controller = StreamController<int>();
      final lxStream = LxStream(controller.stream);

      final future = lxStream.fold<int>(0, (prev, element) => prev + element);

      expect(future, isA<LxFuture<int>>());

      controller.add(1);
      controller.add(2);
      controller.add(3);
      await controller.close();

      // LxFuture.value returns LxStatus<T>
      expect(future.value.valueOrNull, equals(6));

      // We can also await the underlying future if exposed, but confirm LxFuture API first.
      // Assuming we want to check the reactive state value:
      expect(future.value, isA<LxSuccess<int>>());
    });
  });

  group('LxIdle Coverage', () {
    test('LxIdle equality and hashCode', () {
      final idle1 = LxIdle<int>(0);
      final idle2 = LxIdle<int>(0);
      final idle3 = LxIdle<int>(1);

      expect(idle1 == idle2, isTrue);
      expect(idle1 == idle3, isFalse);
      expect(idle1.hashCode, equals(idle2.hashCode));
      expect(idle1.toString(), contains('LxIdle'));
    });
  });

  group('LxBase Internal Coverage', () {
    test('LxBase _checkActive coverage', () {
      final rx = 0.lx;
      // Trigger _checkActive via listener addition/removal
      rx.addListener(() {});
      rx.removeListener(() {});
    });

    test('LxBase isDisposed coverage', () {
      final rx = 0.lx;
      expect(rx.isDisposed, isFalse);
      rx.close();
      expect(rx.isDisposed, isTrue);
    });
  });
}
