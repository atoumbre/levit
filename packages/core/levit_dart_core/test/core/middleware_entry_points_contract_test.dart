import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';

void main() {
  group('Levit middleware entry-point contracts', () {
    tearDown(() {
      Levit.removeDependencyMiddlewareByToken('dep_token');
      Levit.removeStateMiddlewareByToken('state_token');
      Lx.clearMiddlewares();
      Levit.reset(force: true);
    });

    test('addDependencyMiddleware is idempotent by instance identity', () {
      final calls = <String>[];
      final middleware = _ScopeRecordingMiddleware('single', calls);

      Levit.addDependencyMiddleware(middleware);
      Levit.addDependencyMiddleware(middleware);

      Levit.put(() => 1);

      expect(calls, ['single']);
      Levit.removeDependencyMiddleware(middleware);
    });

    test('addDependencyMiddleware token replacement is deterministic', () {
      final calls = <String>[];
      final first = _ScopeRecordingMiddleware('first', calls);
      final second = _ScopeRecordingMiddleware('second', calls);

      Levit.addDependencyMiddleware(first, token: 'dep_token');
      Levit.addDependencyMiddleware(second, token: 'dep_token');

      Levit.put(() => 1);

      expect(calls, ['second']);
      expect(Levit.removeDependencyMiddlewareByToken('dep_token'), isTrue);
      expect(Levit.removeDependencyMiddlewareByToken('dep_token'), isFalse);
    });

    test('addStateMiddleware is idempotent by instance identity', () {
      final calls = <String>[];
      final middleware = _ReactiveRecordingMiddleware('single', calls);

      Levit.addStateMiddleware(middleware);
      Levit.addStateMiddleware(middleware);

      final value = 0.lx;
      value.value = 1;

      expect(calls, ['single']);
      Levit.removeStateMiddleware(middleware);
    });

    test('addStateMiddleware token replacement is deterministic', () {
      final calls = <String>[];
      final first = _ReactiveRecordingMiddleware('first', calls);
      final second = _ReactiveRecordingMiddleware('second', calls);

      Levit.addStateMiddleware(first, token: 'state_token');
      Levit.addStateMiddleware(second, token: 'state_token');

      final value = 0.lx;
      value.value = 1;

      expect(calls, ['second']);
      expect(Levit.removeStateMiddlewareByToken('state_token'), isTrue);
      expect(Levit.removeStateMiddlewareByToken('state_token'), isFalse);
    });
  });
}

class _ScopeRecordingMiddleware extends LevitScopeMiddleware {
  final String id;
  final List<String> calls;

  const _ScopeRecordingMiddleware(this.id, this.calls);

  @override
  void onDependencyRegister(
    int scopeId,
    String scopeName,
    String key,
    LevitDependency info, {
    required String source,
    int? parentScopeId,
  }) {
    calls.add(id);
  }
}

class _ReactiveRecordingMiddleware implements LevitReactiveMiddleware {
  final String id;
  final List<String> calls;

  _ReactiveRecordingMiddleware(this.id, this.calls);

  @override
  LxOnSet? get onSet => (next, reactive, change) {
        calls.add(id);
        return next;
      };

  @override
  LxOnBatch? get onBatch => null;

  @override
  LxOnDispose? get onDispose => null;

  @override
  void Function(LxReactive)? get onInit => null;

  @override
  void Function(LxReactive, List<LxReactive>)? get onGraphChange => null;

  @override
  void Function(LxReactive, LxListenerContext?)? get startedListening => null;

  @override
  void Function(LxReactive, LxListenerContext?)? get stoppedListening => null;

  @override
  void Function(Object, StackTrace?, LxReactive?)? get onReactiveError => null;
}
