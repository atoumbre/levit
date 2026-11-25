import 'package:levit_scope/levit_scope.dart';
import 'package:test/test.dart';

class Service {}

void main() {
  group('Explicit builder registration', () {
    setUp(() async {
      await Ls.reset(force: true);
    });

    test('Ls.put constructs a registered service', () {
      Service builder() => Service();
      Ls.put(builder);
      expect(Ls.isRegistered<Service>(), true);
      expect(Ls.find<Service>(), isA<Service>());
    });

    test('Ls.lazyPut defers service construction', () {
      Service builder() => Service();
      Ls.lazyPut(builder);
      expect(Ls.isRegistered<Service>(), true);
      expect(Ls.isInstantiated<Service>(), false);
      expect(Ls.find<Service>(), isA<Service>());
      expect(Ls.isInstantiated<Service>(), true);
    });
  });
}
