import 'package:levit_scope/levit_scope.dart';
import 'package:test/test.dart';

class TestService implements LevitScopeDisposable {
  bool closed = false;
  bool inited = false;
  @override
  void onInit() => inited = true;
  @override
  void onClose() => closed = true;
  @override
  void didAttachToScope(LevitScope scope, {String? key}) {}
}

void main() {
  late LevitScope levit;
  setUp(() => levit = LevitScope.root());
  tearDown(() => levit.reset(force: true));

  group('DI Error Handling & Scope Edge Cases', () {
    test('LevitScope.put deletes existing instance if present', () {
      final scope = levit.createScope('test');
      final s1 = TestService();
      scope.put(() => s1, tag: 't1');

      final s2 = TestService();
      scope.put(() => s2, tag: 't1'); // Should replace and close s1

      expect(s1.closed, true);
      expect(scope.find<TestService>(tag: 't1'), s2);
    });

    test('LevitScope.find throws if not found anywhere', () {
      final scope = levit.createScope('test');
      expect(() => scope.find<TestService>(), throwsA(isA<Exception>()));
    });

    test('LevitScope.findOrNull recursion fallbacks', () {
      final parent = levit.createScope('parent');
      final child = parent.createScope('child');

      // Should return null if nowhere
      expect(child.findOrNull<TestService>(), isNull);

      // Should find in parent DI if nowhere else
      levit.put(() => TestService());
      expect(child.findOrNull<TestService>(), isNotNull);
    });

    test('SimpleDI.findAsync throws proper error message', () async {
      expect(
        () async => await levit.findAsync<TestService>(tag: 'missing'),
        throwsA(isA<Exception>()),
      );
    });

    test('levit.findAsync works with sync factory', () async {
      levit.lazyPut(() => TestService(), isFactory: true);
      final s1 = await levit.findAsync<TestService>();
      expect(s1.inited, true);
    });

    test('LevitScope.find handles sync factory', () {
      final scope = levit.createScope('test');
      scope.lazyPut(() => TestService(), isFactory: true);
      final s1 = scope.find<TestService>();
      expect(s1.inited, true);
    });
  });
}
