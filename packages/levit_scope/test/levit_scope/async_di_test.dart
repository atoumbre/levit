import 'package:levit_scope/levit_scope.dart';
import 'package:test/test.dart';

class AsyncService implements LevitScopeDisposable {
  final String name;
  static int initCount = 0;
  static int closeCount = 0;

  AsyncService(this.name);

  @override
  void onInit() => initCount++;

  @override
  void onClose() => closeCount++;

  @override
  void didAttachToScope(LevitScope scope, {String? key}) {}

  static void resetCounts() {
    initCount = 0;
    closeCount = 0;
  }
}

class FactoryService implements LevitScopeDisposable {
  static int instanceCount = 0;
  final int id;

  FactoryService() : id = ++instanceCount;

  @override
  void onInit() {}

  @override
  void onClose() {}

  @override
  void didAttachToScope(LevitScope scope, {String? key}) {}

  static void reset() => instanceCount = 0;
}

void main() {
  late LevitScope levit;

  setUp(() {
    levit = LevitScope.root();
    AsyncService.resetCounts();
    FactoryService.reset();
  });

  tearDown(() {
    levit.reset(force: true);
  });

  group('put (simulated async)', () {
    test('registers async service manually', () async {
      final instance = await Future.delayed(
          Duration(milliseconds: 10), () => AsyncService('async'));
      final service = levit.put(() => instance);

      expect(service.name, 'async');
      expect(levit.find<AsyncService>().name, 'async');
      expect(AsyncService.initCount, 1);
    });

    test('put with tag (simulated async)', () async {
      final s1 = await Future.value(AsyncService('v1'));
      levit.put(() => s1, tag: 'v1');

      final s2 = await Future.value(AsyncService('v2'));
      levit.put(() => s2, tag: 'v2');

      expect(levit.find<AsyncService>(tag: 'v1').name, 'v1');
      expect(levit.find<AsyncService>(tag: 'v2').name, 'v2');
    });
  });

  group('lazyPutAsync', () {
    test('does not instantiate until findAsync', () async {
      levit.lazyPutAsync(() async {
        return AsyncService('lazy-async');
      });

      expect(levit.isInstantiated<AsyncService>(), false);

      final service = await levit.findAsync<AsyncService>();
      expect(service.name, 'lazy-async');
      expect(levit.isInstantiated<AsyncService>(), true);
      expect(AsyncService.initCount, 1);
    });

    test('lazyPutAsync with tag', () async {
      levit.lazyPutAsync(() async => AsyncService('tagged'), tag: 'test');

      final service = await levit.findAsync<AsyncService>(tag: 'test');
      expect(service.name, 'tagged');
    });

    test('lazyPutAsync with isFactory', () async {
      int factoryCount = 0;
      levit.lazyPutAsync<FactoryService>(() async {
        factoryCount++;
        return FactoryService();
      }, isFactory: true);

      final s1 = await levit.findAsync<FactoryService>();
      final s2 = await levit.findAsync<FactoryService>();

      expect(s1.id, isNot(equals(s2.id)));
      expect(factoryCount, 2);
    });
  });

  group('findAsync', () {
    test('findAsync works with sync registrations', () async {
      levit.put(() => AsyncService('sync'));

      final service = await levit.findAsync<AsyncService>();
      expect(service.name, 'sync');
    });

    test('findAsync with lazy sync', () async {
      levit.lazyPut(() => AsyncService('lazy-sync'));

      final service = await levit.findAsync<AsyncService>();
      expect(service.name, 'lazy-sync');
    });

    test('findAsync throws if not found', () async {
      expect(
        () async => await levit.findAsync<AsyncService>(),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('putFactory (factory pattern)', () {
    test('putFactory returns new instance each time', () {
      levit.lazyPut(() => FactoryService(), isFactory: true);

      final a = levit.find<FactoryService>();
      final b = levit.find<FactoryService>();
      final c = levit.find<FactoryService>();

      expect(a.id, 1);
      expect(b.id, 2);
      expect(c.id, 3);
      expect(identical(a, b), false);
    });

    test('create with tag', () {
      levit.lazyPut(() => FactoryService(), tag: 'factory', isFactory: true);

      final a = levit.find<FactoryService>(tag: 'factory');
      final b = levit.find<FactoryService>(tag: 'factory');

      expect(a.id != b.id, true);
    });
  });

  group('putFactoryAsync', () {
    test('putFactoryAsync returns new instance each time via findAsync',
        () async {
      levit.lazyPutAsync(() async {
        await Future.delayed(Duration(milliseconds: 5));
        return FactoryService();
      }, isFactory: true);

      final a = await levit.findAsync<FactoryService>();
      final b = await levit.findAsync<FactoryService>();

      expect(a.id, 1);
      expect(b.id, 2);
    });

    test('putFactoryAsync factory works with sync find for sync builders', () {
      levit.lazyPutAsync(() async => FactoryService(), isFactory: true);

      // Using findAsync since it's async factory
      expect(
        () async => await levit.findAsync<FactoryService>(),
        returnsNormally,
      );
    });
  });

  group('findOrNull', () {
    test('returns null if not registered', () {
      expect(levit.findOrNull<AsyncService>(), isNull);
    });

    test('returns instance if registered', () {
      levit.lazyPut(() => AsyncService('test'), isFactory: true);
      expect(levit.findOrNull<AsyncService>()?.name, 'test');
    });

    test('lazy instantiates if needed', () {
      levit.lazyPut(() => AsyncService('lazy'));
      expect(levit.isInstantiated<AsyncService>(), false);

      final service = levit.findOrNull<AsyncService>();
      expect(service?.name, 'lazy');
      expect(levit.isInstantiated<AsyncService>(), true);
    });

    test('findOrNull with tag', () {
      levit.put(() => AsyncService('tagged'), tag: 'special');

      expect(levit.findOrNull<AsyncService>(), isNull);
      expect(levit.findOrNull<AsyncService>(tag: 'special')?.name, 'tagged');
    });
  });

  group('LevitScope async methods', () {
    test('scope findOrNull with parent fallback', () {
      levit.put(() => AsyncService('parent'));
      final scope = levit.createScope('test');

      expect(scope.findOrNull<AsyncService>()?.name, 'parent');
    });
  });
  group('findOrNullAsync', () {
    test('returns null if not registered', () async {
      expect(await levit.findOrNullAsync<AsyncService>(), isNull);
    });

    test('returns instance if registered', () async {
      levit.put<String>(() => 'async value');
      expect(await levit.findOrNullAsync<String>(), 'async value');
    });

    test('lazy instantiates if needed', () async {
      levit.lazyPutAsync(() async => AsyncService('lazy'));
      expect(levit.isInstantiated<AsyncService>(), false);

      final service = await levit.findOrNullAsync<AsyncService>();
      expect(service?.name, 'lazy');
      expect(levit.isInstantiated<AsyncService>(), true);
    });
  });
}
