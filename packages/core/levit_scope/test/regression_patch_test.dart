import 'dart:async';
import 'dart:mirrors';

import 'package:test/test.dart';
import 'package:levit_scope/levit_scope.dart';

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

    test('find(tag-less) falls back when cached scope throws', () {
      final root = LevitScope.root('root2');
      root.put<int>(() => 42);

      final child = root.createScope('child2');
      final unrelated = LevitScope.root('unrelated2');

      _setTypeResolutionCache(child, int, unrelated);

      expect(child.find<int>(), 42);
    });

    test('findOrNull(tag) falls back when cached scope recurses', () {
      final root = LevitScope.root('root_or_null');
      root.put<String>(() => 'root', tag: 't');

      final child = root.createScope('child_or_null');

      // Force the resolution cache to point at itself so the cached resolution
      // path throws (stack overflow) and the scope falls back to parent.
      _setResolutionCache(child, LevitScopeKey.of<String>(tag: 't'), child);

      expect(child.findOrNull<String>(tag: 't'), 'root');
    });

    test('findAsync(tag) falls back when cached scope throws', () async {
      final root = LevitScope.root('root_async');
      root.lazyPutAsync<String>(() async => 'root', tag: 't');

      final child = root.createScope('child_async');
      final unrelated = LevitScope.root('unrelated_async');

      _setResolutionCache(child, LevitScopeKey.of<String>(tag: 't'), unrelated);

      expect(await child.findAsync<String>(tag: 't'), 'root');
    });

    test('findOrNullAsync(tag) falls back when cached scope throws', () async {
      final root = LevitScope.root('root_or_null_async');
      root.put<String>(() => 'root', tag: 't');

      final child = root.createScope('child_or_null_async');
      final thrower = LevitScope.root('thrower_or_null_async');
      thrower.lazyPutAsync<String>(() async => throw StateError('boom'),
          tag: 't');

      _setResolutionCache(child, LevitScopeKey.of<String>(tag: 't'), thrower);

      expect(await child.findOrNullAsync<String>(tag: 't'), 'root');
    });
  });

  test('LevitScopeKey.toString uses debug string format', () {
    expect(LevitScopeKey.of<int>().toString(), contains('int'));
    expect(LevitScopeKey.of<int>(tag: 't').toString(), contains('_t'));
  });

  test('lazyPutAsync disposed during init throws and closes instance',
      () async {
    final scope = LevitScope.root('root3');
    int closed = 0;
    final completer = Completer<void>();

    scope.lazyPutAsync<_Disposable>(() async {
      await completer.future;
      return _Disposable(() => closed++);
    });

    final future = scope.findAsync<_Disposable>();
    final deleted = scope.delete<_Disposable>();
    expect(deleted, isTrue);

    completer.complete();

    await expectLater(future, throwsA(isA<StateError>()));
    expect(closed, 1);
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

void _setTypeResolutionCache(LevitScope scope, Type type, LevitScope cached) {
  final mirror = reflect(scope);
  final lib = mirror.type.owner as LibraryMirror;
  final symbol = MirrorSystem.getSymbol('_typeResolutionCache', lib);
  final cache = mirror.getField(symbol).reflectee as Map<Type, LevitScope>;
  cache[type] = cached;
}

class _Disposable extends LevitScopeDisposable {
  final void Function() _onClose;

  _Disposable(this._onClose);

  @override
  void onClose() {
    _onClose();
  }
}
