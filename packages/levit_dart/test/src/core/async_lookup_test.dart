import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

class Service {}

void main() {
  group('Levit Async Lookup', () {
    setUp(() {
      Levit.reset(force: true);
    });

    test('findAsync returns future for async dependency', () async {
      final service = Service();
      Levit.put<Service>(() => service);

      final found = await Levit.findAsync<Service>();
      expect(found, service);
    });

    test('findOrNullAsync returns null when not found', () async {
      final found = await Levit.findOrNullAsync<Service>();
      expect(found, null);
    });

    test('findOrNullAsync returns future for async dependency', () async {
      final service = Service();
      Levit.put<Service>(() => service);

      final found = await Levit.findOrNullAsync<Service>();
      expect(found, service);
    });
  });
}
