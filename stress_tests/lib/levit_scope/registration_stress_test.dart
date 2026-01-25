import 'package:flutter_test/flutter_test.dart';
import 'package:levit_dart_core/levit_dart_core.dart';

class _Service {
  final int id;
  _Service(this.id);
}

void main() {
  setUp(() {
    Levit.reset(force: true);
  });

  group('Stress Test: DI Registration', () {
    test('Bulk Put/Find - 500k services', () {
      print('[Description] Tests mass registration and lookup performance.');
      const count = 500000;

      // Registration
      final swPut = Stopwatch()..start();
      for (var i = 0; i < count; i++) {
        Levit.put<_Service>(() => _Service(i), tag: 'svc_$i');
      }
      swPut.stop();
      print('Registered $count services in ${swPut.elapsedMilliseconds}ms');

      // Lookup
      final swFind = Stopwatch()..start();
      for (var i = 0; i < count; i++) {
        Levit.find<_Service>(tag: 'svc_$i');
      }
      swFind.stop();
      print('Resolved $count services in ${swFind.elapsedMilliseconds}ms');

      Levit.reset(force: true);
    });

    test('Lazy Instantiation Burst - 50k lazy services', () {
      print('[Description] Tests lazy instantiation triggered all at once.');
      const count = 50000;

      // Register lazy
      for (var i = 0; i < count; i++) {
        Levit.lazyPut<_Service>(() => _Service(i), tag: 'lazy_$i');
      }

      // Trigger all at once
      final sw = Stopwatch()..start();
      for (var i = 0; i < count; i++) {
        Levit.find<_Service>(tag: 'lazy_$i');
      }
      sw.stop();

      print('Instantiated $count lazy services in ${sw.elapsedMilliseconds}ms');

      Levit.reset(force: true);
    });

    test('Factory Create Churn - 100k factory instances', () {
      print('[Description] Tests factory pattern performance.');
      const count = 100000;

      Levit.lazyPut<_Service>(() => _Service(0),
          tag: 'factory', isFactory: true);

      final sw = Stopwatch()..start();
      for (var i = 0; i < count; i++) {
        Levit.find<_Service>(tag: 'factory');
      }
      sw.stop();

      final opsPerMs = count / sw.elapsedMilliseconds;
      print(
          'Created $count factory instances in ${sw.elapsedMilliseconds}ms (${opsPerMs.toStringAsFixed(0)} ops/ms)');

      Levit.reset(force: true);
    });
  });
}
