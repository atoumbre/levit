import 'dart:async';
import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('LxList.assign', () {
    test('assign replaces all elements in one notification', () async {
      final list = [1, 2, 3].lx;
      var notifyCount = 0;

      list.stream.listen((_) => notifyCount++);

      list.assign([4, 5, 6, 7]);
      await Future.microtask(() {});

      expect(list, [4, 5, 6, 7]);
      expect(notifyCount, 1);
    });

    test('assignOne replaces with single element', () async {
      final list = [1, 2, 3].lx;

      list.assignOne(99);

      expect(list, [99]);
    });
  });

  group('LxSet.assign', () {
    test('assign replaces all elements in one notification', () async {
      final set = {1, 2, 3}.lx;
      var notifyCount = 0;

      set.stream.listen((_) => notifyCount++);

      set.assign({4, 5});
      await Future.microtask(() {});

      expect(set, {4, 5});
      expect(notifyCount, 1);
    });

    test('assignOne replaces with single element', () async {
      final set = {1, 2, 3}.lx;

      set.assignOne(99);

      expect(set, {99});
    });
  });

  group('LxMap.assign', () {
    test('assign replaces all entries in one notification', () async {
      final map = {'a': 1, 'b': 2}.lx;
      var notifyCount = 0;

      map.stream.listen((_) => notifyCount++);

      map.assign({'c': 3, 'd': 4});
      await Future.microtask(() {});

      expect(map, {'c': 3, 'd': 4});
      expect(notifyCount, 1);
    });
  });

  group('LxList obscure methods', () {
    test(
      'retainWhere/fillRange/replaceRange/setAll/setRange/assign/assignOne',
      () {
        final list = [1, 2, 3, 4, 5].lx;

        // retainWhere
        list.retainWhere((i) => i.isOdd);
        expect(list, equals([1, 3, 5]));

        // fillRange (0, 2 exclusive -> indices 0, 1)
        list.fillRange(0, 2, 9);
        expect(list, equals([9, 9, 5]));

        // replaceRange
        list.replaceRange(0, 1, [0]);
        expect(list, equals([0, 9, 5]));

        // setAll
        list.setAll(0, [7, 8]);
        expect(list, equals([7, 8, 5]));

        // setRange
        list.setRange(0, 1, [1]);
        expect(list, equals([1, 8, 5]));

        // assign / assignOne
        list.assign([10, 11]);
        expect(list, equals([10, 11]));
        list.assignOne(99);
        expect(list, equals([99]));
      },
    );
  });

  group('LxMap obscure methods', () {
    test('putIfAbsent/update/updateAll/addEntries', () {
      final map = {'a': 1}.lx;

      // putIfAbsent
      map.putIfAbsent('b', () => 2);
      expect(map['b'], equals(2));
      map.putIfAbsent('a', () => 999); // existing
      expect(map['a'], equals(1));

      // update
      map.update('a', (v) => v + 1);
      expect(map['a'], equals(2));

      // updateAll
      map.updateAll((k, v) => v * 2);
      expect(map['a'], equals(4));

      // addEntries
      map.addEntries([MapEntry('c', 3)]);
      expect(map['c'], equals(3));
    });
  });
}
