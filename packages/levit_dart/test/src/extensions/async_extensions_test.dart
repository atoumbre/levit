import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

class Service {}

void main() {
  group('Levit Put Async Extensions', () {
    setUp(() {
      Levit.reset(force: true);
    });

    test('Future<T>.levitLazyPutAsync registers lazy async instance', () async {
      final service = Service();
      final future = Future.value(service);
      future.levitLazyPutAsync();

      expect(Levit.isRegistered<Service>(), true);
      // Note: isInstantiated checks if the *value* is ready, which for async requires the future to complete
      // and be awaited. Since lazyPutAsync just registers the builder, it might return true for registered.

      final found = await Levit.findAsync<Service>();
      expect(found, service);
    });
  });

  group('Levit Put Builder Async Extensions', () {
    setUp(() {
      Levit.reset(force: true);
    });

    test('Future<T> Function().levitLazyPutAsync registers lazy async builder',
        () async {
      final service = Service();
      Future<Service> builder() async => service;

      builder.levitLazyPutAsync();
      expect(Levit.isRegistered<Service>(), true);

      final found = await Levit.findAsync<Service>();
      expect(found, service);
    });

    test('Future<T> Function().levitPutFactoryAsync registers async factory',
        () async {
      Future<Service> builder() async => Service();

      builder.levitLazyPutAsync(isFactory: true);

      final s1 = await Levit.findAsync<Service>();
      final s2 = await Levit.findAsync<Service>();

      expect(s1, isNot(same(s2)));
    });
  });
}
