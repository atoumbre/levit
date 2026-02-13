import 'dart:mirrors';

import 'package:levit_scope/levit_scope.dart';
import 'package:test/test.dart';

void main() {
  group('LevitScope middleware registry resilience', () {
    tearDown(() {
      // Best-effort cleanup; the underlying lists/maps are private statics.
      _clearMiddlewaresViaMirrors();
    });

    test('token replacement works even if token map is out-of-sync', () {
      _clearMiddlewaresViaMirrors();

      final token = Object();
      final orphan = _NoopMiddleware();
      final replacement = _NoopMiddleware();

      final (middlewares, byToken) = _getRegistryViaMirrors();
      byToken[token] = orphan;
      expect(middlewares.contains(orphan), isFalse);

      // Should take the "existingByToken != null && index < 0" branch and still
      // register the replacement middleware without crashing.
      LevitScope.addMiddleware(replacement, token: token);

      expect(LevitScope.containsMiddleware(replacement), isTrue);
      expect(LevitScope.containsMiddlewareToken(token), isTrue);
      LevitScope.removeMiddlewareByToken(token);
    });
  });
}

class _NoopMiddleware extends LevitScopeMiddleware {}

(List<LevitScopeMiddleware>, Map<Object, LevitScopeMiddleware>)
    _getRegistryViaMirrors() {
  final classMirror = reflectClass(LevitScope);
  final lib = classMirror.owner as LibraryMirror;

  final middlewaresSymbol = MirrorSystem.getSymbol('_middlewares', lib);
  final byTokenSymbol = MirrorSystem.getSymbol('_middlewaresByToken', lib);

  final middlewares = classMirror.getField(middlewaresSymbol).reflectee
      as List<LevitScopeMiddleware>;
  final byToken = classMirror.getField(byTokenSymbol).reflectee
      as Map<Object, LevitScopeMiddleware>;

  return (middlewares, byToken);
}

void _clearMiddlewaresViaMirrors() {
  final (middlewares, byToken) = _getRegistryViaMirrors();
  middlewares.clear();
  byToken.clear();
}
