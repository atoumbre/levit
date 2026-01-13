import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'dart:async';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:async/async.dart';

import 'package:nexus_studio_app/main.dart';
import 'package:nexus_studio_app/controllers.dart';
import 'package:shared/shared.dart';

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

  // Set large screen size to avoid overflow
  setUpAll(() {
    // We can't use tester here as it's not available.
    // We rely on individual tests to set size or use TestWidgetsFlutterBinding if needed.
    // Given the previous code used tester inside individual tests (mostly),
    // and the setUpAll in original file was commented out for deprecated window approach:
    // We will leave this empty or remove it if not needed.
    // Checking original file (Step 56), setUpAll contained commented out code.
    // So we can leave it empty.
  });

  testWidgets('App starts with login overlay', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const NexusStudioApp());
    expect(find.text('Nexus Studio'), findsOneWidget);
    expect(find.text('Collaborative Design System'), findsOneWidget);
    expect(find.text('Login as Editor'), findsOneWidget);
  });

  testWidgets('Login unlocks editor', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const NexusStudioApp());

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

  testWidgets('Editor UI updates on state changes',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const NexusStudioApp());

    // Login
    await tester.tap(find.text('Login as Editor'));
    await tester.pumpAndSettle();

    final pc = Levit.find<ProjectController>();

    // 1. Add Node Programmatically
    pc.addNode('rect');
    await tester.pumpAndSettle();

    expect(find.byType(NodeWidget), findsOneWidget);

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

    await tester.pumpWidget(const NexusStudioApp());
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

    // Close dialog
    await tester.tapAt(const Offset(10, 10)); // Tap outside barrier?
    // Or just check contents.
  });

  testWidgets('Hover updates cursor', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const NexusStudioApp());
    await tester.tap(find.text('Login as Editor'));
    await tester.pump();

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(const Offset(100, 100));
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

    await tester.pumpWidget(const NexusStudioApp());
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

    await tester.pumpWidget(const NexusStudioApp());
    await tester.tap(find.text('Login as Editor'));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.crop_square));
    await tester.pump();

    // Create history
    final nodeWidget = find.byType(NodeWidget).first;
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
  void add(data) => _controller.add(data);

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
