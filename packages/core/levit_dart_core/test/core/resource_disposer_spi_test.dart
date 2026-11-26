import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:levit_dart_core/spi.dart';
import 'package:test/test.dart';

class _ExternalHandle {
  int disposeCount = 0;

  void release() {
    disposeCount++;
  }
}

class _AdapterController extends LevitController {
  _AdapterController(this.handle);

  final _ExternalHandle handle;

  @override
  void onInit() {
    super.onInit();
    own(handle);
  }
}

void main() {
  group('LevitResourceDisposerSpi', () {
    test(
      'registers, replaces, and unregisters custom resource adapters',
      () async {
        final token = Object();
        final events = <String>[];

        expect(LevitResourceDisposerSpi.hasAdapter(token), isFalse);

        LevitResourceDisposerSpi.registerAdapter(
          token: token,
          matches: (resource) => resource is _ExternalHandle,
          dispose: (resource) {
            events.add('first');
            (resource as _ExternalHandle).release();
          },
        );
        expect(LevitResourceDisposerSpi.hasAdapter(token), isTrue);

        // Re-registering with the same token replaces the adapter in place.
        LevitResourceDisposerSpi.registerAdapter(
          token: token,
          matches: (resource) => resource is _ExternalHandle,
          dispose: (resource) {
            events.add('replaced');
            (resource as _ExternalHandle).release();
          },
        );

        final scope = Levit.createScope('adapter-test');
        final handle = _ExternalHandle();
        scope.put(() => _AdapterController(handle));

        await scope.dispose();
        expect(handle.disposeCount, 1);
        expect(events, ['replaced']);

        expect(LevitResourceDisposerSpi.unregisterAdapter(token), isTrue);
        expect(LevitResourceDisposerSpi.hasAdapter(token), isFalse);
        expect(LevitResourceDisposerSpi.unregisterAdapter(token), isFalse);

        final secondScope = Levit.createScope('adapter-unregistered');
        try {
          expect(
            () => secondScope.put(() => _AdapterController(_ExternalHandle())),
            throwsArgumentError,
          );
        } finally {
          await secondScope.dispose();
        }
      },
    );

    test('disposes adapted resources owned through LevitRef.own', () async {
      final token = Object();
      LevitResourceDisposerSpi.registerAdapter(
        token: token,
        matches: (resource) => resource is _ExternalHandle,
        dispose: (resource) => (resource as _ExternalHandle).release(),
      );
      addTearDown(() => LevitResourceDisposerSpi.unregisterAdapter(token));

      final handleStore = LevitStore<_ExternalHandle>(
        (ref) => ref.own(_ExternalHandle()),
      );

      final scope = Levit.createScope('store-adapter-test');
      final handle = handleStore.findIn(scope);
      expect(handle.disposeCount, 0);

      await scope.dispose();
      expect(handle.disposeCount, 1);
    });
  });
}
