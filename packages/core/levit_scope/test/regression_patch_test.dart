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

      _setResolutionCache(child, 'String_t', unrelated);

      expect(child.find<String>(tag: 't'), 'root');
    });

    test('find(tagless) falls back when cached scope throws', () {
      final root = LevitScope.root('root2');
      root.put<int>(() => 42);

      final child = root.createScope('child2');
      final unrelated = LevitScope.root('unrelated2');

      _setTypeResolutionCache(child, int, unrelated);

      expect(child.find<int>(), 42);
    });
  });

  test('lazyPutAsync disposed during init throws and closes instance', () async {
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

void _setResolutionCache(LevitScope scope, String key, LevitScope cached) {
  final mirror = reflect(scope);
  final lib = mirror.type.owner as LibraryMirror;
  final symbol = MirrorSystem.getSymbol('_resolutionCache', lib);
  final cache = mirror.getField(symbol).reflectee as Map<String, LevitScope>;
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
