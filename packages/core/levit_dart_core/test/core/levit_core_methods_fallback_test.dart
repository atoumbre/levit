import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';
import 'package:levit_dart_core/spi.dart';

void main() {
  group('Dependency lookup and reactive capture', () {
    tearDown(() async {
      Levit.disableAutoLinking();
      await Levit.reset(force: true);
    });

    test(
      'lookups propagate builder errors and expose lazy initialization state',
      () async {
        // findOrNull success/fail
        Levit.put(() => 'ok', tag: 'ok_tag');
        expect(Levit.findOrNull<String>(tag: 'ok_tag'), 'ok');

        Levit.lazyPut<String>(
          () => throw Exception('error'),
          tag: 'throwing_tag',
        );
        expect(
          () => Levit.findOrNull<String>(tag: 'throwing_tag'),
          throwsException,
        );

        // findAsync success
        Levit.lazyPutAsync(() async => 'async', tag: 'async_tag');
        expect(await Levit.findAsync<String>(tag: 'async_tag'), 'async');

        // findOrNullAsync success/fail
        expect(await Levit.findOrNullAsync<String>(tag: 'async_tag'), 'async');
        expect(
          await Levit.findOrNullAsync<String>(tag: 'missing_async'),
          isNull,
        );

        // isRegistered/isInstantiated coverage
        expect(Levit.isRegistered<String>(tag: 'dep'), false);
        Levit.lazyPut<String>(() => 'dep', tag: 'dep');
        expect(Levit.isRegistered<String>(tag: 'dep'), true);
        expect(Levit.isInstantiated<String>(tag: 'dep'), false);
        expect(Levit.find<String>(tag: 'dep'), 'dep');
        expect(Levit.isInstantiated<String>(tag: 'dep'), true);
      },
    );

    test(
      'auto-linking accepts unowned capture and non-controller registrations',
      () {
        Levit.enableAutoLinking();

        // runCaptured without ownerId (auto_linking.dart line 60)
        LevitAutoLinkSpi.runCaptured(() => 1);

        // Chained capture and Adoption in processInstance (auto_linking.dart 184-185)
        Levit.put(() {
          1.lx;
          2.lx;
          return 'test';
        }, tag: 'multi');

        Levit.disableAutoLinking();
      },
    );
  });
}
