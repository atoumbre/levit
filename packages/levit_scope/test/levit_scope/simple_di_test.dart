import 'package:test/test.dart';
import 'package:levit_scope/levit_scope.dart';

void main() {
  // Reset the DI container before each test
  late LevitScope levit;

  setUp(() {
    levit = LevitScope.root();
  });

  group('levit.put()', () {
    test('registers and returns instance', () {
      final service = levit.put(() => _TestService('hello'));
      expect(service.value, equals('hello'));
    });

    test('instance is retrievable via find', () {
      levit.put(() => _TestService('world'));
      final found = levit.find<_TestService>();
      expect(found.value, equals('world'));
    });

    test('calls onInit on LevitScopeDisposable', () {
      final service = _DisposableService();
      levit.put(() => service);
      expect(service.initCalled, isTrue);
    });

    test('with tag registers separate instances', () {
      levit.put(() => _TestService('default'));
      levit.put(() => _TestService('tagged'), tag: 'v2');

      expect(levit.find<_TestService>().value, equals('default'));
      expect(levit.find<_TestService>(tag: 'v2').value, equals('tagged'));
    });

    test('replaces existing instance', () {
      levit.put(() => _TestService('first'));
      levit.put(() => _TestService('second'));
      expect(levit.find<_TestService>().value, equals('second'));
    });
  });

  group('levit.lazyPut()', () {
    test('does not instantiate immediately', () {
      var builderCalled = false;
      levit.lazyPut(() {
        builderCalled = true;
        return _TestService('lazy');
      });

      expect(builderCalled, isFalse);
      expect(levit.isRegistered<_TestService>(), isTrue);
      expect(levit.isInstantiated<_TestService>(), isFalse);
    });

    test('instantiates on first find', () {
      var callCount = 0;
      levit.lazyPut(() {
        callCount++;
        return _TestService('lazy');
      });

      final first = levit.find<_TestService>();
      final second = levit.find<_TestService>();

      expect(callCount, equals(1)); // Builder called only once
      expect(first.value, equals('lazy'));
      expect(identical(first, second), isTrue);
    });

    test('calls onInit on first find', () {
      levit.lazyPut(() => _DisposableService());

      expect(levit.isInstantiated<_DisposableService>(), isFalse);

      final service = levit.find<_DisposableService>();
      expect(service.initCalled, isTrue);
    });

    test('does not overwrite instantiated instance', () {
      levit.lazyPut(() => _TestService('first'));
      levit.find<_TestService>(); // Instantiate

      levit.lazyPut(() => _TestService('second')); // Should be ignored

      expect(levit.find<_TestService>().value, equals('first'));
    });
  });

  group('levit.find()', () {
    test('throws if not registered', () {
      expect(
        () => levit.find<_TestService>(),
        throwsA(isA<Exception>()),
      );
    });

    test('throws with helpful message', () {
      expect(
        () => levit.find<_TestService>(),
        throwsA(predicate((e) =>
            e.toString().contains('_TestService') &&
            e.toString().contains('not registered'))),
      );
    });

    test('throws with tag in message', () {
      expect(
        () => levit.find<_TestService>(tag: 'special'),
        throwsA(predicate((e) => e.toString().contains('special'))),
      );
    });
  });

  group('levit.delete()', () {
    test('removes instance', () {
      levit.put(() => _TestService('test'));
      expect(levit.isRegistered<_TestService>(), isTrue);

      levit.delete<_TestService>();
      expect(levit.isRegistered<_TestService>(), isFalse);
    });

    test('calls onClose on LevitScopeDisposable', () {
      final service = _DisposableService();
      levit.put(() => service);

      levit.delete<_DisposableService>();
      expect(service.closeCalled, isTrue);
    });

    test('returns true if deleted', () {
      levit.put(() => _TestService('test'));
      expect(levit.delete<_TestService>(), isTrue);
    });

    test('returns false if not registered', () {
      expect(levit.delete<_TestService>(), isFalse);
    });

    test('respects permanent flag', () {
      levit.put(() => _TestService('permanent'), permanent: true);

      expect(levit.delete<_TestService>(), isFalse);
      expect(levit.isRegistered<_TestService>(), isTrue);
    });

    test('force overrides permanent flag', () {
      levit.put(() => _TestService('permanent'), permanent: true);

      expect(levit.delete<_TestService>(force: true), isTrue);
      expect(levit.isRegistered<_TestService>(), isFalse);
    });

    test('deletes correct tagged instance', () {
      levit.put(() => _TestService('default'));
      levit.put(() => _TestService('tagged'), tag: 'v2');

      levit.delete<_TestService>(tag: 'v2');

      expect(levit.isRegistered<_TestService>(), isTrue);
      expect(levit.isRegistered<_TestService>(tag: 'v2'), isFalse);
    });
  });

  group('levit.reset()', () {
    test('clears all instances', () {
      levit.put(() => _TestService('one'));
      levit.put(() => _DisposableService());

      levit.reset();

      expect(levit.registeredCount, equals(0));
    });

    test('calls onClose on all LevitScopeDisposables', () {
      final services = [
        _DisposableService(),
        _DisposableService(),
        _DisposableService(),
      ];
      for (var i = 0; i < services.length; i++) {
        levit.put(() => services[i], tag: 'tag$i');
      }

      levit.reset();

      for (final service in services) {
        expect(service.closeCalled, isTrue);
      }
    });

    test('respects permanent flag', () {
      levit.put(() => _TestService('permanent'), permanent: true);
      levit.put(() => _DisposableService());

      levit.reset();

      expect(levit.isRegistered<_TestService>(), isTrue);
      expect(levit.isRegistered<_DisposableService>(), isFalse);
    });

    test('force clears permanent instances', () {
      levit.put(() => _TestService('permanent'), permanent: true);

      levit.reset(force: true);

      expect(levit.isRegistered<_TestService>(), isFalse);
    });
  });

  group('Registration status', () {
    test('isRegistered returns true for put', () {
      levit.put(() => _TestService('test'));
      expect(levit.isRegistered<_TestService>(), isTrue);
    });

    test('isRegistered returns true for lazyPut before find', () {
      levit.lazyPut(() => _TestService('lazy'));
      expect(levit.isRegistered<_TestService>(), isTrue);
    });

    test('isInstantiated returns false for lazyPut before find', () {
      levit.lazyPut(() => _TestService('lazy'));
      expect(levit.isInstantiated<_TestService>(), isFalse);
    });

    test('isInstantiated returns true after find', () {
      levit.lazyPut(() => _TestService('lazy'));
      levit.find<_TestService>();
      expect(levit.isInstantiated<_TestService>(), isTrue);
    });
  });

  group('LevitScopeDisposable', () {
    test('default onInit does nothing', () {
      final disposable = _MinimalDisposable();
      expect(() => disposable.onInit(), returnsNormally);
    });

    test('default onClose does nothing', () {
      final disposable = _MinimalDisposable();
      expect(() => disposable.onClose(), returnsNormally);
    });
  });

  group('Debugging helpers', () {
    test('registeredTypes returns list of type keys', () {
      levit.put(() => _TestService('one'));
      levit.put(() => _DisposableService());

      final types = levit.registeredKeys;
      expect(levit.registeredKeys, contains(contains('_TestService')));
      expect(types, contains(contains('_DisposableService')));
      expect(types.length, equals(2));
    });
  });

  group('Extensions', () {
    test('ToBuilder creates a builder function', () {
      final service = _TestService('extension');
      final builder = service.toBuilder;
      expect(builder(), service);
    });
  });
}

// Test helpers

class _TestService {
  final String value;
  _TestService(this.value);
}

class _DisposableService implements LevitScopeDisposable {
  bool initCalled = false;
  bool closeCalled = false;

  @override
  void onInit() {
    initCalled = true;
  }

  @override
  void onClose() {
    closeCalled = true;
  }

  @override
  void didAttachToScope(LevitScope scope, {String? key}) {}
}

/// Minimal implementation that uses default methods (extends to get defaults)
class _MinimalDisposable extends LevitScopeDisposable {
  @override
  void didAttachToScope(LevitScope scope, {String? key}) {}
}
