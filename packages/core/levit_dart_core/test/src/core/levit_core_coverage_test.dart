import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';

void main() {
  group('Levit Core and Auto-Linking Coverage', () {
    tearDown(() {
      Levit.disableAutoLinking();
      Levit.reset(force: true);
    });

    test('Levit Core methods fallback coverage', () async {
      // findOrNull success/fail
      Levit.put(() => 'ok', tag: 'ok_tag');
      expect(Levit.findOrNull<String>(tag: 'ok_tag'), 'ok');

      Levit.lazyPut<String>(() => throw Exception('error'),
          tag: 'throwing_tag');
      expect(Levit.findOrNull<String>(tag: 'throwing_tag'), isNull);

      // findAsync success
      Levit.lazyPutAsync(() async => 'async', tag: 'async_tag');
      expect(await Levit.findAsync<String>(tag: 'async_tag'), 'async');

      // findOrNullAsync success/fail
      expect(await Levit.findOrNullAsync<String>(tag: 'async_tag'), 'async');
      expect(await Levit.findOrNullAsync<String>(tag: 'missing_async'), isNull);

      // isRegistered/isInstantiated coverage
      expect(Levit.isRegistered<String>(tag: 'dep'), false);
      Levit.lazyPut<String>(() => 'dep', tag: 'dep');
      expect(Levit.isRegistered<String>(tag: 'dep'), true);
      expect(Levit.isInstantiated<String>(tag: 'dep'), false);
      expect(Levit.find<String>(tag: 'dep'), 'dep');
      expect(Levit.isInstantiated<String>(tag: 'dep'), true);
    });

    test('Auto-linking coverage gaps', () {
      Levit.enableAutoLinking();

      // runCaptured without ownerId (auto_linking.dart line 60)
      runCapturedForTesting(() => 1);

      // Chained capture and Adoption in processInstance (auto_linking.dart 184-185)
      Levit.put(() {
        1.lx;
        2.lx;
        return 'test';
      }, tag: 'multi');

      Levit.disableAutoLinking();
    });
  });
}
