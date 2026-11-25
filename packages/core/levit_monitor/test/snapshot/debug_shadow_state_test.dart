import 'package:test/test.dart';
import 'package:levit_monitor/spi.dart';

void main() {
  test('Debug Scope Remove', () {
    final state = LevitStateSnapshot();
    final sid = 'sid';

    state.applyEvent(
      LevitScopeCreateEvent(
        sessionId: sid,
        scopeId: 1,
        scopeName: 's1',
        parentScopeId: null,
      ),
    );

    print('After create: ${state.scopes.keys}');
    expect(state.scopes.containsKey(1), isTrue);

    state.applyEvent(
      LevitScopeDisposeEvent(sessionId: sid, scopeId: 1, scopeName: 's1'),
    );

    print('After dispose: ${state.scopes.keys}');
    expect(state.scopes.containsKey(1), isFalse);
  });
}
