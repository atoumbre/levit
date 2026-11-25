import 'package:test/test.dart';
import 'package:levit_scope/levit_scope.dart';

void main() {
  test('Ls methods proxy to active scope', () async {
    await Ls.reset(force: true);
    Ls.put(() => 'Dependency', tag: 'tag');
    expect(Ls.isRegistered<String>(tag: 'tag'), isTrue);
    expect(Ls.isInstantiated<String>(tag: 'tag'), isTrue);

    expect(Ls.find<String>(tag: 'tag'), 'Dependency');
    expect(Ls.findOrNull<String>(tag: 'tag'), 'Dependency');
    expect(Ls.findOrNull<String>(tag: 'missing'), isNull);

    await Ls.delete<String>(tag: 'tag');
    expect(Ls.isRegistered<String>(tag: 'tag'), isFalse);
    await Ls.reset(force: true);
  });
}
