import 'dart:async';
import 'package:levit_dart_core/levit_testing.dart';
import 'package:test/test.dart';

void main() {
  setUp(Levit.enableAutoLinking);

  test(
    'definition identity survives shared tags and covariant observation',
    () async {
      final scope = LevitScope.root();
      var builds = 0;
      final first = LevitStore<int>((_) {
        builds++;
        return 1;
      });
      final second = LevitStore<int>((_) => 2);
      final LevitStore<num> widened = first;
      expect(first.findIn(scope, tag: 'shared'), 1);
      expect(second.findIn(scope, tag: 'shared'), 2);
      expect(widened.findIn(scope, tag: 'shared'), 1);
      expect(builds, 1);
      expect(scope.registeredCount, 2);
      await scope.dispose();
    },
  );

  test(
    'sync and async overrides are local recipes owned by receiving scopes',
    () async {
      final store = LevitStore((ref) => ref.own(1.lx));
      final asyncStore = LevitAsyncStore((ref) async => ref.own(2.lx));
      final parent = LevitScope.root();
      final original = store.findIn(parent);
      final child = parent.createScope('child');
      child.applyOverrides([
        store.overrideWith((ref) => ref.own(10.lx)),
        asyncStore.overrideWith((ref) async => ref.own(20.lx)),
      ]);
      final overridden = store.findIn(child);
      final asyncOverridden = await asyncStore.findIn(child);
      expect(overridden.value, 10);
      expect(asyncOverridden.value, 20);
      expect(store.findIn(parent), same(original));
      final sibling = parent.createScope('sibling');
      expect(store.findIn(sibling), same(original));
      final local = store.findIn(sibling, localOnly: true);
      expect(local, isNot(same(original)));
      expect(() => child.overrideStore(store, (_) => 9.lx), throwsStateError);
      await child.dispose();
      expect(overridden.isDisposed, isTrue);
      expect(asyncOverridden.isDisposed, isTrue);
      expect(original.isDisposed, isFalse);
      await parent.dispose();
      expect(local.isDisposed, isTrue);
    },
  );

  test(
    'ref typed lookups preserve variants and local inheritance choices',
    () async {
      final scope = LevitScope.root();
      final a = LevitStore((_) => Object());
      final b = LevitAsyncStore((_) async => Object());
      final ancestor = a.findIn(scope);
      final child = scope.createScope('child');
      final combined = LevitAsyncStore(
        (ref) async => (
          ref.findStore(a),
          ref.findStore(a, localOnly: true),
          await ref.findAsyncStore(b, tag: 'variant', localOnly: true),
        ),
      );
      final values = await combined.findIn(child);
      expect(values.$1, same(ancestor));
      expect(values.$2, isNot(same(ancestor)));
      expect(values.$3, same(await b.findIn(child, tag: 'variant')));
      await scope.dispose();
    },
  );

  test(
    'test harness waits for real completion and reports teardown failure',
    () async {
      final gate = Completer<void>();
      final harness = LevitTestScope();
      final store = LevitStore((ref) {
        ref.onDispose(() => gate.future);
        return 1;
      });
      harness.run(() => store.find());
      var done = false;
      final closing = harness.close().then((_) => done = true);
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);
      gate.complete();
      await closing;
      expect(harness.scope.isDisposed, isTrue);
      final broken = LevitTestScope();
      final failure = LevitStore((ref) {
        ref.onDispose(() => throw StateError('cleanup'));
        return 1;
      });
      failure.findIn(broken.scope);
      await expectLater(broken.close(), throwsA(isA<LevitTestException>()));
    },
  );
}
