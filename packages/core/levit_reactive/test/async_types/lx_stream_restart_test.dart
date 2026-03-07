import 'dart:async';
import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('LxStream Restarts', () {
    test('restartDeferred rebinds immediately if there are active listeners',
        () async {
      final controller1 = StreamController<int>();
      final controller2 = StreamController<int>();

      final lxStream = LxStream.defer(() => controller1.stream);

      // Add a listener to activate the stream bindings
      final values = <LxStatus<int>>[];
      final sub = lxStream.stream.listen(values.add);

      // Verify first stream is bound
      expect(lxStream.hasListener, isTrue);

      // Restarting while there is an active listener should immediately check pending bind
      // and attach the newly deferred stream.
      lxStream.restartDeferred(() => controller2.stream);

      // The new stream stream should immediately be observed. Let's emit to the new stream.
      controller2.add(42);
      await Future.delayed(Duration.zero);

      expect(lxStream.value, isA<LxSuccess<int>>());
      expect((lxStream.value as LxSuccess<int>).value, 42);

      await sub.cancel();
      await controller1.close();
      await controller2.close();
    });
  });
}
