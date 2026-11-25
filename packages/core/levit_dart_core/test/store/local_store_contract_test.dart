import 'dart:async';
import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';

void main() {
  test('inherit by default and explicitly create local state', () async {
    final parent = LevitScope.root();
    final child = parent.createScope('child');
    final store = LevitStore((ref) => ref.own(0.lx));
    final shared = store.findIn(parent);
    expect(store.findIn(child), same(shared));
    final local = store.findIn(child, localOnly: true);
    expect(local, isNot(same(shared)));
    await child.run(() async {
      expect(store.find(localOnly: true), same(local));
    });
    await child.dispose();
    expect(local.isDisposed, isTrue);
    expect(shared.isDisposed, isFalse);
    await parent.dispose();
  });

  test('concurrent local async store reads share initialization', () async {
    final parent = LevitScope.root();
    final child = parent.createScope('child');
    var creations = 0;
    final gate = Completer<void>();
    final store = LevitStore.async((ref) async {
      creations++;
      await gate.future;
      return Object();
    });
    final shared = store.findIn(parent);
    final first = store.findIn(child, localOnly: true);
    final second = store.findIn(child, localOnly: true);
    gate.complete();
    expect(await first, same(await second));
    expect(await first, isNot(same(await shared)));
    expect(creations, 2);
    await child.run(() async {
      expect(await store.find(localOnly: true), same(await first));
    });
    await child.dispose();
    await parent.dispose();
  });

  test('store refs forward local lookup options', () async {
    final parent = LevitScope.root();
    final child = parent.createScope('child');
    final value = LevitStore((ref) => Object());
    final asyncValue = LevitStore.async((ref) async => Object());
    final shared = value.findIn(parent);
    final sharedAsync = await asyncValue.findIn(parent);
    final recipe = LevitStore.async((ref) async {
      final local = ref.findStore(value, localOnly: true);
      expect(ref.findStore(value, localOnly: true), same(local));
      expect(local, isNot(same(shared)));
      expect(
        await ref.findAsyncStore(asyncValue, localOnly: true),
        isNot(same(sharedAsync)),
      );
      return local;
    });
    await recipe.findIn(child);
    await child.dispose();
    await parent.dispose();
  });
}
