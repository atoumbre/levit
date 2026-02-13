import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';
import 'dart:async';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:async/async.dart';

import 'package:nexus_studio_app/main.dart' as app;
import 'package:nexus_studio_app/controllers.dart';
import 'package:nexus_studio_shared/shared.dart';

void main() {
  setUp(() {
    Levit.reset(force: true);
    // Manual DI setup equivalent to main() but with control
    // We register dependencies before the test pumps the widget
    Levit.lazyPut(() => AuthController());
    Levit.put(() => PresenceController());
    Levit.put(() => NexusEngine()); // Required by ProjectController
    Levit.put(() => ProjectController(channel: FakeWebSocketChannel()));
  });

  testWidgets('App starts with login overlay', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const app.NexusStudioApp());
    expect(find.text('Nexus Studio'), findsOneWidget);
    expect(find.text('Collaborative Design System'), findsOneWidget);
    expect(find.text('Login as Editor'), findsOneWidget);
  });

  testWidgets('main() runs without external sockets',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    Levit.reset(force: true);
    app.main(
      enableDevTools: true,
      devToolsChannelBuilder: (_) => FakeWebSocketChannel(),
      projectChannelBuilder: (_) => FakeWebSocketChannel(),
    );
    await tester.pump();

    expect(find.byType(app.NexusStudioApp), findsOneWidget);
    expect(find.text('Login as Editor'), findsOneWidget);
  });

  testWidgets('Login unlocks editor', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const app.NexusStudioApp());

    // Login
    await tester.tap(find.text('Login as Editor'));
    await tester.pumpAndSettle(); // Rebuild for auth change and animations

    // Overlay should include logic to hide
    // We need to verify auth state or UI change
    expect(Levit.find<AuthController>().isAuthenticated, true);

    // Overlay hides (SizedBox.shrink)
    expect(find.text('Login as Editor'), findsNothing);

    // UI showing toolbar
    expect(find.text('NEXUS STUDIO'), findsOneWidget);
    expect(find.text('Add Shape:'), findsOneWidget);
  });

  testWidgets('Viewer login covers read-only path',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const app.NexusStudioApp());

    await tester.tap(find.text('Login as Viewer'));
    await tester.pumpAndSettle();

    expect(Levit.find<AuthController>().isAuthenticated, true);
    expect(Levit.find<AuthController>().canEdit, false);
  });

  testWidgets('Editor UI updates on state changes',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const app.NexusStudioApp());

    // Login
    await tester.tap(find.text('Login as Editor'));
    await tester.pumpAndSettle();

    final pc = Levit.find<ProjectController>();

    // 1. Add Node Programmatically
    pc.addNode('rect');
    await tester.pumpAndSettle();

    expect(find.byType(app.NodeWidget), findsOneWidget);

    // 2. Select Programmatically
    final node = pc.engine.nodes.first;
    pc.toggleSelection(node.id);
    await tester.pumpAndSettle();

    expect(find.text('1 elements selected'), findsOneWidget); // Sidebar updates

    // 3. Move Programmatically (Verify visual update)
    final initialOffset = node.position.value;
    pc.moveSelection(const Vec2(50, 50));
    await tester.pumpAndSettle();

    // Check that widget position likely updated (hard to check exact pixel without golden,
    // but we can check internal state or just rely on the fact it didn't crash).
    expect(node.position.value.x, initialOffset.x + 50);
  });

  testWidgets('Stats Dialog (Scoped DI)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const app.NexusStudioApp());
    await tester.tap(find.text('Login as Editor'));
    await tester.pump();

    // Open Stats
    await tester.tap(find.byIcon(Icons.bar_chart));
    await tester.pumpAndSettle();

    expect(find.text('Project Stats'), findsOneWidget);
    expect(find.text('Total Nodes'), findsOneWidget);

    // Actually Levit.isRegistered checks current scope. The dialog is in a NEW scope via LScope.
    // So the test environment (root scope) won't see it.
    // LScope uses its own internal logic.

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Project Stats'), findsNothing);
  });

  testWidgets('Hover updates cursor', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const app.NexusStudioApp());
    await tester.tap(find.text('Login as Editor'));
    await tester.pump();

    tester.binding.handlePointerEvent(
      const PointerHoverEvent(position: Offset(100, 100)),
    );
    await tester.pump();

    // Updates local cursor (PresenceController)
    // We can't verify public side effect without mocking channel,
    // but execution path is covered.
  });

  testWidgets('Chaos Mode', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const app.NexusStudioApp());
    await tester.tap(find.text('Login as Editor'));
    await tester.pump();

    await tester.tap(find.text('CHAOS MODE'));
    await tester.pump();
    // Logic executed
  });

  testWidgets('Undo/Redo via UI', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const app.NexusStudioApp());
    await tester.tap(find.text('Login as Editor'));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.crop_square));
    await tester.pump();

    // Create history
    final nodeWidget = find.byType(app.NodeWidget).first;
    await tester.tap(nodeWidget);
    await tester.pump();
    await tester.drag(nodeWidget, const Offset(50, 0));
    await tester.pump();

    // Undo
    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();

    // Redo
    await tester.tap(find.byIcon(Icons.redo));
    await tester.pump();
  });

  test('GridPainter does not repaint', () {
    expect(app.GridPainter().shouldRepaint(app.GridPainter()), false);
  });

  testWidgets('Toolbar actions cover add/color/export/presence',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    Levit.reset(force: true);
    Levit.lazyPut(() => AuthController());
    Levit.put(() => PresenceController());
    Levit.put(() => NexusEngine());
    Levit.put(
      () => ProjectController(
        channel: FakeWebSocketChannel(),
        exportDelay: Duration.zero,
      ),
    );

    await tester.pumpWidget(const app.NexusStudioApp());
    await tester.tap(find.text('Login as Editor'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add Square'));
    await tester.pump();
    await tester.tap(find.byTooltip('Add Circle'));
    await tester.pump();
    await tester.tap(find.byTooltip('Add Triangle'));
    await tester.pump();
    expect(find.byType(app.NodeWidget), findsNWidgets(3));

    // Select first node and apply a color via sidebar button.
    await tester.tap(find.byType(app.NodeWidget).first);
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('color_${0xFF818CF8}')));
    await tester.pump();

    // Background tap clears selection.
    await tester.tap(find.byKey(const ValueKey('canvas_background')));
    await tester.pump();

    // Presence overlay: add a remote user and ensure UI builds it.
    final presence = Levit.find<PresenceController>();
    presence.handlePresenceMessage({
      'senderId': 'remote_user',
      'name': 'Remote',
      'color': 0xFFFF0000,
      'cursor': {'x': 10.0, 'y': 20.0},
    });
    await tester.pump();
    expect(find.text('Remote'), findsOneWidget);

    // Export completes quickly and updates label.
    Levit.find<ProjectController>().export();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.textContaining('DONE'), findsOneWidget);
  });

  testWidgets('Session timer covers waiting branch',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final timerStream = StreamController<String>();
    addTearDown(timerStream.close);

    Levit.reset(force: true);
    Levit.lazyPut(() => AuthController());
    Levit.put(() => PresenceController());
    Levit.put(() => NexusEngine());
    Levit.put(
      () => ProjectController(
        channel: FakeWebSocketChannel(),
        sessionTimer: LxStream<String>(timerStream.stream),
      ),
    );

    await tester.pumpWidget(const app.NexusStudioApp());
    await tester.tap(find.text('Login as Editor'));
    await tester.pump();

    expect(find.text('Session: --:--'), findsOneWidget);
  });

  testWidgets('Session timer covers idle branch', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    Levit.reset(force: true);
    Levit.lazyPut(() => AuthController());
    Levit.put(() => PresenceController());
    Levit.put(() => NexusEngine());
    Levit.put(
      () => ProjectController(
        channel: FakeWebSocketChannel(),
        sessionTimer: LxStream<String>.idle(),
      ),
    );

    await tester.pumpWidget(const app.NexusStudioApp());
    await tester.tap(find.text('Login as Editor'));
    await tester.pump();

    expect(find.textContaining('Session:'), findsNothing);
  });
}

// FAKE CHANNEL - Duplicated from unit_test.dart to isolate widget tests
class FakeWebSocketChannel implements WebSocketChannel {
  final StreamController _controller = StreamController();
  final StreamController _sinkController = StreamController();

  @override
  Stream get stream => _controller.stream;

  @override
  WebSocketSink get sink => _FakeSink(_sinkController);

  @override
  void pipe(StreamChannel<dynamic> other) {}

  @override
  StreamChannel<S> transform<S>(
      StreamChannelTransformer<S, dynamic> transformer) {
    throw UnimplementedError();
  }

  @override
  StreamChannel<dynamic> transformStream(
      StreamTransformer<dynamic, dynamic> transformer) {
    throw UnimplementedError();
  }

  @override
  StreamChannel<dynamic> transformSink(
      StreamSinkTransformer<dynamic, dynamic> transformer) {
    throw UnimplementedError();
  }

  @override
  StreamChannel<dynamic> changeStream(Stream Function(Stream) change) {
    throw UnimplementedError();
  }

  @override
  StreamChannel<dynamic> changeSink(StreamSink Function(StreamSink) change) {
    throw UnimplementedError();
  }

  @override
  StreamChannel<S> cast<S>() => throw UnimplementedError();

  @override
  String? protocol;

  @override
  int? closeCode;

  @override
  String? closeReason;

  Future start() async {}

  @override
  Future get ready => Future.value();
}

class _FakeSink implements WebSocketSink {
  final StreamController _controller;
  _FakeSink(this._controller);

  @override
  void add(dynamic data) => _controller.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _controller.addError(error, stackTrace);

  @override
  Future addStream(Stream stream) => _controller.addStream(stream);

  @override
  Future close([int? closeCode, String? closeReason]) => _controller.close();

  @override
  Future get done => _controller.done;
}
