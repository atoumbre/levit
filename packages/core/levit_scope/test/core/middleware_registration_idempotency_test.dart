import 'package:levit_scope/levit_scope.dart';
import 'package:test/test.dart';

void main() {
  group('LevitScope middleware registration idempotency', () {
    tearDown(() {
      LevitScope.removeMiddlewareByToken('scope_token');
      LevitScope.removeMiddlewareByToken('ls_scope_token');
    });

    test('adding same middleware instance twice is idempotent', () {
      final calls = <String>[];
      final middleware = _ScopeRecordingMiddleware('single', calls);

      LevitScope.addMiddleware(middleware);
      LevitScope.addMiddleware(middleware);

      LevitScope.root('idempotent_scope');

      expect(calls.where((entry) => entry == 'single').length, 1);
      LevitScope.removeMiddleware(middleware);
    });

    test('token-based registration replaces previous middleware', () {
      final calls = <String>[];
      final first = _ScopeRecordingMiddleware('first', calls);
      final second = _ScopeRecordingMiddleware('second', calls);

      LevitScope.addMiddleware(first, token: 'scope_token');
      LevitScope.addMiddleware(second, token: 'scope_token');

      LevitScope.root('token_scope');

      expect(calls, contains('second'));
      expect(calls, isNot(contains('first')));
      expect(LevitScope.containsMiddleware(first), isFalse);
      expect(LevitScope.containsMiddleware(second), isTrue);
      expect(LevitScope.containsMiddlewareToken('scope_token'), isTrue);
      expect(LevitScope.removeMiddlewareByToken('scope_token'), isTrue);
      expect(LevitScope.containsMiddlewareToken('scope_token'), isFalse);
    });

    test('Ls wrapper supports token-based middleware registration', () {
      final middleware = _ScopeRecordingMiddleware('ls', []);

      Ls.addMiddleware(middleware, token: 'ls_scope_token');
      expect(LevitScope.containsMiddlewareToken('ls_scope_token'), isTrue);
      expect(Ls.removeMiddlewareByToken('ls_scope_token'), isTrue);
      expect(LevitScope.containsMiddlewareToken('ls_scope_token'), isFalse);
    });

    test(
      'removing an instance clears its tokens and preserves others',
      () async {
        final calls = <String>[];
        final removed = _ScopeRecordingMiddleware('removed', calls);
        final retained = _ScopeRecordingMiddleware('retained', calls);
        final token = Object();
        final alias = Object();
        final retainedToken = Object();
        addTearDown(() {
          LevitScope.removeMiddleware(removed);
          LevitScope.removeMiddleware(retained);
          LevitScope.removeMiddlewareByToken(token);
          LevitScope.removeMiddlewareByToken(alias);
          LevitScope.removeMiddlewareByToken(retainedToken);
        });

        LevitScope.addMiddleware(removed, token: token);
        LevitScope.addMiddleware(removed, token: alias);
        LevitScope.addMiddleware(retained, token: retainedToken);
        LevitScope.removeMiddleware(removed);

        expect(LevitScope.containsMiddleware(removed), isFalse);
        expect(LevitScope.containsMiddlewareToken(token), isFalse);
        expect(LevitScope.containsMiddlewareToken(alias), isFalse);
        expect(LevitScope.containsMiddlewareToken(retainedToken), isTrue);
        final scope = LevitScope.root('after_instance_removal');
        addTearDown(scope.dispose);
        expect(calls, ['retained']);

        // Old tokens must not remove a later registration of the same instance.
        LevitScope.addMiddleware(removed);
        expect(LevitScope.removeMiddlewareByToken(token), isFalse);
        expect(LevitScope.removeMiddlewareByToken(alias), isFalse);
        expect(LevitScope.containsMiddleware(removed), isTrue);
        expect(LevitScope.removeMiddlewareByToken(retainedToken), isTrue);
        expect(LevitScope.containsMiddleware(retained), isFalse);
      },
    );

    test(
      'token can be attached to an existing middleware without duplicates',
      () {
        final calls = <String>[];
        final middleware = _ScopeRecordingMiddleware('attach', calls);

        LevitScope.addMiddleware(middleware);
        LevitScope.addMiddleware(middleware, token: 'attach_token');
        LevitScope.addMiddleware(middleware, token: 'attach_token');

        LevitScope.root('attach_token_scope');

        expect(calls.where((id) => id == 'attach').length, 1);
        expect(LevitScope.containsMiddlewareToken('attach_token'), isTrue);
        expect(LevitScope.removeMiddlewareByToken('attach_token'), isTrue);
        LevitScope.removeMiddleware(middleware);
      },
    );
  });
}

class _ScopeRecordingMiddleware extends LevitScopeMiddleware {
  final String id;
  final List<String> calls;

  const _ScopeRecordingMiddleware(this.id, this.calls);

  @override
  void onScopeCreate(int scopeId, String scopeName, int? parentScopeId) {
    calls.add(id);
  }
}
