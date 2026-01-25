import 'package:levit_dart_core/levit_dart_core.dart';
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

    test('lazyPutAsync returns a finder function', () async {
      final finder = Levit.lazyPutAsync(() async => Service());
      expect(finder, isA<Future<Service> Function()>());
      final instance = await finder();
      expect(instance, isA<Service>());
    });

    test('disableAutoLinking can be called', () {
      Levit.enableAutoLinking();
      Levit.disableAutoLinking();
      // No assertion needed, just coverage
    });
  });
}
