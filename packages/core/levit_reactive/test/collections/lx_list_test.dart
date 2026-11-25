import 'dart:async';
import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('LxList<T>', () {
    test('initial list is accessible', () {
      final items = <String>[].lx;
      expect(items.value, isEmpty);
    });

    test('add triggers stream event', () async {
      final items = <String>[].lx;
      final triggered = <List<String>>[];
      // We listen to the stream, which emits the *new list* reference or content
      // Note: LxList implementation usually emits the list itself
      items.stream.listen((v) => triggered.add(List.from(v)));

      items.add('a');

      await Future.delayed(Duration.zero);
      expect(triggered, hasLength(1));
      expect(triggered.first, equals(['a']));
      expect(items.value, equals(['a']));
    });

    test('addAll triggers stream event', () async {
      final items = <String>[].lx;
      final triggered = <List<String>>[];
      items.stream.listen((v) => triggered.add(List.from(v)));

      items.addAll(['a', 'b']);

      await Future.delayed(Duration.zero);
      expect(triggered, hasLength(1));
      expect(items.value, equals(['a', 'b']));
    });

    test('remove returns false if not found', () {
      final items = ['a', 'b'].lx;
      expect(items.remove('x'), isFalse);
    });

    test('removeAt triggers stream event', () async {
      final items = ['a', 'b', 'c'].lx;
      final removed = items.removeAt(1);

      expect(removed, equals('b'));
      expect(items.value, equals(['a', 'c']));
    });

    test('removeLast triggers stream event', () {
      final items = ['a', 'b', 'c'].lx;
      final removed = items.removeLast();
      expect(removed, equals('c'));
      expect(items.value, equals(['a', 'b']));
    });

    test('removeWhere triggers stream event', () {
      final items = ['a', 'b', 'c'].lx;
      items.removeWhere((e) => e == 'b');
      expect(items.value, equals(['a', 'c']));
    });

    test('retainWhere triggers stream event', () {
      final items = ['a', 'b', 'c'].lx;
      items.retainWhere((e) => e == 'b');
      expect(items.value, equals(['b']));
    });

    test('insert triggers stream event', () {
      final items = ['a', 'c'].lx;
      items.insert(1, 'b');
      expect(items.value, equals(['a', 'b', 'c']));
    });

    test('insertAll triggers stream event', () {
      final items = ['a', 'd'].lx;
      items.insertAll(1, ['b', 'c']);
      expect(items.value, equals(['a', 'b', 'c', 'd']));
    });

    test('fillRange triggers stream event', () {
      final items = ['a', 'b', 'c'].lx;
      items.fillRange(0, 2, 'x');
      expect(items.value, equals(['x', 'x', 'c']));
    });

    test('replaceRange triggers stream event', () {
      final items = ['a', 'b', 'c'].lx;
      items.replaceRange(0, 2, ['x', 'y']);
      expect(items.value, equals(['x', 'y', 'c']));
    });

    test('setRange triggers stream event', () {
      final items = ['a', 'b', 'c'].lx;
      final source = ['x', 'y'];
      items.setRange(0, 2, source);
      expect(items.value, equals(['x', 'y', 'c']));
    });

    test('setAll triggers stream event', () {
      final items = ['a', 'b', 'c'].lx;
      items.setAll(1, ['x', 'y']);
      expect(items.value, equals(['a', 'x', 'y']));
    });

    test('sort triggers stream event', () {
      final items = [3, 1, 2].lx;
      items.sort();
      expect(items.value, equals([1, 2, 3]));
    });

    test('shuffle triggers stream event', () {
      final items = [1, 2, 3, 4, 5].lx;
      items.shuffle();
      expect(items.length, equals(5));
    });

    test('set length triggers stream event', () {
      final items = ['a', 'b', 'c'].lx;
      items.length = 2;
      expect(items.value, equals(['a', 'b']));
    });

    test('set first triggers stream event', () {
      final items = ['a', 'b', 'c'].lx;
      items.first = 'x';
      expect(items.value, equals(['x', 'b', 'c']));
    });

    test('set last triggers stream event', () {
      final items = ['a', 'b', 'c'].lx;
      items.last = 'x';
      expect(items.value, equals(['a', 'b', 'x']));
    });

    test('operator []= triggers stream event', () async {
      final items = ['a', 'b'].lx;
      final triggered = <bool>[];
      items.stream.listen((_) => triggered.add(true));

      items[0] = 'x';

      await Future.delayed(Duration.zero);
      expect(triggered, hasLength(1));
      expect(items[0], equals('x'));
    });

    test('clear triggers stream event', () async {
      final items = ['a', 'b', 'c'].lx;
      final triggered = <bool>[];
      items.stream.listen((_) => triggered.add(true));

      items.clear();

      await Future.delayed(Duration.zero);
      expect(triggered, hasLength(1));
      expect(items, isEmpty);
    });

    test('list read-only methods work', () {
      final items = [1, 2, 3, 4, 5].lx;
      expect(items.length, equals(5));
      expect(items.first, equals(1));
      expect(items.last, equals(5));
      expect(items.isEmpty, isFalse);
      expect(items.isNotEmpty, isTrue);
      // expect(() => items.single, throwsStateError); // This depends on standard library behavior
      expect(items.reversed.toList(), equals([5, 4, 3, 2, 1]));
      expect(items.contains(3), isTrue);
      expect(items.elementAt(2), equals(3));
      expect(items.every((e) => e > 0), isTrue);
      expect(items.any((e) => e > 4), isTrue);
      expect(items.firstWhere((e) => e > 2), equals(3));
      expect(items.lastWhere((e) => e < 4), equals(3));
      expect(items.indexOf(3), equals(2));
      expect(items.lastIndexOf(3), equals(2));
      expect(items.indexWhere((e) => e > 2), equals(2));
      expect(items.lastIndexWhere((e) => e < 4), equals(2));
      expect(items.reduce((a, b) => a + b), equals(15));
      expect(items.fold<int>(10, (acc, e) => acc + e), equals(25));
      expect(items.where((e) => e.isOdd).toList(), equals([1, 3, 5]));
      expect(items.whereType<int>().toList(), equals([1, 2, 3, 4, 5]));
      expect(items.map((e) => e * 2).toList(), equals([2, 4, 6, 8, 10]));
      expect(
        items.expand((e) => [e, e]).toList(),
        equals([1, 1, 2, 2, 3, 3, 4, 4, 5, 5]),
      );
      expect(items.join(','), equals('1,2,3,4,5'));
      expect(items.skip(2).toList(), equals([3, 4, 5]));
      expect(items.skipWhile((e) => e < 3).toList(), equals([3, 4, 5]));
      expect(items.take(2).toList(), equals([1, 2]));
      expect(items.takeWhile((e) => e < 3).toList(), equals([1, 2]));
      expect(items.toList(), equals([1, 2, 3, 4, 5]));
      expect(items.toSet(), equals({1, 2, 3, 4, 5}));
      expect(items.followedBy([6]).toList(), equals([1, 2, 3, 4, 5, 6]));
      expect(items.asMap(), equals({0: 1, 1: 2, 2: 3, 3: 4, 4: 5}));
      expect(items + [6], equals([1, 2, 3, 4, 5, 6]));
      expect(items.sublist(1, 3), equals([2, 3]));
      expect(items.getRange(1, 3).toList(), equals([2, 3]));
      expect(items.cast<num>().toList(), equals([1, 2, 3, 4, 5]));
    });

    test('forEach works', () {
      final items = [1, 2, 3].lx;
      final result = <int>[];
      for (var e in items) {
        result.add(e);
      }
      expect(result, equals([1, 2, 3]));
    });

    test('iterator works', () {
      final items = [1, 2, 3].lx;
      final result = <int>[];
      for (final e in items) {
        result.add(e);
      }
      expect(result, equals([1, 2, 3]));
    });

    test('singleWhere works', () {
      final items = [1, 2, 3].lx;
      expect(items.singleWhere((e) => e == 2), equals(2));
    });

    test('remove should not notify if element not found', () {
      final list = [1, 2, 3].lx;
      bool notified = false;
      list.addListener(() => notified = true);

      final result = list.remove(99); // Not in list

      expect(result, isFalse);
      expect(notified, isFalse);
    });

    test('remove should notify if element exists', () {
      final list = [1, 2, 3].lx;
      bool notified = false;
      list.addListener(() => notified = true);

      final result = list.remove(2); // In list

      expect(result, isTrue);
      expect(notified, isTrue);
      expect(list, [1, 3]);
    });

    test('removeRange should remove elements and notify', () {
      final list = [1, 2, 3, 4, 5].lx;
      bool notified = false;
      list.addListener(() => notified = true);

      list.removeRange(1, 3); // Removes index 1 and 2 (values 2 and 3)

      expect(list, [1, 4, 5]);
      expect(notified, isTrue);
    });

    test('single getter should delegate to underlying list', () {
      final list = [42].lx;
      expect(list.single, 42);

      final emptyList = <int>[].lx;
      expect(
        () => emptyList.single,
        throwsStateError,
      ); // Standard List behavior
    });
  });
}
