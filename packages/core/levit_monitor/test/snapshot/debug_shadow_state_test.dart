import 'package:levit_monitor/levit_monitor.dart';
import 'package:test/test.dart';

void main() {
  test('Debug Scope Remove', () {
    final state = StateSnapshot();
    final sid = 'sid';

    state.applyEvent(ScopeCreateEvent(
      sessionId: sid,
      scopeId: 1,
      scopeName: 's1',
      parentScopeId: null,
    ));

    print('After create: ${state.scopes.keys}');
    expect(state.scopes.containsKey(1), isTrue);

    state.applyEvent(ScopeDisposeEvent(
      sessionId: sid,
      scopeId: 1,
      scopeName: 's1',
    ));

    print('After dispose: ${state.scopes.keys}');
    expect(state.scopes.containsKey(1), isFalse);
  });
}
