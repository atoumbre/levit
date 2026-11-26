import 'dart:async';

import 'package:levit_scope/levit_scope.dart';
import 'package:levit_scope/spi.dart';
import 'package:test/test.dart';

void main() {
  group('Ancestor resolution and implicit scope zones', () {
    test(
      'find(type) throws after parent deletes previously resolved dependency',
      () async {
        final root = LevitScope.root('root_type_stale');
        root.put<String>(() => 'root');
        final child = root.createScope('child_type_stale');

        expect(child.find<String>(), 'root');
        await root.delete<String>();

        expect(() => child.find<String>(), throwsException);
      },
    );

    test(
      'find(tag) throws after parent deletes previously resolved dependency',
      () async {
        final root = LevitScope.root('root_tag_stale');
        root.put<String>(() => 'root', tag: 't');
        final child = root.createScope('child_tag_stale');

        expect(child.find<String>(tag: 't'), 'root');
        await root.delete<String>(tag: 't');

        expect(() => child.find<String>(tag: 't'), throwsException);
      },
    );

    test(
      'findOrNull(tag) returns parent value and returns null after parent deletion',
      () async {
        final root = LevitScope.root('root_or_null_stale');
        root.put<String>(() => 'root', tag: 't');
        final child = root.createScope('child_or_null_stale');

        expect(child.findOrNull<String>(tag: 't'), 'root');

        await root.delete<String>(tag: 't');

        expect(child.findOrNull<String>(tag: 't'), isNull);
      },
    );

    test(
      'findAsync(tag) propagates ancestor construction failure after replacement',
      () async {
        final root = LevitScope.root('root_async_stale');
        root.put<String>(() => 'root', tag: 't');
        final child = root.createScope('child_async_stale');

        expect(await child.findAsync<String>(tag: 't'), 'root');
        await root.delete<String>(tag: 't');
        root.lazyPutAsync<String>(
          () async => throw StateError('stale parent'),
          tag: 't',
        );

        await expectLater(child.findAsync<String>(tag: 't'), throwsStateError);
      },
    );

    test(
      'findOrNullAsync(tag) propagates ancestor failure after replacement',
      () async {
        final root = LevitScope.root('root_or_null_async_stale');
        root.put<String>(() => 'root', tag: 't');
        final child = root.createScope('child_or_null_async_stale');

        expect(await child.findOrNullAsync<String>(tag: 't'), 'root');
        await root.delete<String>(tag: 't');
        root.lazyPutAsync<String>(
          () async => throw StateError('stale parent'),
          tag: 't',
        );

        await expectLater(
          child.findOrNullAsync<String>(tag: 't'),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'Ls.currentScope resolves across run, runUnary, runBinary, and microtasks',
      () async {
        final scope = Ls.createScope('zone_handlers');
        try {
          final seen = <LevitScope>[];
          final microtaskDone = Completer<LevitScope>();
          scope.run(() {
            seen.add(Ls.currentScope);
            seen.add(Zone.current.runUnary((int _) => Ls.currentScope, 1));
            seen.add(
              Zone.current.runBinary((int _, int __) => Ls.currentScope, 1, 2),
            );
            scheduleMicrotask(() => microtaskDone.complete(Ls.currentScope));
          });

          expect(seen, everyElement(same(scope)));
          expect(await microtaskDone.future, same(scope));
        } finally {
          await scope.dispose();
        }
      },
    );

    test(
      'Ls.currentScope resolves when LsSpi.zoneScopeKey is bound directly',
      () async {
        final scope = Ls.createScope('direct_zone_key');
        try {
          final resolved = runZoned(
            () => Ls.currentScope,
            zoneValues: {LsSpi.zoneScopeKey: scope},
          );
          expect(resolved, same(scope));
          expect(Ls.currentScope, isNot(same(scope)));
        } finally {
          await scope.dispose();
        }
      },
    );

    test(
      'LsSpi.runSyncWithScope nests cleanly with scope.run in both directions',
      () async {
        final scopeA = Ls.createScope('sync_scope_a');
        final scopeB = Ls.createScope('sync_scope_b');
        try {
          LsSpi.runSyncWithScope(scopeA, () {
            expect(Ls.currentScope, same(scopeA));
            scopeB.run(() {
              expect(Ls.currentScope, same(scopeB));
              LsSpi.runSyncWithScope(scopeA, () {
                expect(Ls.currentScope, same(scopeA));
              });
              expect(Ls.currentScope, same(scopeB));
            });
            expect(Ls.currentScope, same(scopeA));
          });
        } finally {
          await scopeB.dispose();
          await scopeA.dispose();
        }
      },
    );

    test(
      'find resolves and caches an already-initialized lazyPutAsync singleton',
      () async {
        final scope = LevitScope.root('async_then_sync');
        scope.lazyPutAsync<String>(() async => 'ready');

        expect(await scope.findAsync<String>(), 'ready');
        expect(scope.find<String>(), 'ready');
        expect(scope.find<String>(), 'ready');
        await scope.dispose();
      },
    );
  });
}
