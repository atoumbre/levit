import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';

void main() {
  setUp(() {
    Levit.enableAutoLinking();
    Levit.reset(force: true);
  });

  tearDown(() {
    Levit.disableAutoLinking();
    Levit.reset(force: true);
  });

  group('LevitStore', () {
    test('builder runs exactly once (Init-Once)', () {
      int buildCount = 0;
      final store = LevitStore((ref) {
        buildCount++;
        return 42;
      });

      expect(buildCount, 0);
      expect(store.find(), 42);
      expect(buildCount, 1);

      // Subsequent access should not rebuild
      expect(store.find(), 42);
      expect(buildCount, 1);
    });

    test('ignores dependency changes (Static)', () {
      final dep = 0.lx;

      final store = LevitStore((ref) {
        // Read dependency
        final value = dep.value;
        return value * 10;
      });

      expect(store.find(), 0); // initial: 0 * 10

      // Change dependency
      dep.value = 5;

      // Store should remain static (0), unlike LevitStore which would become 50
      expect(store.find(), 0);
    });

    test('captures and disposes implicit orphans (New Behavior)', () {
      late LxReactive orphan;

      final store = LevitStore((ref) {
        orphan = 0.lx; // Implicit orphan (not returned, not used)
        return 'done';
      });

      store.find();

      expect((orphan as LevitReactiveNotifier).isDisposed, false);
      expect(orphan.ownerId, isNotNull,
          reason: "Orphan should be captured/tagged");

      // Close store
      store.delete(force: true);

      expect((orphan as LevitReactiveNotifier).isDisposed, true,
          reason:
              "Orphan should be disposed on store close due to restored Zone capture");
    });

    test('AutoDispose works manually', () {
      bool disposed = false;
      final disposable = LevitDisposableCallback(() {
        disposed = true;
      });

      final store = LevitStore((ref) {
        ref.autoDispose(disposable);
        return 0;
      });

      store.find();
      store.delete(force: true);
      expect(disposed, true);
    });

    test('ref.find and findAsync with LevitStore keys', () async {
      final otherStore = LevitStore((ref) => 'other');
      final otherAsyncStore = LevitStore.async((ref) async => 'otherAsync');

      final mainStore = LevitStore((ref) {
        final val = ref.find<String>(key: otherStore);
        return val;
      });

      final mainAsyncStore = LevitStore.async((ref) async {
        final val = await ref.findAsync<String>(key: otherAsyncStore);
        return val;
      });

      expect(mainStore.find(), 'other');
      expect(await mainAsyncStore.find(), 'otherAsync');
    });

    test('ref.put, lazyPut, lazyPutAsync work as expected', () async {
      final store = LevitStore((ref) {
        ref.put<String>(() => 'putVal', tag: 't1');
        ref.lazyPut<String>(() => 'lazyVal', tag: 't2');
        ref.lazyPutAsync<String>(() async => 'asyncVal', tag: 't3');

        return (
          v1: ref.find<String>(tag: 't1'),
          v2: ref.find<String>(tag: 't2'),
          v3: ref.findAsync<String>(tag: 't3'),
        );
      });

      final result = store.find();
      expect(result.v1, 'putVal');
      expect(result.v2, 'lazyVal');
      expect(await result.v3, 'asyncVal');
    });

    test('findAsyncIn does not dispose existing instance on concurrent calls',
        () async {
      final scope = LevitScope.root('race_store');
      int closed = 0;
      final store = LevitStore((ref) => _TestController(() => closed++));

      final f1 = store.findAsyncIn(scope);
      final f2 = store.findAsyncIn(scope);
      final results = await Future.wait([f1, f2]);

      expect(identical(results[0], results[1]), isTrue);
      expect(closed, 0);
    });

    test('builder error disposes captured reactives', () {
      late LxVar<int> orphan;
      final store = LevitStore((ref) {
        orphan = LxVar(0);
        throw StateError('boom');
      });

      expect(() => store.find(), throwsStateError);
      expect(orphan.isDisposed, isTrue);
    });
  });

  group('LevitAsyncStore', () {
    test('resolves future correctly', () async {
      final store = LevitStore.async((ref) async {
        await Future.delayed(Duration(milliseconds: 1));
        return 100;
      });

      expect(await store.find(), 100);
    });

    test('async builder error disposes captured reactives', () async {
      late LxVar<int> orphan;
      final store = LevitStore.async((ref) async {
        orphan = LxVar(0);
        await Future.delayed(Duration.zero);
        throw StateError('boom');
      });

      await expectLater(store.find(), throwsStateError);
      expect(orphan.isDisposed, isTrue);
    });
  });
}

class LevitDisposableCallback implements LevitDisposable {
  final VoidCallback callback;
  LevitDisposableCallback(this.callback);

  @override
  void dispose() => callback();
}

typedef VoidCallback = void Function();

class _TestController extends LevitController {
  final VoidCallback _onClose;
  _TestController(this._onClose);

  @override
  void onClose() {
    _onClose();
    super.onClose();
  }
}
