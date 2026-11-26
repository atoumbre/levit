import 'package:levit_reactive/levit_reactive.dart';
import 'package:levit_reactive/spi.dart';
import 'package:test/test.dart';

class _NoopMiddleware extends LevitReactiveMiddleware {}

void main() {
  tearDown(Lx.clearMiddlewares);

  group('Untracked reads, owned construction, and cleanup errors', () {
    test(
      'Lx.untracked reads directly outside observers and suppresses sync tracking inside LxComputed',
      () async {
        final source = 10.lx;
        final trigger = 0.lx;
        expect(Lx.untracked(() => source.value), 10);

        var builds = 0;
        final derived = LxComputed(() {
          builds++;
          return trigger.value + Lx.untracked(() => source.value);
        });
        void listener() {}
        derived.addListener(listener);

        expect(derived.value, 10);
        expect(builds, 1);

        source.value = 20;
        expect(derived.value, 10);
        expect(builds, 1);

        trigger.value = 1;
        expect(derived.value, 21);
        expect(builds, 2);

        derived.removeListener(listener);
        await derived.close();
        await trigger.close();
        await source.close();
      },
    );

    test(
      'LxSpi.deferAutoLink forwards nested non-returned captures to outermost createOwned',
      () async {
        final standalone = 0.lx;
        expect(LxSpi.isConstructingOwned, isFalse);
        expect(LxSpi.deferAutoLink(standalone, () {}), isFalse);

        final captured = <LxReactive>[];
        late LxVar<int> nestedSide;
        late LxVar<int> innerReturned;
        final outerReturned = LxSpi.createOwned(() {
          expect(LxSpi.isConstructingOwned, isTrue);
          innerReturned = LxSpi.createOwned(() {
            nestedSide = 1.lx;
            expect(
              LxSpi.deferAutoLink(nestedSide, () => captured.add(nestedSide)),
              isTrue,
            );
            final direct = 2.lx;
            expect(
              LxSpi.deferAutoLink(direct, () => captured.add(direct)),
              isTrue,
            );
            return direct;
          });
          return 3.lx;
        });

        expect(captured, equals([nestedSide]));

        expect(LxSpi.isDrainedSync(standalone), isTrue);
        expect(LxSpi.closeSyncOrAsync(standalone), isNull);
        await standalone.close();

        final asyncReactive = LxFuture<int>(Future<int>.value(9));
        final asyncClose = LxSpi.closeSyncOrAsync(asyncReactive);
        expect(asyncClose, isA<Future<void>>());
        await asyncClose;

        await nestedSide.close();
        await innerReturned.close();
        await outerReturned.close();
      },
    );

    test(
      'Lx.removeMiddleware clears token registration when removed by instance',
      () {
        final middleware = _NoopMiddleware();
        const token = 'sync-token';

        Lx.addMiddleware(middleware, token: token);
        expect(Lx.containsMiddlewareToken(token), isTrue);

        expect(Lx.removeMiddleware(middleware), isTrue);
        expect(Lx.containsMiddlewareToken(token), isFalse);
      },
    );

    test(
      'LxVar.close captures synchronous onCancel errors into LxCleanupException',
      () async {
        final variable = LxVar<int>(
          0,
          onCancel: () => throw StateError('sync-cancel-boom'),
        );
        void listener() {}
        variable.addListener(listener);

        await expectLater(
          variable.close(),
          throwsA(
            isA<LxCleanupException>().having(
              (e) => e.failures.single.error,
              'sync error',
              isA<StateError>(),
            ),
          ),
        );
      },
    );
  });
}
