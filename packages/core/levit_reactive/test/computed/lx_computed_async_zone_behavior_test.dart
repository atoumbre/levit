import 'dart:async';
import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

void main() {
  group('LxComputed.async Zone Coverage Patch', () {
    test('covers runBinary', () async {
      final completer = Completer<int>();

      final computed = LxComputed.async<int>(() async {
        final zone = Zone.current;
        try {
          // Exercise runBinary
          final result = zone.runBinary((int x, int y) {
            return x + y;
          }, 10, 20);
          completer.complete(result);
          return result;
        } catch (e, s) {
          completer.completeError(e, s);
          rethrow;
        }
      }, initial: 0);

      // Trigger computation by adding a listener (makes it active)
      void listener() {}
      computed.addListener(listener);

      final result = await completer.future.timeout(Duration(seconds: 1));
      expect(result, 30);

      computed.removeListener(listener);

      // Allow the computed to settle
      await Future.delayed(Duration(milliseconds: 10));
      if (computed.status is LxError) {
        fail('Computed failed with: ${(computed.status as LxError).error}');
      }
    });

    test('covers registerBinaryCallback', () async {
      final completer = Completer<int>();

      final computed = LxComputed.async<int>(() async {
        final zone = Zone.current;
        try {
          // Exercise registerBinaryCallback
          final cb = zone.registerBinaryCallback((int x, int y) {
            return x + y;
          });
          final result = cb(100, 200);
          completer.complete(result);
          return result;
        } catch (e, s) {
          completer.completeError(e, s);
          rethrow;
        }
      }, initial: 0);

      // Trigger computation
      void listener() {}
      computed.addListener(listener);

      final result = await completer.future.timeout(Duration(seconds: 1));
      expect(result, 300);

      computed.removeListener(listener);

      await Future.delayed(Duration(milliseconds: 10));
      if (computed.status is LxError) {
        fail('Computed failed with: ${(computed.status as LxError).error}');
      }
    });
  });
}
