import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:levit_dart_core/spi.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    Levit.disableAutoLinking();
    LevitAutoLinkSpi.resetAutoLinkingPreference();
    await Levit.reset(force: true);
  });

  group('LevitAutoLinkSpi default preference', () {
    test(
      'enables auto-linking by default unless explicitly disabled by user',
      () {
        Levit.disableAutoLinking();
        LevitAutoLinkSpi.resetAutoLinkingPreference();
        expect(Levit.isAutoLinkingEnabled, isFalse);

        LevitAutoLinkSpi.ensureFlutterDefaultAutoLinking();
        expect(Levit.isAutoLinkingEnabled, isTrue);

        // Explicit opt-out prevents default Flutter initialization from re-enabling.
        Levit.disableAutoLinking();
        expect(Levit.isAutoLinkingEnabled, isFalse);

        LevitAutoLinkSpi.ensureFlutterDefaultAutoLinking();
        expect(Levit.isAutoLinkingEnabled, isFalse);

        // Clearing the opt-out allows default initialization to enable again.
        LevitAutoLinkSpi.resetAutoLinkingPreference();
        LevitAutoLinkSpi.ensureFlutterDefaultAutoLinking();
        expect(Levit.isAutoLinkingEnabled, isTrue);
      },
    );
  });
}
