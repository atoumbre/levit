import 'package:test/test.dart';
import 'package:levit_scope/levit_scope.dart';

void main() {
  test('Ls methods proxy to active scope', () {
    Ls.reset(force: true);
    Ls.put(() => 'Dependency', tag: 'tag');
    expect(Ls.isRegistered<String>(tag: 'tag'), isTrue);
    expect(Ls.isInstantiated<String>(tag: 'tag'), isTrue);

    expect(Ls.find<String>(tag: 'tag'), 'Dependency');
    expect(Ls.findOrNull<String>(tag: 'tag'), 'Dependency');
    expect(Ls.findOrNull<String>(tag: 'missing'), isNull);

    Ls.delete<String>(tag: 'tag');
    expect(Ls.isRegistered<String>(tag: 'tag'), isFalse);
    Ls.reset(force: true);
  });
}
