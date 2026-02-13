import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  group('Middleware registration idempotency', () {
    tearDown(() {
      Lx.clearMiddlewares();
    });

    test('adding the same middleware instance twice is idempotent', () {
      final calls = <String>[];
      final middleware = _RecordingMiddleware('single', calls);

      Lx.addMiddleware(middleware);
      Lx.addMiddleware(middleware);

      final state = 0.lx;
      state.value = 1;

      expect(calls, ['single']);
    });

    test('token-based registration replaces previous middleware for token', () {
      final calls = <String>[];
      final first = _RecordingMiddleware('first', calls);
      final second = _RecordingMiddleware('second', calls);

      Lx.addMiddleware(first, token: 'history');
      Lx.addMiddleware(second, token: 'history');

      final state = 0.lx;
      state.value = 1;

      expect(calls, ['second']);
      expect(Lx.containsMiddleware(first), isFalse);
      expect(Lx.containsMiddleware(second), isTrue);
      expect(Lx.containsMiddlewareToken('history'), isTrue);
      expect(Lx.removeMiddlewareByToken('history'), isTrue);
      expect(Lx.containsMiddlewareToken('history'), isFalse);
    });

    test('token can be attached to an existing middleware without duplicates',
        () {
      final calls = <String>[];
      final middleware = _RecordingMiddleware('same', calls);

      Lx.addMiddleware(middleware);
      Lx.addMiddleware(middleware, token: 'shared');
      Lx.addMiddleware(middleware, token: 'shared');

      final state = 0.lx;
      state.value = 1;

      expect(calls, ['same']);
    });
  });
}

class _RecordingMiddleware extends LevitReactiveMiddleware {
  final String id;
  final List<String> calls;

  const _RecordingMiddleware(this.id, this.calls);

  @override
  LxOnSet? get onSet => (next, reactive, change) {
        calls.add(id);
        return next;
      };
}
