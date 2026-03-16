import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';

void main() {
  group('Levit Delete and Instantiated', () {
    tearDown(() {
      Ls.reset(force: true);
    });

    test('Levit.delete and Levit.isInstantiated', () {
      Levit.lazyPut(() => 'hello', tag: 'my-tag');

      expect(Levit.isInstantiated<String>(tag: 'my-tag'), isFalse);

      Levit.find<String>(tag: 'my-tag');

      expect(Levit.isInstantiated<String>(tag: 'my-tag'), isTrue);
      expect(Levit.delete<String>(tag: 'my-tag'), isTrue);
    });
  });
}
