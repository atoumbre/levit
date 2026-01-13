import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

class Service {}

void main() {
  group('Levit Dependency Management', () {
    setUp(() {
      Levit.reset(force: true);
    });

    test('Levit.delete removes dependency', () {
      Levit.put(() => Service());
      expect(Levit.isRegistered<Service>(), true);

      final deleted = Levit.delete<Service>();
      expect(deleted, true);
      expect(Levit.isRegistered<Service>(), false);
    });

    test('Levit.delete returns false for unknown dependency', () {
      final deleted = Levit.delete<Service>();
      expect(deleted, false);
    });

    test('Levit.reset clears all dependencies', () {
      Levit.put(() => Service());
      expect(Levit.isRegistered<Service>(), true);

      Levit.reset(force: true);
      expect(Levit.isRegistered<Service>(), false);
      expect(Levit.registeredCount, 0);
    });

    test('Levit.registeredCount mirrors scope count', () {
      expect(Levit.registeredCount, 0);
      Levit.put(() => Service());
      expect(Levit.registeredCount, 1);
    });

    test('Levit.registeredKeys mirrors scope keys', () {
      Levit.put(() => Service(), tag: 'myTag');
      expect(Levit.registeredKeys, contains(contains('myTag')));
    });

    test('Levit.findOrNull returns null when not found', () {
      final found = Levit.findOrNull<Service>();
      expect(found, null);
    });

    test('Levit.findOrNull returns instance when found', () {
      final service = Service();
      Levit.put(() => service);
      final found = Levit.findOrNull<Service>();
      expect(found, service);
    });
    test('toBuilder extension works', () {
      final service = Service();
      final builder = service.toBuilder;
      expect(builder(), service);
    });
  });
}
