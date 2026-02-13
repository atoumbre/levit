import 'dart:mirrors';

import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  group('LevitReactiveMiddleware token registry resilience', () {
    tearDown(() {
      Lx.clearMiddlewares();
      _clearMiddlewaresViaMirrors();
    });

    test('token replacement works even if token map is out-of-sync', () {
      Lx.clearMiddlewares();
      _clearMiddlewaresViaMirrors();

      final token = Object();
      final orphan = _NoopReactiveMiddleware();
      final replacement = _NoopReactiveMiddleware();

      final (middlewares, byToken) = _getRegistryViaMirrors();
      byToken[token] = orphan;
      expect(middlewares.contains(orphan), isFalse);

      Lx.addMiddleware(replacement, token: token);

      expect(Lx.containsMiddleware(replacement), isTrue);
      expect(Lx.containsMiddlewareToken(token), isTrue);
      expect(Lx.removeMiddlewareByToken(token), isTrue);
    });
  });
}

class _NoopReactiveMiddleware extends LevitReactiveMiddleware {
  const _NoopReactiveMiddleware();
}

(List<LevitReactiveMiddleware>, Map<Object, LevitReactiveMiddleware>)
    _getRegistryViaMirrors() {
  final classMirror = reflectClass(LevitReactiveMiddleware);
  final lib = classMirror.owner as LibraryMirror;

  final middlewaresSymbol = MirrorSystem.getSymbol('_middlewares', lib);
  final byTokenSymbol = MirrorSystem.getSymbol('_middlewaresByToken', lib);

  final middlewares = classMirror.getField(middlewaresSymbol).reflectee
      as List<LevitReactiveMiddleware>;
  final byToken = classMirror.getField(byTokenSymbol).reflectee
      as Map<Object, LevitReactiveMiddleware>;

  return (middlewares, byToken);
}

void _clearMiddlewaresViaMirrors() {
  final (middlewares, byToken) = _getRegistryViaMirrors();
  middlewares.clear();
  byToken.clear();
}
