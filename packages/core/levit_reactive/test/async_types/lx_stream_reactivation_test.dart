import 'dart:async';
import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

// ignore_for_file: cascade_invocations

void main() {
  group('LxStream Reactivation', () {
    test('single-subscription mapped stream survives reactivation', () async {
      final controller = StreamController<int>.broadcast();
      final baseStream = LxStream(controller.stream);

      // .map() creates a single-subscription stream under the hood.
      // Prior to the factory refactor, unmounting and remounting this
      // would throw a StateError: "Stream has already been listened to."
      final mappedStream = baseStream.map((e) => e * 2);

      // 1. Mount (first listener)
      final results1 = <int>[];
      final sub1 = mappedStream.valueStream.listen(results1.add);

      controller.add(1);
      await Future<void>.delayed(Duration.zero);
      expect(results1, [2]);

      // 2. Unmount (lose all listeners, stream goes idle, cancels underlying)
      await sub1.cancel();
      expect(mappedStream.hasListener, isFalse);

      // 3. Remount (new listener, should lazily create a fresh stream via factory)
      final results2 = <int>[];
      final sub2 = mappedStream.valueStream.listen(results2.add);

      controller.add(2);
      await Future<void>.delayed(Duration.zero);
      expect(results2, [4]);

      await sub2.cancel();
      await controller.close();
    });

    test('static stream does not survive reactivation if single-subscription',
        () async {
      // Create a raw single subscription stream
      final controller = StreamController<int>();
      final stream = controller.stream;

      // By using the standard constructor, we wrap the *existing* instance.
      final lxStream = LxStream(stream);

      // First mount works
      final sub1 = lxStream.valueStream.listen((_) {});
      await Future<void>.delayed(Duration.zero);

      // Unmount cancels the subscription
      await sub1.cancel();

      // Remounting a single-subscription static stream crashes
      // because we try to listen to the *same* static instance.
      expect(() => lxStream.valueStream.listen((_) {}), throwsStateError);

      await controller.close();
    });
  });
}
