import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_devtools_extension/src/client/devtools_client.dart';
import 'package:levit_devtools_extension/src/views/levit_devtools_screen.dart';
import 'package:levit_monitor/spi.dart';

import 'inspector_controller_test.dart';

void main() {
  group('LevitDevToolsScreen widget behavior', () {
    testWidgets('shows setup instructions when LevitDevTools is not attached', (
      tester,
    ) async {
      final client = FakeDevToolsClient(
        snapshotResult: const LevitRemoteSnapshotResult.unattached(),
      );
      addTearDown(client.dispose);

      await tester.pumpWidget(
        MaterialApp(home: LevitDevToolsScreen(client: client)),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('LevitDevTools is not attached in the running app'),
        findsOneWidget,
      );
      expect(find.text('Not Attached'), findsOneWidget);
    });

    testWidgets('renders all five tabs when attached to a monitored snapshot', (
      tester,
    ) async {
      final client = FakeDevToolsClient(
        snapshotResult: LevitRemoteSnapshotResult(
          attached: true,
          snapshot: {
            'scopes': [
              {'id': 1, 'name': 'app', 'parentScopeId': null, 'progress': {}},
              {'id': 2, 'name': 'checkout', 'parentScopeId': 1, 'progress': {}},
            ],
            'dependencies': [
              {
                'scopeId': 2,
                'key': 'CartController',
                'isLazy': false,
                'isFactory': false,
                'isAsync': false,
                'status': 'active',
                'type': 'controller',
                'value': 'CartController',
              },
            ],
            'variables': [
              {
                'id': 10,
                'name': 'subtotal',
                'ownerId': '2:CartController',
                'isSensitive': false,
                'value': '99',
                'valueType': 'int',
                'dependencies': <int>[],
                'listenerCount': 3,
              },
              {
                'id': 11,
                'name': 'total',
                'ownerId': '2:CartController',
                'isSensitive': false,
                'value': '109',
                'valueType': 'int',
                'dependencies': <int>[10],
                'listenerCount': 1,
              },
              {
                'id': 12,
                'name': 'orphanFlag',
                'ownerId': null,
                'isSensitive': false,
                'value': 'true',
                'valueType': 'bool',
                'dependencies': <int>[],
                'listenerCount': 0,
              },
            ],
            'taskTrees': {
              '2:CartController': {
                'ownerPath': '2:CartController',
                'status': 'running',
                'tasks': [
                  {'id': 'upload-1', 'state': 'running'},
                ],
              },
            },
          },
        ),
        history: [
          LevitEventEnvelope.stateChange(
            sessionId: 's1',
            seq: 1,
            timestamp: '2026-11-26T00:00:00Z',
            reactiveId: '10',
            name: 'subtotal',
            ownerId: '2:CartController',
            isSensitive: false,
            oldValue: '50',
            newValue: '99',
            valueType: 'int',
          ),
        ],
      );
      addTearDown(client.dispose);

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(home: LevitDevToolsScreen(client: client)),
      );
      await tester.pumpAndSettle();

      // Header + Scopes tab
      expect(find.text('Connected (Read-Only)'), findsOneWidget);
      expect(find.text('app (#1)'), findsOneWidget);
      expect(find.text('checkout (#2)'), findsOneWidget);

      await tester.tap(find.text('checkout (#2)'));
      await tester.pumpAndSettle();
      expect(find.text('CartController'), findsOneWidget);

      // Reactives tab
      await tester.tap(find.text('Reactives (3)'));
      await tester.pumpAndSettle();
      expect(find.text('subtotal'), findsWidgets);
      expect(find.text('total'), findsWidgets);

      // Tasks tab
      await tester.tap(find.text('Tasks (1)'));
      await tester.pumpAndSettle();
      expect(find.text('2:CartController'), findsOneWidget);

      // Timeline tab
      await tester.tap(find.text('Timeline (1)'));
      await tester.pumpAndSettle();
      expect(find.text('#1 • state_change'), findsOneWidget);

      // Diagnostics tab
      await tester.tap(find.text('Diagnostics'));
      await tester.pumpAndSettle();
      expect(find.text('unowned_reactives'), findsOneWidget);
    });
  });
}
