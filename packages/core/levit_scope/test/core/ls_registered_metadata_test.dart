import 'package:test/test.dart';
import 'package:levit_scope/levit_scope.dart';

void main() {
  test('Ls.registeredCount and registeredKeys', () async {
    await Ls.reset(force: true);
    expect(Ls.registeredCount, 0);
    expect(Ls.registeredKeys, isEmpty);

    Ls.put(() => 'A');
    expect(Ls.registeredCount, 1);
    expect(Ls.registeredKeys, contains('String'));
    await Ls.reset(force: true);
  });
}
