import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  group('Precise collection multi-channel lifecycle', () {
    test(
      'LxList notifies element, membership, length, and empty channels on add and removeLast and retires unused channels',
      () async {
        final list = <String>[].lx;
        final slot0 = list.entry(0);

        final elem = LxComputed(() => slot0.value);
        final exists = LxComputed(() => slot0.exists);
        final len = LxComputed(() => list.length);
        final empty = LxComputed(() => list.isEmpty);

        var elemHits = 0;
        var existsHits = 0;
        var lenHits = 0;
        var emptyHits = 0;
        void onElem() => elemHits++;
        void onExists() => existsHits++;
        void onLen() => lenHits++;
        void onEmpty() => emptyHits++;

        elem.addListener(onElem);
        exists.addListener(onExists);
        len.addListener(onLen);
        empty.addListener(onEmpty);

        expect(elem.value, isNull);
        expect(exists.value, isFalse);
        expect(len.value, 0);
        expect(empty.value, isTrue);

        list.add('first');
        expect(elem.value, 'first');
        expect(exists.value, isTrue);
        expect(len.value, 1);
        expect(empty.value, isFalse);
        expect(elemHits, 1);
        expect(existsHits, 1);
        expect(lenHits, 1);
        expect(emptyHits, 1);

        // Removing length and empty listeners retires those channels cleanly.
        len.removeListener(onLen);
        empty.removeListener(onEmpty);
        await len.close();
        await empty.close();

        expect(list.removeLast(), 'first');
        expect(elem.value, isNull);
        expect(exists.value, isFalse);

        elem.removeListener(onElem);
        exists.removeListener(onExists);
        await elem.close();
        await exists.close();
        await list.close();
      },
    );

    test(
      'closing LxMap with active element, membership, length, empty, and keys channels closes all channels',
      () async {
        final map = <String, int>{'a': 1}.lx;
        final entry = map.entry('a');

        final elem = LxComputed(() => entry.value);
        final mem = LxComputed(() => entry.exists);
        final len = LxComputed(() => map.length);
        final empty = LxComputed(() => map.isEmpty);
        final keys = LxComputed(() => map.keys.toList());

        void noop() {}
        elem.addListener(noop);
        mem.addListener(noop);
        len.addListener(noop);
        empty.addListener(noop);
        keys.addListener(noop);

        expect(elem.value, 1);
        expect(mem.value, isTrue);
        expect(len.value, 1);
        expect(empty.value, isFalse);
        expect(keys.value, ['a']);

        map['b'] = 2;
        expect(len.value, 2);
        expect(keys.value, ['a', 'b']);

        await map.close();
        expect(map.observedChannelCount, 0);

        await elem.close();
        await mem.close();
        await len.close();
        await empty.close();
        await keys.close();
      },
    );
  });
}
