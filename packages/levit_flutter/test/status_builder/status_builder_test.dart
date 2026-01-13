import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

void main() {
  setUp(() {
    Levit.reset(force: true);
  });

  group('LStatusBuilder with LxFuture', () {
    testWidgets('shows waiting state', (tester) async {
      final completer = Completer<String>();
      final future = LxFuture(completer.future);

      await tester.pumpWidget(
        MaterialApp(
          home: LStatusBuilder<String>(
            source: future,
            onSuccess: (data) => Text('Success: $data'),
            onWaiting: () => const Text('Loading'),
          ),
        ),
      );

      expect(find.text('Loading'), findsOneWidget);

      completer.complete('done');
      await tester.pumpAndSettle();

      expect(find.text('Success: done'), findsOneWidget);

      future.close();
    });

    testWidgets('shows error state', (tester) async {
      final completer = Completer<String>();
      final future = LxFuture(completer.future);

      await tester.pumpWidget(
        MaterialApp(
          home: LStatusBuilder<String>(
            source: future,
            onSuccess: (data) => Text('Success: $data'),
            onError: (err, stack) => Text('Error: $err'),
          ),
        ),
      );

      completer.completeError('Oops');
      await tester.pumpAndSettle();

      expect(find.text('Error: Oops'), findsOneWidget);

      future.close();
    });

    testWidgets('uses idle callback when idle', (tester) async {
      final future = LxFuture<String>.idle();

      await tester.pumpWidget(
        MaterialApp(
          home: LStatusBuilder<String>(
            source: future,
            onSuccess: (data) => Text('Success: $data'),
            onIdle: () => const Text('Idle'),
            onWaiting: () => const Text('Waiting'),
          ),
        ),
      );

      expect(find.text('Idle'), findsOneWidget);

      future.close();
    });

    testWidgets('default error widget when onError not provided',
        (tester) async {
      final completer = Completer<String>();
      final future = LxFuture(completer.future);

      await tester.pumpWidget(
        MaterialApp(
          home: LStatusBuilder<String>(
            source: future,
            onSuccess: (data) => Text('Success: $data'),
          ),
        ),
      );

      completer.completeError('Test error');
      await tester.pumpAndSettle();

      expect(find.textContaining('Error:'), findsOneWidget);

      future.close();
    });

    testWidgets('shows onWaiting as fallback when idle and onIdle is null',
        (tester) async {
      final future = LxFuture<String>.idle();

      await tester.pumpWidget(
        MaterialApp(
          home: LStatusBuilder<String>(
            source: future,
            onSuccess: (data) => Text('Success: $data'),
            onWaiting: () => const Text('Waiting Fallback'),
          ),
        ),
      );

      expect(find.text('Waiting Fallback'), findsOneWidget);
    });
  });

  group('LStatusBuilder.future', () {
    testWidgets('creates and disposes LxFuture automatically', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LStatusBuilder<int>.future(
            future: () async => 42,
            onSuccess: (data) => Text('Value: $data'),
            onWaiting: () => const Text('Loading'),
          ),
        ),
      );

      expect(find.text('Loading'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Value: 42'), findsOneWidget);
    });

    testWidgets('handles errors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LStatusBuilder<int>.future(
            future: () async => throw 'Failed',
            onSuccess: (data) => Text('Value: $data'),
            onError: (err, stack) => Text('Error: $err'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Error: Failed'), findsOneWidget);
    });

    testWidgets('shows default error widget when no onError', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LStatusBuilder<String>.future(
            future: () => Future.error('Boom'),
            onSuccess: (data) => Text('Success: $data'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Error:'), findsOneWidget);
    });
  });

  group('LStatusBuilder with LxStream', () {
    testWidgets('shows waiting then success state', (tester) async {
      final controller = StreamController<int>();
      final stream = LxStream(controller.stream);

      await tester.pumpWidget(
        MaterialApp(
          home: LStatusBuilder<int>(
            source: stream,
            onSuccess: (data) => Text('Value: $data'),
            onWaiting: () => const Text('Waiting'),
          ),
        ),
      );

      expect(find.text('Waiting'), findsOneWidget);

      controller.add(42);
      await tester.pump(const Duration(milliseconds: 10));

      expect(find.text('Value: 42'), findsOneWidget);

      controller.close();
      stream.close();
    });

    testWidgets('handles LxIdle status', (tester) async {
      final stream = LxStream<int>.idle();

      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: LStatusBuilder<int>(
          source: stream,
          onSuccess: (val) => Text('val: $val'),
          onIdle: () => const Text('Idle'),
        ),
      ));

      expect(find.text('Idle'), findsOneWidget);

      stream.close();
    });

    testWidgets('idle falls back to waiting then shrink', (tester) async {
      final stream = LxStream<int>.idle();

      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: LStatusBuilder<int>(
          source: stream,
          onSuccess: (val) => Text('val: $val'),
          onWaiting: () => const Text('Waiting fallback'),
        ),
      ));

      expect(find.text('Waiting fallback'), findsOneWidget);

      stream.close();
    });
  });

  group('LStatusBuilder.stream', () {
    testWidgets('creates and disposes LxStream automatically', (tester) async {
      final controller = StreamController<int>();

      await tester.pumpWidget(
        MaterialApp(
          home: LStatusBuilder<int>.stream(
            stream: controller.stream,
            onSuccess: (data) => Text('Value: $data'),
            onWaiting: () => const Text('Waiting'),
          ),
        ),
      );

      expect(find.text('Waiting'), findsOneWidget);

      controller.add(10);
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.text('Value: 10'), findsOneWidget);

      controller.close();
    });
  });

  group('LStatusBuilder error handling', () {
    testWidgets('uses default error widget when onError is null (future)',
        (tester) async {
      final future = LxFuture<int>(Future.error('oops'));
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: LStatusBuilder<int>(
          source: future,
          onSuccess: (_) => Text('success'),
        ),
      ));

      await tester.pump();
      expect(find.text('Error: oops'), findsOneWidget);
    });

    testWidgets('uses default error widget when onError is null (stream)',
        (tester) async {
      final controller = StreamController<int>();
      final stream = LxStream<int>(controller.stream, initial: 0);

      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: LStatusBuilder<int>(
          source: stream,
          onSuccess: (val) => Text('val: $val'),
        ),
      ));

      expect(find.text('val: 0'), findsOneWidget);

      await tester.runAsync(() async {
        controller.addError('stream error');
        await Future.delayed(const Duration(milliseconds: 20));
      });

      await tester.pump();

      expect(find.text('Error: stream error'), findsOneWidget);

      stream.close();
      await controller.close();
      await tester.pumpWidget(Container());
    });
    testWidgets('updates when source changes', (tester) async {
      final source1 = LxFuture<int>.idle();
      final source2 = LxFuture<int>(Future.value(42));

      await tester.pumpWidget(
        MaterialApp(
          home: LStatusBuilder<int>(
            source: source1,
            onSuccess: (data) => Text('Value: $data'),
            onIdle: () => const Text('Idle'),
          ),
        ),
      );

      expect(find.text('Idle'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: LStatusBuilder<int>(
            source: source2,
            onSuccess: (data) => Text('Value: $data'),
            onIdle: () => const Text('Idle'),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Value: 42'), findsOneWidget);
    });
  });
}
