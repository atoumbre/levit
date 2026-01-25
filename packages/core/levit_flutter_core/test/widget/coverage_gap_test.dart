import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

void main() {
  setUp(() {
    Levit.reset(force: true);
  });

  group('Coverage Gaps - LevitProvider', () {
    testWidgets('putOrFind uses existing global instance', (tester) async {
      Levit.put<_TestService>(() => _TestService());

      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          final service =
              context.levit.putOrFind<_TestService>(() => _TestService());
          return Text('Service: ${service.hashCode}');
        }),
      ));

      expect(Levit.isRegistered<_TestService>(), isTrue);
    });

    testWidgets('putOrFind creates global instance if missing', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          final service =
              context.levit.putOrFind<_TestService>(() => _TestService());
          return Text('Service: ${service.hashCode}');
        }),
      ));

      expect(Levit.isRegistered<_TestService>(), isTrue);
    });

    testWidgets('putOrFind uses existing scoped instance', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: LScope(
          dependencyFactory: (s) => s.put<_TestService>(() => _TestService()),
          child: Builder(builder: (context) {
            final service =
                context.levit.putOrFind<_TestService>(() => _TestService());
            return Text('Service: ${service.hashCode}');
          }),
        ),
      ));
    });

    testWidgets('putOrFind creates scoped instance if missing', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: LScope(
          dependencyFactory: (s) =>
              s.put<String>(() => 'dummy'), // Just to create scope
          child: Builder(builder: (context) {
            final service =
                context.levit.putOrFind<_TestService>(() => _TestService());
            return Text('Service: ${service.hashCode}');
          }),
        ),
      ));
    });
    testWidgets('lazyPutAsync returns a finder function', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: LScope(
          dependencyFactory: (s) => s.put<String>(() => 'dummy'),
          child: Builder(builder: (context) {
            final finder = context.levit
                .lazyPutAsync<_TestService>(() async => _TestService());
            return TextButton(
              onPressed: () async {
                final service = await finder();
                debugPrint('Service: ${service.hashCode}');
              },
              child: const Text('Find'),
            );
          }),
        ),
      ));

      expect(find.text('Find'), findsOneWidget);
    });
  });

  group('Coverage Gaps - LView', () {
    testWidgets('LView in Scope', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: LScope(
          dependencyFactory: (s) => s.put<_TestService>(() => _TestService()),
          child: LView<_TestService>(
            resolver: (context) => context.levit.find<_TestService>(),
            builder: (context, controller) => const Text('Controller Found'),
          ),
        ),
      ));

      expect(find.text('Controller Found'), findsOneWidget);
    });
  });

  group('Coverage Gaps - LWatch', () {
    testWidgets('LWatch cleans up subscriptions when dependencies removed',
        (tester) async {
      final notifier = 0.lx;
      final toggle = true.lx;

      await tester.pumpWidget(MaterialApp(
        home: LWatch(() {
          if (toggle.value) {
            // Depend on notifier
            return Text('Value: ${notifier.value}');
          } else {
            // Depend on nothing
            return const Text('Value: Clean');
          }
        }),
      ));

      expect(find.text('Value: 0'), findsOneWidget);

      toggle.value = false;
      await tester.pump();
      expect(find.text('Value: Clean'), findsOneWidget);
    });
  });

  group('Coverage Gaps - LScopedView', () {
    testWidgets('LScopedView updates correctly', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        home: _UpdateableScopedView(key: key, tag: '1'),
      ));

      expect(find.text('Tag: 1'), findsOneWidget);

      await tester.pumpWidget(MaterialApp(
        home: _UpdateableScopedView(key: key, tag: '2'),
      ));

      expect(find.text('Tag: 2'), findsOneWidget);
    });

    testWidgets('LScopedView.async handles loading and resolution',
        (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp(
          home: LScope(
            dependencyFactory: (s) {
              s.lazyPutAsync<_TestService>(() async {
                await Future.delayed(const Duration(milliseconds: 100));
                return _TestService();
              });
            },
            // resolver: (context) => context.levit.findAsync<_TestService>(),
            // builder: (context, controller) => const Text('Resolved'),
            child: LAsyncView<_TestService>(
              resolver: (context) => context.levit.findAsync<_TestService>(),
              loading: (context) => const Text('Loading...'),
              builder: (context, controller) => const Text('Resolved'),
            ),
          ),
        ));

        expect(find.text('Loading...'), findsOneWidget);

        await Future.delayed(const Duration(milliseconds: 150));
        await tester.pump();

        expect(find.text('Resolved'), findsOneWidget);
      });
    });
  });
}

class _TestService {}

class _UpdateableScopedView extends StatelessWidget {
  final String tag;
  const _UpdateableScopedView({super.key, required this.tag});

  @override
  Widget build(BuildContext context) {
    return LScopedView<_TestService>(
      dependencyFactory: (s) =>
          s.put<_TestService>(() => _TestService(), tag: tag),
      resolver: (context) => context.levit.find<_TestService>(tag: tag),
      args: [tag],
      builder: (context, controller) => Text('Tag: $tag'),
    );
  }
}
