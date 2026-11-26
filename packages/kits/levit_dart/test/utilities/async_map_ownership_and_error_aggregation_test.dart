import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

class _OwnedMapController extends LevitController {
  late final LevitAsyncMap<String, int> map;

  @override
  void onInit() {
    super.onInit();
    map = own(LevitAsyncMap<String, int>((key, _) => key.length, name: 'docs'));
  }
}

class _ThrowingDisposeMiddleware extends LevitReactiveMiddleware {
  bool shouldThrow = false;

  @override
  LevitReactiveOnDispose? get onDispose => (next, reactive) {
    return () {
      next();
      if (shouldThrow) {
        throw StateError('dispose-middleware-failure');
      }
    };
  };
}

void main() {
  group(
    'LevitAsyncMap ownership propagation and retirement error aggregation',
    () {
      test(
        'propagates ownerId from controller-owned map to created entry state',
        () async {
          Levit.enableAutoLinking();
          final scope = Levit.createScope('owned_async_map');
          final controller = scope.put(() => _OwnedMapController());

          final value = await controller.map.fetch('abc');
          expect(value, 3);

          await scope.dispose();
          expect(controller.map.isDisposed, isTrue);
        },
      );

      test(
        'aggregates in-flight refresh drain failures and state disposal failures on evict',
        () async {
          final map = LevitAsyncMap<String, int>((key, ctx) async => 42);

          // Complete initial load so refresh replaces the completed producer.
          expect(await map.fetch('k'), 42);
          final initialEntry = map.peek('k')!;

          final middleware = _ThrowingDisposeMiddleware();
          const token = 'async-map-dispose-mw';
          Levit.addStateMiddleware(middleware, token: token);
          addTearDown(() => Levit.removeStateMiddlewareByToken(token));

          middleware.shouldThrow = true;
          final refreshing = map.refresh('k');
          refreshing.ignore();
          final evicting = map.evict('k');

          await expectLater(evicting, throwsA(isA<LxCleanupException>()));
          middleware.shouldThrow = false;

          expect(initialEntry.isClosed, isTrue);
          await expectLater(
            map.close(),
            throwsA(isA<LevitDisposalException>()),
          );
        },
      );
    },
  );
}
