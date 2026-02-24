import 'dart:async';
import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('Reactive Bind Stream Coverage', () {
    test('bind early returns if the same stream is bound again', () async {
      final v = 0.lx;
      final controller = StreamController<int>.broadcast();
      final stream = controller.stream;

      v.bind(stream);
      // Bind exact same stream again to hit line 912
      v.bind(stream);

      // Verify the stream is still bound properly
      expect(v.hasListener, isFalse);

      final events = <int>[];
      final sub = v.stream.listen(events.add);

      controller.add(42);
      await Future.delayed(Duration.zero);

      expect(events, contains(42));
      sub.cancel();
    });

    test('exercises _hasStreamListener logic natively', () {
      final v = 0.lx;
      final controller = StreamController<int>.broadcast();

      // Bind stream
      v.bind(controller.stream);

      // Create a computed that relies on v. This naturally invokes stream listeners locally.
      final comp = (() => v.value * 2).lx;

      final compEvents = <int>[];
      final compSub = comp.stream.listen(compEvents.add);

      // Listen to v's stream directly to increment externalListeners
      final vEvents = <int>[];
      final vSub = v.stream.listen(vEvents.add);

      controller.add(10);

      expect(v.hasListener, isTrue); // Should be true

      vSub.cancel();
      compSub.cancel();
      controller.close();
    });
  });
}
