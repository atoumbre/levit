import 'dart:mirrors';

import 'package:levit_scope/levit_scope.dart';
import 'package:test/test.dart';

void main() {
  group('Resolution cache fallback', () {
    test('find(tag) falls back when cached scope throws', () {
      final root = LevitScope.root('root');
      root.put<String>(() => 'root', tag: 't');
      final child = root.createScope('child');
      final unrelated = LevitScope.root('unrelated');
      _setResolutionCache(child, LevitScopeKey.of<String>(tag: 't'), unrelated);
      expect(child.find<String>(tag: 't'), 'root');
    });

    test('findOrNull(tag) falls back when cached scope recurses', () {
      final root = LevitScope.root('root_or_null');
      root.put<String>(() => 'root', tag: 't');
      final child = root.createScope('child_or_null');
      _setResolutionCache(child, LevitScopeKey.of<String>(tag: 't'), child);
      expect(child.findOrNull<String>(tag: 't'), 'root');
    });

    test('findAsync(tag) falls back when cached scope recurses', () async {
      final root = LevitScope.root('root_async');
      root.put<String>(() => 'root', tag: 't');
      final child = root.createScope('child_async');
      _setResolutionCache(child, LevitScopeKey.of<String>(tag: 't'), child);
      expect(await child.findAsync<String>(tag: 't'), 'root');
    });

    test('findOrNullAsync(tag) falls back when cached scope recurses',
        () async {
      final root = LevitScope.root('root_or_null_async');
      root.put<String>(() => 'root', tag: 't');
      final child = root.createScope('child_or_null_async');
      _setResolutionCache(child, LevitScopeKey.of<String>(tag: 't'), child);
      expect(await child.findOrNullAsync<String>(tag: 't'), 'root');
    });
  });
}

void _setResolutionCache(
    LevitScope scope, LevitScopeKey key, LevitScope cached) {
  final mirror = reflect(scope);
  final lib = mirror.type.owner as LibraryMirror;
  final symbol = MirrorSystem.getSymbol('_resolutionCache', lib);
  final cache =
      mirror.getField(symbol).reflectee as Map<LevitScopeKey, LevitScope>;
  cache[key] = cached;
}
