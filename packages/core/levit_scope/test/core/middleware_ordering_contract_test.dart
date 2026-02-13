import 'package:levit_scope/levit_scope.dart';
import 'package:test/test.dart';

void main() {
  group('LevitScope middleware ordering contract', () {
    tearDown(() {
      LevitScope.removeMiddlewareByToken('order_first');
      LevitScope.removeMiddlewareByToken('order_second');
      LevitScope.removeMiddlewareByToken('slot_first');
      LevitScope.removeMiddlewareByToken('slot_replace');
      LevitScope.removeMiddlewareByToken('slot_last');
    });

    test('register hooks run in deterministic registration order', () {
      final calls = <String>[];
      LevitScope.addMiddleware(
        _RegisterOrderMiddleware('first', calls),
        token: 'order_first',
      );
      LevitScope.addMiddleware(
        _RegisterOrderMiddleware('second', calls),
        token: 'order_second',
      );

      final root = LevitScope.root('root_order');
      root.put(() => 1);

      final child = root.createScope('child_order');
      child.put(() => 2);

      expect(
        calls,
        [
          'first:root_order:put',
          'second:root_order:put',
          'first:child_order:put',
          'second:child_order:put',
        ],
      );
    });

    test('token replacement preserves middleware slot ordering', () {
      final calls = <String>[];
      LevitScope.addMiddleware(
        _RegisterOrderMiddleware('first', calls),
        token: 'slot_first',
      );
      LevitScope.addMiddleware(
        _RegisterOrderMiddleware('replace_old', calls),
        token: 'slot_replace',
      );
      LevitScope.addMiddleware(
        _RegisterOrderMiddleware('last', calls),
        token: 'slot_last',
      );

      LevitScope.addMiddleware(
        _RegisterOrderMiddleware('replace_new', calls),
        token: 'slot_replace',
      );

      final root = LevitScope.root('slot_root');
      root.put(() => 1);

      expect(calls, [
        'first:slot_root:put',
        'replace_new:slot_root:put',
        'last:slot_root:put'
      ]);
    });
  });
}

class _RegisterOrderMiddleware extends LevitScopeMiddleware {
  final String id;
  final List<String> calls;

  const _RegisterOrderMiddleware(this.id, this.calls);

  @override
  void onDependencyRegister(
    int scopeId,
    String scopeName,
    String key,
    LevitDependency info, {
    required String source,
    int? parentScopeId,
  }) {
    calls.add('$id:$scopeName:$source');
  }
}
