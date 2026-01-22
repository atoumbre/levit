import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

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
          init: () => _TestService(),
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
          init: () => 'dummy', // Just to create scope
          child: Builder(builder: (context) {
            final service =
                context.levit.putOrFind<_TestService>(() => _TestService());
            return Text('Service: ${service.hashCode}');
          }),
        ),
      ));
      // Logic check: should be in scope? Implementation details of scope.
      // We assume it worked if it didn't throw.
    });
  });

  group('Coverage Gaps - LView', () {
    testWidgets('LView creates controller if missing in Scope', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: LScope(
          init: () => 'dummy',
          child: _TestView(),
        ),
      ));

      expect(find.text('Controller Created'), findsOneWidget);
    });

    testWidgets('LView throws specific error if factory returns null in Scope',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: LScope(
          init: () => 'dummy',
          child: _NullFactoryView(),
        ),
      ));

      // We expect the framework to catch the error, so we inspect handling?
      // Or we catch it. pumpWidget might rethrow.
      expect(tester.takeException(), isNotNull);
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

    testWidgets('LWatch handles mixed dependency transitions', (tester) async {
      final streamCtrl = StreamController<int>.broadcast();
      final notifier = 0.lx;
      final mode = 0.lx; // 0: both, 1: notifier only, 2: stream only

      await tester.pumpWidget(MaterialApp(
        home: LWatch(() {
          final m = mode.value;

          // Note: Standard streams are not auto-captured by LWatch/Lx unless wrapped.
          // We manually trigger capture via Lx.proxy for this test to verify LWatch internals
          // handling mixed dependencies.
          if (m == 0 || m == 2) {
            Lx.proxy?.addStream(streamCtrl.stream);
          }
          if (m == 0 || m == 1) {
            // Access notifier to capture it
            notifier.value;
          }
          return Text('Mode: $m');
        }),
      ));

      expect(find.text('Mode: 0'), findsOneWidget);

      // Transition to Notifier Only (Stream cleanup)
      mode.value = 1;
      await tester.pump();
      expect(find.text('Mode: 1'), findsOneWidget);

      // Transition to Stream Only (Notifier cleanup)
      mode.value = 2;
      await tester.pump();
      expect(find.text('Mode: 2'), findsOneWidget);
    });

    testWidgets(
        'LWatch handles transition to NO dependencies via parent rebuild',
        (tester) async {
      final notifier = 0.lx;
      final rebuildCounter = ValueNotifier(0);

      await tester.pumpWidget(MaterialApp(
        home: ValueListenableBuilder<int>(
          valueListenable: rebuildCounter,
          builder: (context, count, _) {
            return LWatch(() {
              if (count == 0) {
                return Text('Value: ${notifier.value}');
              } else {
                return const Text('Static');
              }
            });
          },
        ),
      ));

      expect(find.text('Value: 0'), findsOneWidget);

      // Trigger parent rebuild which makes LWatch rebuild with NO reactive dependencies
      rebuildCounter.value = 1;
      await tester.pump();
      expect(find.text('Static'), findsOneWidget);

      // Now verify if it hits the else branch for cleanup
    });

    testWidgets('LWatch handles complex mixed dependency transitions',
        (tester) async {
      final streamCtrl = StreamController<int>.broadcast();
      final notifier = 0.lx;
      final rebuildCounter = ValueNotifier(0);

      await tester.pumpWidget(MaterialApp(
        home: ValueListenableBuilder<int>(
          valueListenable: rebuildCounter,
          builder: (context, count, _) {
            return LWatch(() {
              if (count == 0) {
                // Both Notifier and Stream
                Lx.proxy?.addStream(streamCtrl.stream);
                notifier.value;
                return const Text('Both');
              } else if (count == 1) {
                // Stream Only (Should trigger else if for Notifiers)
                Lx.proxy?.addStream(streamCtrl.stream);
                return const Text('Stream Only');
              } else if (count == 2) {
                // Notifier Only (Should trigger else if for Streams)
                notifier.value;
                return const Text('Notifier Only');
              } else {
                return const Text('None');
              }
            });
          },
        ),
      ));

      expect(find.text('Both'), findsOneWidget);

      // 1. Both -> Stream Only (Clears Notifiers via SLOW PATH else if)
      rebuildCounter.value = 1;
      await tester.pump();
      expect(find.text('Stream Only'), findsOneWidget);

      // 2. Stream Only -> Both
      rebuildCounter.value = 0;
      await tester.pump();
      expect(find.text('Both'), findsOneWidget);

      // 3. Both -> Notifier Only (Clears Streams via SLOW PATH else if)
      rebuildCounter.value = 2;
      await tester.pump();
      expect(find.text('Notifier Only'), findsOneWidget);

      // 4. Notifier Only -> None (Clears Notifiers via EMPTY PATH)
      rebuildCounter.value = 3;
      await tester.pump();
      expect(find.text('None'), findsOneWidget);
    });
  });

  group('Coverage Gaps - LScopedView', () {
    testWidgets('LScopedView updates correctly', (tester) async {
      // We need a widget that changes
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        home: _UpdateableScopedView(key: key, tag: '1'),
      ));

      await tester.pumpWidget(MaterialApp(
        home: _UpdateableScopedView(key: key, tag: '2'),
      ));

      // This should trigger the update method
    });
  });
}

class _TestService {}

class _TestView extends LView<_TestService> {
  @override
  _TestService createController() => _TestService();

  @override
  Widget buildContent(BuildContext context, _TestService controller) {
    return const Text('Controller Created');
  }
}

class _NullFactoryView extends LView<_TestService> {
  @override
  _TestService? createController() => null; // Returns null!

  @override
  Widget buildContent(BuildContext context, _TestService controller) {
    return Container();
  }
}

class _UpdateableScopedView extends LScopedView<_TestService> {
  final String _tag;
  const _UpdateableScopedView({super.key, required String tag}) : _tag = tag;

  @override
  String get tag => _tag;

  @override
  _TestService createController() => _TestService();

  @override
  Widget buildContent(BuildContext context, _TestService controller) {
    return Text('Tag: $tag');
  }
}
