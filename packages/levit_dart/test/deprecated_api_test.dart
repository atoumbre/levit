import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

class Service {}

void main() {
  group('Deprecation Tests', () {
    setUp(() {
      Levit.reset(force: true);
    });

    test('putFactory still works', () {
      Levit.lazyPut(() => Service(), isFactory: true);
      expect(Levit.isRegistered<Service>(), isTrue);
    });

    test('putFactoryAsync still works', () async {
      Levit.lazyPutAsync(() async => Service(), isFactory: true);
      await Levit.findAsync<Service>();
      expect(Levit.isRegistered<Service>(), isTrue);
    });

    test('disableAutoLinking can be called', () {
      Levit.enableAutoLinking();
      Levit.disableAutoLinking();
      // No assertion needed, just coverage
    });
  });
}
