import 'package:levit_scope/levit_scope.dart';
import 'package:test/test.dart';

class Service {}

void main() {
  group('Explicit async builder registration', () {
    setUp(() async {
      await Ls.reset(force: true);
    });

    test('Ls.lazyPutAsync registers a lazy async builder', () async {
      final service = Service();
      Future<Service> builder() async => service;

      Ls.lazyPutAsync(builder);
      expect(Ls.isRegistered<Service>(), true);

      final found = await Ls.findAsync<Service>();
      expect(found, service);
    });

    test('Ls.lazyPutAsync registers an async factory', () async {
      Future<Service> builder() async => Service();

      Ls.lazyPutAsync(builder, isFactory: true);

      final s1 = await Ls.findAsync<Service>();
      final s2 = await Ls.findAsync<Service>();

      expect(s1, isNot(same(s2)));
    });
  });
}
