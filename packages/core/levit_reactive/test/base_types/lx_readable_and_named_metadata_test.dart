import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  group('asReadable across reactive primitives', () {
    test('exposes observation-only LxReadable views on LxBase subclasses', () {
      final variable = LxVar<int>(1, name: 'count');
      final flag = LxBool(true, name: 'flag');
      final list = LxList<String>(initial: ['a'], name: 'items');
      final map = LxMap<String, int>(initial: {'a': 1}, name: 'scores');
      final set = LxSet<int>(initial: {1}, name: 'ids');
      final computed = LxComputed<int>(() => variable.value * 2);

      final LxReadable<int> readableVar = variable.asReadable;
      final LxReadable<bool> readableFlag = flag.asReadable;
      final LxReadable<List<String>> readableList = list.asReadable;
      final LxReadable<Map<String, int>> readableMap = map.asReadable;
      final LxReadable<Set<int>> readableSet = set.asReadable;
      final LxReadable<int> readableComputed = computed.asReadable;

      expect(readableVar.value, 1);
      expect(readableFlag.value, isTrue);
      expect(readableList.value, ['a']);
      expect(readableMap.value, {'a': 1});
      expect(readableSet.value, {1});
      expect(readableComputed.value, 2);

      variable.value = 5;
      expect(readableVar.value, 5);
      expect(readableComputed.value, 10);

      computed.close();
      set.close();
      map.close();
      list.close();
      flag.close();
      variable.close();
    });
  });

  group('named metadata parameters on reactive collection constructors', () {
    test('LxList supports named initial, name, and isSensitive', () {
      final list = LxList<int>(
        initial: [1, 2],
        name: 'rows',
        isSensitive: true,
      );
      final copied = LxList<int>.from(
        [3, 4],
        name: 'copiedRows',
        isSensitive: true,
      );

      expect(list, [1, 2]);
      expect(list.name, 'rows');
      expect(list.isSensitive, isTrue);

      expect(copied, [3, 4]);
      expect(copied.name, 'copiedRows');
      expect(copied.isSensitive, isTrue);

      list.close();
      copied.close();
    });

    test('LxMap supports named initial, name, and isSensitive', () {
      final map = LxMap<String, int>(
        initial: {'a': 1},
        name: 'tokens',
        isSensitive: true,
      );
      final copied = LxMap<String, int>.from(
        {'b': 2},
        name: 'copiedTokens',
        isSensitive: true,
      );

      expect(map['a'], 1);
      expect(map.name, 'tokens');
      expect(map.isSensitive, isTrue);

      expect(copied['b'], 2);
      expect(copied.name, 'copiedTokens');
      expect(copied.isSensitive, isTrue);

      map.close();
      copied.close();
    });

    test('LxSet supports named initial, name, and isSensitive', () {
      final set = LxSet<String>(
        initial: {'x'},
        name: 'tags',
        isSensitive: true,
      );
      final copied = LxSet<String>.from(
        ['y'],
        name: 'copiedTags',
        isSensitive: true,
      );

      expect(set, {'x'});
      expect(set.name, 'tags');
      expect(set.isSensitive, isTrue);

      expect(copied, {'y'});
      expect(copied.name, 'copiedTags');
      expect(copied.isSensitive, isTrue);

      set.close();
      copied.close();
    });
  });
}
