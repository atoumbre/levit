import 'package:test/test.dart';
import 'package:levit_reactive/levit_reactive.dart';

void main() {
  group('LxComputed Manual Listeners', () {
    test('Manual addListener/removeListener manages lifecycle', () {
      final count = 0.lx;
      final computed = LxComputed(() => count.value * 2);

      int listenerCallCount = 0;
      int listener() => listenerCallCount++;

      // 1. Add listener
      computed.addListener(listener);
      expect(computed.hasListener, isTrue);
      // Adding listener triggers onActive -> _isDirty=true.

      // 2. Update dependency
      count.value = 5;
      // Triggers listener immediately (sync) or microtask?
      // Lx notifies sync.
      expect(listenerCallCount, 1);
      expect(computed.value, 10);

      // 3. Remove listener
      computed.removeListener(listener);
      // removal might be effective immediately
      expect(computed.hasListener, isFalse);

      // Force checking inactive state implicitly by re-adding and ensuring it re-activates
      computed.addListener(listener);
      expect(computed.hasListener, isTrue);
      // Clean up to hit onInactive again
      computed.removeListener(listener);
      // 4. Update dependency (should not trigger computation or listener)
      count.value = 10;
      expect(listenerCallCount, 1); // No change

      // 5. Read value (pull-based now, because inactive)
      expect(computed.value, 20); // Computed on demand
    });
  });
}
