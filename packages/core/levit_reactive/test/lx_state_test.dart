import 'dart:async';

import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

class CounterState extends LxState<int> {
  CounterState(super.initial);

  void increment() => emit(value + 1);

  @override
  void emit(int state) => super.emit(state);
}

class UserState {
  final String name;
  final int age;

  const UserState({required this.name, required this.age});

  UserState copyWith({String? name, int? age}) {
    return UserState(
      name: name ?? this.name,
      age: age ?? this.age,
    );
  }
}

void main() {
  group('LxState', () {
    test('value matches initial', () {
      final state = LxState(10);
      expect(state.value, 10);
    });

    test('emit updates value and notifies', () {
      final state = CounterState(0);
      int calls = 0;
      state.addListener(() => calls++);

      expect(state.value, 0);
      state.increment();
      expect(state.value, 1);
      expect(calls, 1);
    });

    test('emit does not notify if value is same', () {
      final state = CounterState(5);
      int calls = 0;
      state.addListener(() => calls++);

      state.emit(5);
      expect(calls, 0);
    });

    test('update modifies state via reducer', () {
      final state = LxState(10);
      state.update((s) => s * 2);
      expect(state.value, 20);
    });

    test('works with complex objects', () {
      final state = LxState(const UserState(name: 'Alice', age: 30));

      state.update((s) => s.copyWith(age: 31));
      expect(state.value.age, 31);
      expect(state.value.name, 'Alice');
    });

    test('asReactive exposes read-only interface', () {
      final state = CounterState(0);
      final reactive = state.asReactive;

      expect(reactive.value, 0);
      state.increment();
      expect(reactive.value, 1);

      // reactive.emit(2); // specific checking that this method doesn't exist on interface is static
    });

    test('bind throws to preserve immutability', () {
      final state = LxState(0);
      expect(() => state.bind(Stream.value(1)), throwsStateError);
    });

    test('mutate/updateValue are not available', () {
      final state = LxState(1);
      final dynamic dyn = state;
      expect(
        () => dyn.mutate((int v) {}),
        throwsA(isA<NoSuchMethodError>()),
      );
      expect(
        () => dyn.updateValue((int v) => v + 1),
        throwsA(isA<NoSuchMethodError>()),
      );
    });
  });
}
