import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';

void main() {
  group('levit_dart_core Final Gaps', () {
    tearDown(() {
      Levit.disableAutoLinking();
      Ls.reset(force: true);
    });

    test('state.dart:22, 30-31 - LevitRef find/findAsync with LevitState key',
        () async {
      final s1 = LevitState((ref) => 10);
      final s2 = LevitState((ref) {
        final val1 = ref.find<int>(key: s1);
        return val1 + 1;
      });

      final s3 = LevitAsyncState((ref) async {
        final val1 = await ref.findAsync<int>(key: s1);
        return val1 + 2;
      });

      expect(s2.find(), 11);
      expect(await s3.findAsync(), 12);
    });

    test('state.dart:174 - LevitAsyncState autoDispose captured reactives',
        () async {
      Levit.enableAutoLinking();

      final s = LevitAsyncState((ref) async {
        final _ = 0.lx; // Create it here to be captured
        return 1;
      });

      await s.findAsync();
    });

    test('auto_linking.dart:157-161 - Context-based owner linking', () {
      Levit.enableAutoLinking();
      Lx.runWithOwner('my-context-owner', () {
        runCapturedForTesting(() {
          final rx2 = 0.lx;
          expect(rx2.ownerId, 'my-context-owner');
        });
      });
    });

    test('core.dart:178 & 190 - Levit.delete and Levit.isInstantiated', () {
      Levit.lazyPut(() => 'hello', tag: 'my-tag');

      expect(Levit.isInstantiated<String>(tag: 'my-tag'), isFalse);

      Levit.find<String>(tag: 'my-tag');

      expect(Levit.isInstantiated<String>(tag: 'my-tag'), isTrue);
      expect(Levit.delete<String>(tag: 'my-tag'), isTrue);
    });
  });
}
