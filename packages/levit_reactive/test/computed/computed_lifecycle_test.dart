import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('LxComputed Lifecycle via addListener', () {
    test('addListener activates computed when not already active', () {
      final count = 0.lx;

      // Create sync computed - note: it calculates initial value immediately
      // but is NOT active (no stream listeners, no addListener)
      final computed = LxComputed(() => count.value * 2);

      // Verify initial state
      expect(computed.hasListener, isFalse);
      // _isActive should be false at this point

      bool notified = false;
      void listener() => notified = true;

      // This should trigger line 166: _onActive() because !_isActive is true
      computed.addListener(listener);
      expect(computed.hasListener, isTrue);

      // Verify computation is working
      count.value = 5;
      expect(notified, isTrue);
      expect(computed.value, 10);

      // This should trigger line 173: _onInactive()
      // because after removal, !hasListener && _isActive
      computed.removeListener(listener);
      expect(computed.hasListener, isFalse);

      // Close to clean up
      computed.close();
    });

    test('async computed activates via addListener path', () async {
      final count = 0.lx;

      // Create async computed without listening to stream
      final computed = LxComputed.async(() async => count.value * 2);

      expect(computed.hasListener, isFalse);

      void listener() {}

      // This should go through line 166
      computed.addListener(listener);
      expect(computed.hasListener, isTrue);

      // Wait for initial computation
      await Future.delayed(const Duration(milliseconds: 50));

      // This should go through line 173
      computed.removeListener(listener);
      expect(computed.hasListener, isFalse);

      computed.close();
    });

    test('multiple addListener calls do not re-activate', () {
      final count = 0.lx;
      final computed = LxComputed(() => count.value * 2);

      void listener1() {}
      void listener2() {}

      // First add activates
      computed.addListener(listener1);
      expect(computed.hasListener, isTrue);

      // Second add should not call _onActive again (already active)
      computed.addListener(listener2);
      expect(computed.hasListener, isTrue);

      // Remove first - still have listener2
      computed.removeListener(listener1);
      expect(computed.hasListener, isTrue);

      // Remove second - now goes inactive
      computed.removeListener(listener2);
      expect(computed.hasListener, isFalse);

      computed.close();
    });
  });
}
