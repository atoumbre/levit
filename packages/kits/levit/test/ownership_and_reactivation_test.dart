import 'package:levit/levit.dart';
import 'package:test/test.dart';

class _AppController extends LevitController {
  final count = 0.lx;
  late final LxInt initialized;

  @override
  void onInit() {
    super.onInit();
    initialized = 1.lx;
  }
}

class _PageController extends LevitController {
  _PageController(this.shared);
  final _AppController shared;
  final local = 0.lx;
}

void main() {
  test('a page borrows the app controller it first resolves', () async {
    Levit.enableAutoLinking();
    addTearDown(Levit.disableAutoLinking);
    final app = Levit.createScope('app');
    addTearDown(app.dispose);
    final page = app.createScope('page');
    app.lazyPut(_AppController.new);

    final owner = page.put(() => _PageController(page.find<_AppController>()));
    final shared = owner.shared;
    final seen = <int>[];
    shared.count.addListener(() => seen.add(shared.count()));
    shared.count.value = 1;
    await page.dispose();

    expect(owner.local.isDisposed, isTrue);
    expect(app.find<_AppController>(), same(shared));
    expect(shared.isDisposed, isFalse);
    expect(shared.initialized.isDisposed, isFalse);
    shared.count.value = 2;
    expect(seen, [1, 2]);
    await app.dispose();
    expect(shared.count.isDisposed, isTrue);
    expect(shared.initialized.isDisposed, isTrue);
  });

  test('a failed page builder releases only its own allocations', () async {
    Levit.enableAutoLinking();
    addTearDown(Levit.disableAutoLinking);
    final app = Levit.createScope('app');
    addTearDown(app.dispose);
    final page = app.createScope('page');
    app.lazyPut(_AppController.new);
    late LxInt temporary;
    expect(
      () => page.put<_PageController>(() {
        temporary = 0.lx;
        page.find<_AppController>();
        throw StateError('page setup failed');
      }),
      throwsStateError,
    );
    await page.dispose();
    expect(temporary.isDisposed, isTrue);
    final shared = app.find<_AppController>();
    expect(shared.count.isDisposed, isFalse);
    expect(shared.initialized.isDisposed, isFalse);
  });

  test(
    'resolving an app owner inside a page async-map loader preserves ownership',
    () async {
      Levit.enableAutoLinking();
      addTearDown(Levit.disableAutoLinking);
      final app = Levit.createScope('app');
      addTearDown(app.dispose);
      final page = app.createScope('page');
      app.lazyPut(_AppController.new);
      late _AppController shared;
      final owner = page.put(() {
        final queries = LevitAsyncMap<String, int>((key, _) async {
          shared = page.find<_AppController>();
          return 3;
        });
        shared = page.find<_AppController>();
        return _PageController(shared)..own(queries);
      });
      await page.dispose();
      expect(owner.local.isDisposed, isTrue);
      expect(shared.count.isDisposed, isFalse);
      expect(shared.initialized.isDisposed, isFalse);
      await app.dispose();
      expect(shared.count.isDisposed, isTrue);
      expect(shared.initialized.isDisposed, isTrue);
    },
  );

  test('a static computed reconnects to its scalar dependency', () async {
    final source = 0.lx;
    addTearDown(source.close);
    final derived = LxComputed(() => source.value, staticDeps: true);
    addTearDown(derived.close);
    void listen() {}
    derived.addListener(listen);
    derived.removeListener(listen);
    source.value = 1;
    derived.addListener(listen);
    expect(derived.value, 1);
    source.value = 2;
    expect(derived.value, 2);
  });

  test(
    'static async tracking survives detachment from its first result',
    () async {
      final source = 0.lx;
      addTearDown(source.close);
      final derived = LxComputed.async(
        () async => source.value,
        staticDeps: true,
      );
      addTearDown(derived.close);
      void detach() {
        if (derived.isSuccess) derived.removeListener(detach);
      }

      derived.addListener(detach);
      await derived.drain();
      expect(source.hasListener, isFalse);
      derived.addListener(() {});
      await derived.drain();
      source.value = 2;
      await derived.drain();
      expect(derived.requireValue, 2);
    },
  );

  for (final policy in LxAsyncConcurrency.values) {
    test('static async dependencies reconnect after idle ($policy)', () async {
      final source = 0.lx;
      addTearDown(source.close);
      final derived = LxComputed.async(
        () async {
          await Future<void>.value();
          return source.value;
        },
        staticDeps: true,
        concurrency: policy,
      );
      addTearDown(derived.close);
      void listen() {}
      derived.addListener(listen);
      await derived.drain();
      expect(derived.requireValue, 0);
      derived.removeListener(listen);
      expect(source.hasListener, isFalse);

      source.value = 1;
      derived.addListener(listen);
      await derived.drain();
      expect(derived.requireValue, 1);
      source.value = 2;
      await derived.drain();
      expect(derived.requireValue, 2);
    });
  }
}
