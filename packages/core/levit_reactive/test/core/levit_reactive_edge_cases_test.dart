import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  group('LevitReactive Edge Cases', () {
    test('LxListenerContext toJson and toString', () {
      const context = LxListenerContext(type: 'Test', id: 123, data: 'meta');
      expect(context.toJson(), {'type': 'Test', 'id': 123, 'data': 'meta'});
      expect(context.toString(), contains('type: Test'));
      expect(context.toString(), contains('id: 123'));
      expect(context.toString(), contains('data: meta'));
    });

    test('Recovery in _flushGlobalBatch when listener throws', () async {
      final v1 = 0.lx;
      final v2 = 0.lx;

      // Listener that throws
      v1.addListener(() {
        throw Exception('Listener failed');
      });

      // Since we removed the try-catch block for performance, this now throws.
      expect(
          () => Lx.batch(() {
                v1.value = 1;
                v2.value = 1;
              }),
          throwsException);

      // Verify recover: batchedNotifiers should be clear
      // We can't check internal list directly, but if we run another batch,
      // it should be clean.
      int called = 0;
      v2.addListener(() => called++);

      Lx.batch(() {
        v2.value = 2;
      });

      expect(called, 1);
    });

    test('Error handling in _notifyListeners with Middleware', () {
      final v = 0.lx;
      Object? caughtError;

      final middleware = ErrorMiddleware((e) => caughtError = e);
      Lx.addMiddleware(middleware);

      try {
        v.addListener(() => throw Exception('Sync Error'));
        v.value = 1;
        expect(caughtError, isA<Exception>());
      } finally {
        Lx.removeMiddleware(middleware);
      }
    });

    test('Error handling with multiple listeners (Fast Path throws)', () {
      final v = 0.lx;
      v.addListener(() {}); // Add first
      v.addListener(
          () => throw Exception('Multi Error')); // Add second to trigger loop

      expect(() => v.value = 1, throwsException);
    });

    test('Error handling in _notifyListeners (Fast Path throws)', () {
      final v = 0.lx;
      v.addListener(() => throw 'Silent Error');
      expect(() => v.value = 1, throwsA('Silent Error'));
    });
  });
}

class ErrorMiddleware extends LevitReactiveMiddleware {
  final void Function(Object) onError;
  ErrorMiddleware(this.onError);

  @override
  void Function(Object error, StackTrace? stack, LxReactive? context)?
      get onReactiveError => (e, s, c) => onError(e);
}
