import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';
import 'dart:async';

void main() {
  group('Implicit DI Scopes (LevitScope.run)', () {
    setUp(() {
      Levit.reset(force: true);
    });

    test('finds dependency in implicit scope', () {
      final scope = Levit.createScope('test');
      scope.put<String>(() => 'scoped_value');
      Levit.put<String>(() => 'global_value');

      scope.run(() {
        expect(Levit.find<String>(), 'scoped_value');
      });

      // Outside match global
      expect(Levit.find<String>(), 'global_value');
    });

    test('falls back to global if not in implicit scope', () {
      final scope = Levit.createScope('test');
      // scope is empty
      Levit.put<String>(() => 'global_value');

      scope.run(() {
        expect(Levit.find<String>(), 'global_value');
      });
    });

    test('persists across async gaps', () async {
      final scope = Levit.createScope('test');
      scope.put<String>(() => 'scoped_value');

      await scope.run(() async {
        await Future.delayed(Duration.zero);
        expect(Levit.find<String>(), 'scoped_value');
      });
    });

    test('nested scopes respect innermost', () {
      final outer = Levit.createScope('outer');
      outer.put<String>(() => 'outer_value');

      final inner = Levit.createScope('inner');
      inner.put<String>(() => 'inner_value');

      outer.run(() {
        expect(Levit.find<String>(), 'outer_value');

        inner.run(() {
          expect(Levit.find<String>(), 'inner_value');
        });

        expect(Levit.find<String>(), 'outer_value');
      });
    });

    test('isRegistered checks implicit scope', () {
      final scope = Levit.createScope('test');
      scope.put<String>(() => 'scoped');

      expect(Levit.isRegistered<String>(), false);

      scope.run(() {
        expect(Levit.isRegistered<String>(), true);
      });
    });

    test('findOrNull respects implicit scope', () {
      final scope = Levit.createScope('test');
      scope.put<String>(() => 'scoped');

      expect(Levit.findOrNull<String>(), null);

      scope.run(() {
        expect(Levit.findOrNull<String>(), 'scoped');
      });
    });
  });
}
