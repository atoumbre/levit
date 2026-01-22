import 'package:levit_scope/levit_scope.dart';
import 'package:test/test.dart';

// Test service class
class TestService implements LevitScopeDisposable {
  static int initCount = 0;
  static int closeCount = 0;
  final String name;

  TestService([this.name = 'default']);

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

class ParentService {}

class ChildService {}

void main() {
  late LevitScope levit;

  setUp(() {
    levit = LevitScope.root();
    TestService.resetCounts();
  });

  tearDown(() {
    levit.reset(force: true);
  });

  group('LevitScope', () {
    group('Basic Registration', () {
      test('put registers in scope', () {
        final scope = levit.createScope('test');
        final service = TestService('scoped');

        scope.put(() => service);

        expect(scope.find<TestService>().name, 'scoped');
        expect(scope.registeredCount, 1);
      });

      test('lazyPut registers lazy in scope', () {
        final scope = levit.createScope('test');
        var created = false;

        scope.lazyPut(() {
          created = true;
          return TestService('lazy');
        });

        expect(created, false);
        expect(scope.find<TestService>().name, 'lazy');
        expect(created, true);
      });

      test('putFactory registers factory in scope', () {
        final scope = levit.createScope('test');
        var count = 0;

        scope.lazyPut(() => TestService('factory-${++count}'), isFactory: true);

        final a = scope.find<TestService>();
        final b = scope.find<TestService>();

        expect(a.name, 'factory-1');
        expect(b.name, 'factory-2');
        expect(identical(a, b), false);
      });

      test('onInit is called on put', () {
        final scope = levit.createScope('test');
        scope.put(() => TestService());

        expect(TestService.initCount, 1);
      });
    });

    group('Parent Fallback', () {
      test('find falls back to Levit if not in scope', () {
        levit.put(() => ParentService());
        final scope = levit.createScope('test');

        expect(scope.find<ParentService>(), isA<ParentService>());
        expect(scope.isRegisteredLocally<ParentService>(), false);
        expect(scope.isRegistered<ParentService>(), true);
      });

      test('findOrNull falls back to Levit', () {
        levit.put(() => ParentService());
        final scope = levit.createScope('test');

        expect(scope.findOrNull<ParentService>(), isNotNull);
      });

      test('findOrNull returns null if not found anywhere', () {
        final scope = levit.createScope('test');

        expect(scope.findOrNull<ParentService>(), isNull);
      });

      test('find throws if not found anywhere', () {
        final scope = levit.createScope('test');

        expect(
          () => scope.find<ParentService>(),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('Local Override', () {
      test('scope can override parent dependency', () {
        levit.put(() => TestService('parent'));
        final scope = levit.createScope('test');
        scope.put(() => TestService('scoped'));

        // Scope returns local
        expect(scope.find<TestService>().name, 'scoped');
        // Parent still has original
        expect(levit.find<TestService>().name, 'parent');
      });

      test('override works with findOrNull', () {
        levit.put(() => TestService('parent'));
        final scope = levit.createScope('test');
        scope.put(() => TestService('scoped'));

        expect(scope.findOrNull<TestService>()?.name, 'scoped');
      });
    });

    group('Scope Reset', () {
      test('reset clears scope only, not parent', () {
        levit.put(() => ParentService());
        final scope = levit.createScope('test');
        scope.put(() => ChildService());

        expect(scope.registeredCount, 1);

        scope.reset();

        expect(scope.registeredCount, 0);
        // Parent still has its service
        expect(levit.find<ParentService>(), isA<ParentService>());
      });

      test('reset calls onClose on scope services', () {
        final scope = levit.createScope('test');
        scope.put(() => TestService());

        expect(TestService.closeCount, 0);
        scope.reset();
        expect(TestService.closeCount, 1);
      });

      test('reset does not affect parent services', () {
        levit.put(() => TestService('parent'));
        final scope = levit.createScope('test');

        scope.reset();

        expect(levit.find<TestService>().name, 'parent');
        expect(TestService.closeCount, 0);
      });
    });

    group('Nested Scopes', () {
      test('nested scope falls back to parent scope', () {
        levit.put(() => TestService('levit'));
        final parent = levit.createScope('parent');
        parent.put(() => ParentService());
        final child = parent.createScope('child');

        // Child can find from parent scope
        expect(child.find<ParentService>(), isA<ParentService>());
        // Child can also find from Levit
        expect(child.find<TestService>().name, 'levit');
      });

      test('nested scope can override parent scope', () {
        final parent = levit.createScope('parent');
        parent.put(() => TestService('parent-scope'));
        final child = parent.createScope('child');
        child.put(() => TestService('child-scope'));

        expect(parent.find<TestService>().name, 'parent-scope');
        expect(child.find<TestService>().name, 'child-scope');
      });

      test('child reset does not affect parent scope', () {
        final parent = levit.createScope('parent');
        parent.put(() => ParentService());
        final child = parent.createScope('child');
        child.put(() => ChildService());

        child.reset();

        expect(child.registeredCount, 0);
        expect(parent.registeredCount, 1);
        expect(parent.find<ParentService>(), isA<ParentService>());
      });
    });

    group('Deletion', () {
      test('delete removes from scope', () {
        final scope = levit.createScope('test');
        scope.put(() => TestService());

        scope.delete<TestService>();

        expect(scope.registeredCount, 0);
      });

      test('delete calls onClose', () {
        final scope = levit.createScope('test');
        scope.put(() => TestService());

        scope.delete<TestService>();

        expect(TestService.closeCount, 1);
      });
    });

    group('isRegistered', () {
      test('isRegisteredLocally checks only local', () {
        levit.put(() => ParentService());
        final scope = levit.createScope('test');

        expect(scope.isRegisteredLocally<ParentService>(), false);
      });

      test('isRegistered checks local and parents', () {
        levit.put(() => ParentService());
        final scope = levit.createScope('test');

        expect(scope.isRegistered<ParentService>(), true);
      });
    });

    test('toString shows scope name and count', () {
      final scope = levit.createScope('checkout');
      scope.put(() => TestService());

      expect(scope.toString(), contains('checkout'));
      expect(scope.toString(), contains('1'));
    });
  });
}
