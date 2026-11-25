import 'package:test/test.dart';
import 'package:levit_scope/levit_scope.dart';

void main() {
  test('Ls.run executes in scope zone', () async {
    await Ls.reset(force: true);
    final scope = Ls.createScope('run_test');
    scope.run(() {
      Ls.put(() => 'ZoneDependency');
      expect(Ls.isRegistered<String>(), isTrue);
      expect(scope.isRegisteredLocally<String>(), isTrue);
    });
    expect(Ls.isRegistered<String>(), isFalse);
    await Ls.reset(force: true);
  });
}
