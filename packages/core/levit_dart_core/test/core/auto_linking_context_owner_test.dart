import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';
import 'package:levit_dart_core/spi.dart';

void main() {
  group('Auto-Linking Context Owner', () {
    tearDown(() async {
      Levit.disableAutoLinking();
      await Ls.reset(force: true);
    });

    test('Context-based owner linking', () {
      Levit.enableAutoLinking();
      LxSpi.runWithOwner('my-context-owner', () {
        LevitAutoLinkSpi.runCaptured(() {
          final rx2 = 0.lx;
          expect(rx2.ownerId, 'my-context-owner');
        });
      });
    });
  });
}
