import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';

class _TokenStateMiddleware extends LevitReactiveMiddleware {
  int writes = 0;

  @override
  LevitReactiveOnSet? get onSet => (next, reactive, change) {
    return (value) {
      writes++;
      next(value);
    };
  };
}

void main() {
  tearDown(() async {
    Levit.clearStateMiddlewares();
    await Levit.reset(force: true);
  });

  group('Levit unified facade parity', () {
    test(
      'currentScope reflects active run zone and defaults to root',
      () async {
        final root = Levit.currentScope;
        final child = root.createScope('child_parity');

        expect(child.run(() => Levit.currentScope), same(child));
        expect(Levit.currentScope, same(root));

        await child.dispose();
      },
    );

    test(
      'untracked reads values without subscribing computed dependents',
      () async {
        final tracked = 1.lx;
        final ignored = 10.lx;
        var builds = 0;
        var notifications = 0;

        final derived = LxComputed(() {
          builds++;
          return tracked.value + Levit.untracked(() => ignored.value);
        });
        void listener() => notifications++;
        derived.addListener(listener);

        expect(derived.value, 11);
        expect(builds, 1);

        ignored.value = 20;
        expect(derived.value, 11);
        expect(builds, 1);
        expect(notifications, 0);

        tracked.value = 2;
        expect(derived.value, 22);
        expect(builds, 2);
        expect(notifications, 1);

        derived.removeListener(listener);
        await derived.close();
        await tracked.close();
        await ignored.close();
      },
    );

    test('isBatching reports active sync and async batch boundaries', () async {
      expect(Levit.isBatching, isFalse);

      Levit.batch(() {
        expect(Levit.isBatching, isTrue);
      });
      expect(Levit.isBatching, isFalse);

      await Levit.batchAsync(() async {
        expect(Levit.isBatching, isTrue);
        await Future<void>.delayed(Duration.zero);
        expect(Levit.isBatching, isTrue);
      });
      expect(Levit.isBatching, isFalse);
    });

    test('containsStateMiddlewareToken tracks token lifecycle', () {
      final token = Object();
      final middleware = _TokenStateMiddleware();

      expect(Levit.containsStateMiddlewareToken(token), isFalse);

      Levit.addStateMiddleware(middleware, token: token);
      expect(Levit.containsStateMiddlewareToken(token), isTrue);
      expect(Levit.containsStateMiddleware(middleware), isTrue);

      expect(Levit.removeStateMiddlewareByToken(token), isTrue);
      expect(Levit.containsStateMiddlewareToken(token), isFalse);
    });
  });
}
