import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';

void main() {
  setUp(() => Levit.reset(force: true));
  tearDown(() => Levit.reset(force: true));

  group('Levit.runInScope', () {
    test('runs sync callback in isolated scope and auto-disposes it', () {
      final result = Levit.runInScope<int>(
        () {
          Levit.put(() => 42, tag: 'scoped_value');
          expect(Levit.find<int>(tag: 'scoped_value'), 42);
          return 7;
        },
        name: 'sync_scope',
      );

      expect(result, 7);
      expect(Levit.findOrNull<int>(tag: 'scoped_value'), isNull);
    });

    test('runs async callback in isolated scope and auto-disposes it',
        () async {
      final result = await Levit.runInScope<String>(
        () async {
          Levit.put(() => 'ok', tag: 'async_scoped_value');
          await Future<void>.delayed(Duration.zero);
          return Levit.find<String>(tag: 'async_scoped_value');
        },
        name: 'async_scope',
      );

      expect(result, 'ok');
      expect(Levit.findOrNull<String>(tag: 'async_scoped_value'), isNull);
    });

    test('disposes scope when callback throws', () {
      expect(
        () => Levit.runInScope<void>(
          () {
            Levit.put(() => 1, tag: 'error_scope_value');
            throw StateError('boom');
          },
          name: 'error_scope',
        ),
        throwsA(isA<StateError>()),
      );

      expect(Levit.findOrNull<int>(tag: 'error_scope_value'), isNull);
    });
  });
}
