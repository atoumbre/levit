import 'dart:async';
import 'package:levit_scope/levit_scope.dart';
import 'package:test/test.dart';

void main() {
  test(
    'optional lookup returns only missing registrations as absent',
    () async {
      final parent = LevitScope.root();
      final child = parent.createScope('child');
      final failure = StateError('builder failed');
      parent.lazyPut<int>(() => throw failure);
      parent.lazyPutAsync<String>(() async => throw failure);
      expect(child.findOrNull<double>(), isNull);
      expect(await child.findOrNullAsync<double>(), isNull);
      expect(() => child.findOrNull<int>(), throwsA(same(failure)));
      await expectLater(
        child.findOrNullAsync<String>(),
        throwsA(same(failure)),
      );
      await expectLater(child.findAsync<String>(), throwsA(same(failure)));
      expect(() => child.findOrNull<String>(), throwsStateError);
      await parent.dispose();
    },
  );

  test(
    'snapshots are immutable, show ancestry and pending work, omit values',
    () async {
      final parent = LevitScope.root('app');
      final child = parent.createScope('route');
      final gate = Completer<Object>();
      child.lazyPutAsync(() => gate.future);
      final resolving = child.findAsync<Object>();
      child.put<String>(() => 'secret value', tag: 'secret tag');
      final before = child.describe();
      expect(before.ancestry.single.id, parent.id);
      expect(parent.describe().ownedChildren.single.id, child.id);
      expect(before.registrations.first.pendingInitializations, 1);
      expect(
        before.registrations.map((item) => item.key).join(),
        isNot(contains('secret')),
      );
      expect(() => before.registrations.clear(), throwsUnsupportedError);
      var settled = false;
      final waiting = child.waitForInitialization().then((_) => settled = true);
      await Future<void>.delayed(Duration.zero);
      expect(settled, isFalse);
      gate.complete(Object());
      await resolving;
      await waiting;
      expect(before.registrations.first.isInstantiated, isFalse);
      expect(child.describe().registrations.first.isInstantiated, isTrue);
      await parent.dispose();
      expect(child.describe().isDisposed, isTrue);
    },
  );
}
