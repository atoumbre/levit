import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';

void main() {
  group('Auto-Linking Context Owner', () {
    tearDown(() {
      Levit.disableAutoLinking();
      Ls.reset(force: true);
    });

    test('Context-based owner linking', () {
      Levit.enableAutoLinking();
      Lx.runWithOwner('my-context-owner', () {
        runCapturedForTesting(() {
          final rx2 = 0.lx;
          expect(rx2.ownerId, 'my-context-owner');
        });
      });
    });
  });
}
