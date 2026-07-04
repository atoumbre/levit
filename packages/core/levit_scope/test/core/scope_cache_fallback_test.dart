import 'dart:mirrors';

import 'package:levit_scope/levit_scope.dart';
import 'package:test/test.dart';

void main() {
  group('Resolution cache fallback', () {
    test('find(type) clears stale parent cache when cached parent throws', () {
      final root = LevitScope.root('root_type_stale');
      root.put<String>(() => 'root');
      final child = root.createScope('child_type_stale');

      expect(child.find<String>(), 'root');
      root.delete<String>();

      expect(() => child.find<String>(), throwsException);
    });

    test('find(tag) falls back when cached scope throws', () {
      final root = LevitScope.root('root');
      root.put<String>(() => 'root', tag: 't');
      final child = root.createScope('child');
      final unrelated = LevitScope.root('unrelated');
      _setResolutionCache(child, LevitScopeKey.of<String>(tag: 't'), unrelated);
      expect(child.find<String>(tag: 't'), 'root');
    });

    test('find(tag) clears stale parent cache when cached parent throws', () {
      final root = LevitScope.root('root_tag_stale');
      root.put<String>(() => 'root', tag: 't');
      final child = root.createScope('child_tag_stale');

      expect(child.find<String>(tag: 't'), 'root');
      root.delete<String>(tag: 't');

      expect(() => child.find<String>(tag: 't'), throwsException);
    });

    test('findOrNull(tag) falls back when cached scope recurses', () {
      final root = LevitScope.root('root_or_null');
      root.put<String>(() => 'root', tag: 't');
      final child = root.createScope('child_or_null');
      _setResolutionCache(child, LevitScopeKey.of<String>(tag: 't'), child);
      expect(child.findOrNull<String>(tag: 't'), 'root');
    });

    test('findOrNull(tag) returns cached parent result', () {
      final root = LevitScope.root('root_or_null_cached');
      root.put<String>(() => 'root', tag: 't');
      final child = root.createScope('child_or_null_cached');
      final key = LevitScopeKey.of<String>(tag: 't');

      expect(child.findOrNull<String>(tag: 't'), 'root');
      expect(_resolutionCache(child).containsKey(key), isTrue);
      expect(child.findOrNull<String>(tag: 't'), 'root');
    });

    test('findOrNull(tag) evicts cached parent when value disappears', () {
      final root = LevitScope.root('root_or_null_stale');
      root.put<String>(() => 'root', tag: 't');
      final child = root.createScope('child_or_null_stale');
      final key = LevitScopeKey.of<String>(tag: 't');

      expect(child.findOrNull<String>(tag: 't'), 'root');
      expect(_resolutionCache(child).containsKey(key), isTrue);

      root.delete<String>(tag: 't');

      expect(child.findOrNull<String>(tag: 't'), isNull);
      expect(_resolutionCache(child).containsKey(key), isFalse);
    });

    test('findAsync(tag) falls back when cached scope recurses', () async {
      final root = LevitScope.root('root_async');
      root.put<String>(() => 'root', tag: 't');
      final child = root.createScope('child_async');
      _setResolutionCache(child, LevitScopeKey.of<String>(tag: 't'), child);
      expect(await child.findAsync<String>(tag: 't'), 'root');
    });

    test('findAsync(tag) clears stale parent cache when cached parent throws',
        () async {
      final root = LevitScope.root('root_async_stale');
      root.put<String>(() => 'root', tag: 't');
      final child = root.createScope('child_async_stale');

      expect(await child.findAsync<String>(tag: 't'), 'root');
      root.delete<String>(tag: 't');
      root.lazyPutAsync<String>(() async => throw StateError('stale parent'),
          tag: 't');

      await expectLater(child.findAsync<String>(tag: 't'), throwsException);
    });

    test('findOrNullAsync(tag) falls back when cached scope recurses',
        () async {
      final root = LevitScope.root('root_or_null_async');
      root.put<String>(() => 'root', tag: 't');
      final child = root.createScope('child_or_null_async');
      _setResolutionCache(child, LevitScopeKey.of<String>(tag: 't'), child);
      expect(await child.findOrNullAsync<String>(tag: 't'), 'root');
    });

    test(
        'findOrNullAsync(tag) clears stale parent cache when cached parent throws',
        () async {
      final root = LevitScope.root('root_or_null_async_stale');
      root.put<String>(() => 'root', tag: 't');
      final child = root.createScope('child_or_null_async_stale');

      expect(await child.findOrNullAsync<String>(tag: 't'), 'root');
      root.delete<String>(tag: 't');
      root.lazyPutAsync<String>(() async => throw StateError('stale parent'),
          tag: 't');

      await expectLater(
        child.findOrNullAsync<String>(tag: 't'),
        throwsA(isA<StateError>()),
      );
    });
  });
}

void _setResolutionCache(
    LevitScope scope, LevitScopeKey key, LevitScope cached) {
  _resolutionCache(scope)[key] = cached;
}

Map<LevitScopeKey, LevitScope> _resolutionCache(LevitScope scope) {
  final mirror = reflect(scope);
  final lib = mirror.type.owner as LibraryMirror;
  final symbol = MirrorSystem.getSymbol('_resolutionCache', lib);
  return mirror.getField(symbol).reflectee as Map<LevitScopeKey, LevitScope>;
}
