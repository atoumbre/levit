import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

class Service {}

void main() {
  group('Levit Put Extensions', () {
    setUp(() {
      Levit.reset(force: true);
    });

    test('T.levitPut registers instance', () {
      final service = Service();
      service.levitPut();
      expect(Levit.find<Service>(), service);
    });

    test('T.levitLazyPut registers lazy instance', () {
      final service = Service();
      service.levitLazyPut();
      expect(Levit.isInstantiated<Service>(), false);
      expect(Levit.find<Service>(), service);
      expect(Levit.isInstantiated<Service>(), true);
    });
  });

  group('Levit Put Builder Extensions', () {
    setUp(() {
      Levit.reset(force: true);
    });

    test('T Function().levitPut registers builder', () {
      Service builder() => Service();
      builder.levitPut();
      expect(Levit.isRegistered<Service>(), true);
      expect(Levit.find<Service>(), isA<Service>());
    });

    test('T Function().levitLazyPut registers lazy builder', () {
      Service builder() => Service();
      builder.levitLazyPut();
      expect(Levit.isRegistered<Service>(), true);
      expect(Levit.isInstantiated<Service>(), false);
      expect(Levit.find<Service>(), isA<Service>());
      expect(Levit.isInstantiated<Service>(), true);
    });
  });
}
