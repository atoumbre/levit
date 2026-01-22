import 'package:levit_scope/levit_scope.dart';
import 'package:test/test.dart';

class LifecycleService implements LevitScopeDisposable {
  bool inited = false;
  bool closed = false;
  LevitScope? attachedScope;

  @override
  void onInit() {
    inited = true;
  }

  @override
  void didAttachToScope(LevitScope scope, {String? key}) {
    attachedScope = scope;
  }

  @override
  void onClose() {
    closed = true;
  }
}

class AsyncLifecycleService extends LifecycleService {}

void main() {
  late LevitScope levit;

  setUp(() => levit = LevitScope.root());
  tearDown(() => levit.reset(force: true));

  group('LevitScopeDisposable.didAttachToScope', () {
    test('called on synchronous put', () {
      final scope = levit.createScope('test');
      final service = LifecycleService();

      scope.put(() => service);

      expect(service.inited, isTrue);
      expect(service.attachedScope, equals(scope));
    });

    test('called on lazyPut instantiation', () {
      final scope = levit.createScope('test');
      scope.lazyPut(() => LifecycleService());

      final service = scope.find<LifecycleService>();

      expect(service.inited, isTrue);
      expect(service.attachedScope, equals(scope));
    });

    test('called on putFactory instantiation', () {
      final scope = levit.createScope('test');
      scope.lazyPut(() => LifecycleService(), isFactory: true);

      final service = scope.find<LifecycleService>();

      expect(service.inited, isTrue);
      expect(service.attachedScope, equals(scope));
    });

    test('called on put (simulated async)', () async {
      final scope = levit.createScope('test');
      final instance = await Future.value(AsyncLifecycleService());
      scope.put(() => instance);

      final service = await scope.findAsync<AsyncLifecycleService>();

      expect(service.inited, isTrue);
      expect(service.attachedScope, equals(scope));
    });

    test('called on lazyPutAsync instantiation', () async {
      final scope = levit.createScope('test');
      scope.lazyPutAsync(() async => AsyncLifecycleService());

      final service = await scope.findAsync<AsyncLifecycleService>();

      expect(service.inited, isTrue);
      expect(service.attachedScope, equals(scope));
    });

    test('called on putFactoryAsync instantiation', () async {
      final scope = levit.createScope('test');
      scope.lazyPutAsync(() async => AsyncLifecycleService(), isFactory: true);

      final service = await scope.findAsync<AsyncLifecycleService>();

      expect(service.inited, isTrue);
      expect(service.attachedScope, equals(scope));
    });

    test('called on _findLocal lazy instantiation (sync)', () {
      // White-box test for _findLocal logic
      final scope = levit.createScope('test');
      scope.lazyPut(() => LifecycleService());

      // Accessing via internal logic implies typical use
      final service = scope.find<LifecycleService>();
      expect(service.attachedScope, equals(scope));
    });
  });
}
