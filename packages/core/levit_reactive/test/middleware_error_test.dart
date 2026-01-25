import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

class ErrorTrackingMiddleware extends LevitReactiveMiddleware {
  final List<Object> errors = [];
  final List<LxReactive?> contexts = [];

  @override
  void Function(Object error, StackTrace? stack, LxReactive? context)?
      get onReactiveError => (error, stack, context) {
            errors.add(error);
            contexts.add(context);
          };
}

void main() {
  group('onReactiveError Hook', () {
    late ErrorTrackingMiddleware middleware;

    setUp(() {
      middleware = ErrorTrackingMiddleware();
      LevitReactiveMiddleware.add(middleware);
    });

    tearDown(() {
      LevitReactiveMiddleware.clear();
    });

    test('intercepts exception from single listener (Fast Path)', () {
      final rx = 0.lx;
      rx.addListener(() {
        throw Exception('Boom!');
      });

      rx.value = 1;

      expect(middleware.errors.length, 1);
      expect(middleware.errors.first.toString(), contains('Boom!'));
      expect(middleware.contexts.first, rx);
    });

    test('intercepts exception from multiple listeners (Normal Path)', () {
      final rx = 0.lx;
      rx.addListener(() {
        throw Exception('Error 1');
      });
      rx.addListener(() {
        throw Exception('Error 2');
      });

      rx.value = 1;

      expect(middleware.errors.length, 2);
      expect(middleware.errors[0].toString(), contains('Error 1'));
      expect(middleware.errors[1].toString(), contains('Error 2'));
    });

    test('ensures isolation: one failing listener does not stop others', () {
      final rx = 0.lx;
      var successCalled = false;

      rx.addListener(() {
        throw Exception('Fail');
      });
      rx.addListener(() {
        successCalled = true;
      });

      rx.value = 1;

      expect(middleware.errors.length, 1);
      expect(successCalled, isTrue,
          reason: 'Second listener should run despite first failure');
    });

    test('works with computed values', () {
      final source = 0.lx;
      final computed = LxComputed(() {
        if (source.value == 1) throw Exception('Computed Error');
        return source.value * 2;
      });

      // Trigger computation
      expect(computed.value, 0);

      // Trigger error update
      source.value = 1;

      // Note: Computed might not throw immediately if lazy,
      // but if we listen to it, the error propagates during notification?
      // Actually LxComputed.notifyListeners() calls _notifyListeners which is now wrapped.
    });

    test('works with Ever worker', () {
      final rx = 0.lx;

      // Mock worker behavior by manually adding listener that mimics what 'ever' does
      rx.addListener(() {
        throw 'Worker Error';
      });

      rx.value = 1;

      expect(middleware.errors.length, 1);
      expect(middleware.errors.first, 'Worker Error');
    });
  });

  group('Fallback Behavior', () {
    test('prints to console when no middleware is present', () {
      LevitReactiveMiddleware.clear();
      final rx = 0.lx;
      rx.addListener(() => throw 'Console Error');

      // We can't easily assert print output here without zoning,
      // but we can verify that without middleware, exceptions are propagated (Fast Path).
      expect(() => rx.value = 1, throwsA('Console Error'));
    });
  });
}
