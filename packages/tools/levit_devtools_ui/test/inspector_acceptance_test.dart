import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_devtools_ui/main.dart' as ui;
import 'package:web_socket_channel/web_socket_channel.dart';

class Channel implements WebSocketChannel {
  final incoming = StreamController<dynamic>();
  final connected = Completer<void>();
  @override
  final Output sink = Output();
  @override
  Stream<dynamic> get stream => incoming.stream;
  @override
  Future<void> get ready => connected.future;
  void send(Map<String, dynamic> message) => incoming.add(jsonEncode(message));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Output implements WebSocketSink {
  final sent = <Map<String, dynamic>>[];
  bool closed = false;
  @override
  void add(dynamic value) =>
      sent.add(Map<String, dynamic>.from(jsonDecode(value as String) as Map));
  @override
  Future<void> close([int? code, String? reason]) async {
    closed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> event(
  int seq, {
  String type = 'state_change',
  String category = 'state',
}) => {
  'sessionId': 'app',
  'seq': seq,
  'type': type,
  'category': category,
  'timestamp': DateTime(2026).toIso8601String(),
  'reactiveId': '1',
  'name': 'count',
  'valueType': 'int',
  'oldValue': '$seq',
  'newValue': '${seq + 1}',
};
const sessions = [
  {'id': 'app', 'appId': 'Application', 'connected': true},
  {'id': 'server', 'appId': 'Backend', 'connected': false},
];
Map<String, dynamic> snapshot({
  Map<String, dynamic> state = const {},
  List<Map<String, dynamic>> timeline = const [],
}) => {
  'kind': 'snapshot',
  'session': {'id': 'app'},
  'state': state,
  'timeline': timeline,
};

Future<void> mount(WidgetTester tester, Channel channel) async {
  tester.view.physicalSize = const Size(1600, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  channel.connected.complete();
  await tester.pumpWidget(
    MaterialApp(home: ui.InspectorScreen(channelFactory: (_) => channel)),
  );
  channel.send({'kind': 'sessions', 'sessions': sessions});
  channel.send(snapshot());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'application entrypoint mounts the inspector and cleans up connection attempts',
    (tester) async {
      ui.main();
      await tester.pump();
      expect(find.text('Levit Inspector'), findsOneWidget);
      expect(find.byType(ui.InspectorScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    },
  );

  testWidgets(
    'ownership, relationships, task descendants, filters and redacted export are actionable',
    (tester) async {
      final channel = Channel();
      await mount(tester, channel);
      channel.send(
        snapshot(
          state: {
            'scopes': [
              {
                'id': 1,
                'name': 'root',
                'progress': {
                  'registrations': [
                    {'isClosing': true},
                  ],
                },
              },
              {'id': 2, 'name': 'feature', 'parentScopeId': 1},
              {
                'id': 3,
                'name': 'initializing',
                'progress': {
                  'registrations': [
                    {'pendingInitializations': 1},
                  ],
                },
              },
            ],
            'dependencies': [
              {
                'scopeId': 1,
                'key': 'Controller',
                'isLazy': false,
                'isFactory': false,
                'isAsync': false,
                'status': 'active',
                'type': 'controller',
              },
              {
                'scopeId': 2,
                'key': 'factory',
                'isLazy': true,
                'isFactory': true,
                'isAsync': false,
                'status': 'registered',
                'type': 'other',
              },
            ],
            'variables': [
              {
                'id': 1,
                'name': 'count',
                'ownerId': '1:Controller',
                'value': '2',
                'dependencies': [],
                'listenerCount': 1,
              },
              {
                'id': 2,
                'name': 'double',
                'value': '4',
                'dependencies': [1],
                'listenerCount': 1,
              },
            ],
            'taskTrees': {
              'owner': {
                'tree': {
                  'id': 'root-task',
                  'name': 'save',
                  'pendingCount': 0,
                  'runningCount': 1,
                  'children': [
                    {
                      'id': 'child',
                      'name': 'upload',
                      'executionIds': ['execution'],
                      'children': [],
                    },
                  ],
                },
              },
            },
          },
          timeline: [
            event(1),
            event(2, type: 'log', category: 'log'),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Controller'), findsOneWidget);
      expect(find.text('feature #2'), findsOneWidget);
      expect(find.text('1 reactive values'), findsOneWidget);
      expect(find.text('double #2'), findsOneWidget);
      await tester.tap(find.text('Export JSON'));
      await tester.tap(find.text('Reactions'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Reads: count #1'), findsOneWidget);
      await tester.tap(find.text('count #1'));
      await tester.pumpAndSettle();
      expect(find.textContaining('#1 state_change'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.widgetWithText(ChoiceChip, 'log'));
      await tester.pumpAndSettle();
      expect(find.textContaining('#1 state_change'), findsNothing);
      await tester.tap(find.textContaining('#2 log'));
      await tester.pumpAndSettle();
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      await tester.tap(find.text('Copy redacted event'));
      await tester.pump();
      expect(jsonDecode(copied!)['seq'], 2);
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      expect(find.text('upload · child'), findsOneWidget);
      expect(find.text('Execution execution'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'missing');
      await tester.pumpAndSettle();
      expect(find.text('save · root-task'), findsNothing);
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('Cleanup'));
      await tester.pumpAndSettle();
      expect(find.text('root #1'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Backend').last);
      channel.send({
        ...snapshot(),
        'session': {'id': 'server'},
      });
      await tester.pumpAndSettle();
      expect(
        channel.sink.sent.lastWhere((m) => m.containsKey('select'))['select'],
        'server',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(channel.incoming.close);
    },
  );

  testWidgets(
    'timeline remains bounded across snapshots and live updates; removed sessions clear selection',
    (tester) async {
      final channel = Channel();
      await mount(tester, channel);
      channel.send({
        ...snapshot(timeline: List.generate(1002, (i) => event(i))),
        'sessions': sessions,
      });
      await tester.pumpAndSettle();
      channel.send({
        'kind': 'event',
        'session': {'id': 'server'},
        'event': event(9999),
      });
      channel.send({
        'kind': 'event',
        'session': {'id': 'app'},
        'event': event(1002),
      });
      await tester.pumpAndSettle();
      await tester.tap(find.text('Timeline'));
      await tester.pumpAndSettle();
      expect(find.textContaining('#1002 state_change'), findsOneWidget);
      expect(find.textContaining('#9999'), findsNothing);
      await tester.enterText(find.byType(TextField), '"seq": 0');
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNothing);
      channel.send({
        'kind': 'event',
        'session': {'id': 'app'},
        'event': {...event(1003), 'type': 'snapshot', 'state': {}},
      });
      await tester.pumpAndSettle();
      channel.send({'kind': 'sessions', 'sessions': []});
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Export JSON'))
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(channel.incoming.close);
    },
  );

  testWidgets(
    'reconnect ignores obsolete readiness failure and reselects the session',
    (tester) async {
      final first = Channel();
      final next = Channel()..connected.complete();
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ui.InspectorScreen(
            channelFactory: (_) => attempts++ == 0 ? first : next,
          ),
        ),
      );
      first.send({'kind': 'sessions', 'sessions': sessions});
      await tester.pump();
      first.incoming.addError(StateError('lost connection'));
      await tester.pump();
      expect(find.textContaining('Disconnected'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text('Connected'), findsOneWidget);
      expect(next.sink.sent, contains(equals({'select': 'app'})));
      first.connected.completeError(StateError('obsolete handshake'));
      await tester.pump();
      expect(find.text('Connected'), findsOneWidget);
      expect(next.sink.closed, isFalse);
      next.incoming.add('{invalid');
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Disconnected'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(first.incoming.close);
      await tester.runAsync(next.incoming.close);
    },
  );

  testWidgets(
    'synchronous connection failure retries and empty task state is useful',
    (tester) async {
      final channel = Channel()..connected.complete();
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ui.InspectorScreen(
            channelFactory: (_) {
              if (attempts++ == 0) throw StateError('connect');
              return channel;
            },
          ),
        ),
      );
      expect(find.textContaining('Disconnected'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      channel.send({'kind': 'sessions', 'sessions': sessions});
      channel.send(snapshot());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      expect(find.text('No task adapter attached'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(channel.incoming.close);
    },
  );

  testWidgets(
    'cyclic ownership records are visible without recursive rendering',
    (tester) async {
      final channel = Channel();
      await mount(tester, channel);
      channel.send(
        snapshot(
          state: {
            'scopes': [
              {'id': 1, 'name': 'cycle-a', 'parentScopeId': 2},
              {'id': 2, 'name': 'cycle-b', 'parentScopeId': 1},
            ],
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Scope ancestry cycle'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(channel.incoming.close);
    },
  );
}
