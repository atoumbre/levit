import 'package:levit_scope/levit_scope.dart';
import 'package:test/test.dart';

class Service {}

void main() {
  group('Levit Put Extensions', () {
    setUp(() {
      Ls.reset(force: true);
    });

    test('T.levitPut registers instance', () {
      final service = Service();
      service.levitPut();
      expect(Ls.find<Service>(), service);
    });

    test('T.levitLazyPut registers lazy instance', () {
      final service = Service();
      service.levitLazyPut();
      expect(Ls.isInstantiated<Service>(), false);
      expect(Ls.find<Service>(), service);
      expect(Ls.isInstantiated<Service>(), true);
    });
  });

  group('Levit Put Builder Extensions', () {
    setUp(() {
      Ls.reset(force: true);
    });

    test('T Function().levitPut registers builder', () {
      Service builder() => Service();
      builder.levitPut();
      expect(Ls.isRegistered<Service>(), true);
      expect(Ls.find<Service>(), isA<Service>());
    });

    test('T Function().levitLazyPut registers lazy builder', () {
      Service builder() => Service();
      builder.levitLazyPut();
      expect(Ls.isRegistered<Service>(), true);
      expect(Ls.isInstantiated<Service>(), false);
      expect(Ls.find<Service>(), isA<Service>());
      expect(Ls.isInstantiated<Service>(), true);
    });
  });
}
