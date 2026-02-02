import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

void main() {
  setUp(() {
    Levit.reset(force: true);
  });

  group('LWatchStatus Tests', () {
    testWidgets('renders success state', (tester) async {
      final rx = (LxSuccess<String>('Hello')).lx;

      await tester.pumpWidget(
        MaterialApp(
          home: LStatusBuilder<String>(
            rx,
            onSuccess: (data) => Text('Data: $data'),
          ),
        ),
      );

      expect(find.text('Data: Hello'), findsOneWidget);
    });

    testWidgets('renders waiting state then success', (tester) async {
      final rx = (LxWaiting<String>() as LxStatus<String>).lx;

      await tester.pumpWidget(
        MaterialApp(
          home: LStatusBuilder<String>(
            rx,
            onSuccess: (data) => Text('Data: $data'),
            onWaiting: () => const Text('Loading...'),
          ),
        ),
      );

      expect(find.text('Loading...'), findsOneWidget);

      rx.value = LxSuccess<String>('Done');
      await tester.pump();

      expect(find.text('Data: Done'), findsOneWidget);
    });

    testWidgets('renders error state', (tester) async {
      final rx = (LxError<String>('Oops', StackTrace.current)).lx;

      await tester.pumpWidget(
        MaterialApp(
          home: LStatusBuilder<String>(
            rx,
            onSuccess: (data) => Text('Data: $data'),
            onError: (err, stack) => Text('Error: $err'),
          ),
        ),
      );

      expect(find.text('Error: Oops'), findsOneWidget);
    });

    testWidgets('renders idle state and falls back to waiting', (tester) async {
      final rx = (LxIdle<String>()).lx;

      await tester.pumpWidget(
        MaterialApp(
          home: LStatusBuilder<String>(
            rx,
            onSuccess: (data) => Text('Data: $data'),
            onWaiting: () => const Text('Waiting...'),
          ),
        ),
      );

      expect(find.text('Waiting...'), findsOneWidget);
    });

    testWidgets('switches source reactively', (tester) async {
      final rx1 = (LxSuccess<String>('One')).lx;
      final rx2 = (LxSuccess<String>('Two')).lx;

      await tester.pumpWidget(
        MaterialApp(
          home: LStatusBuilder<String>(
            rx1,
            onSuccess: (data) => Text('Data: $data'),
          ),
        ),
      );

      expect(find.text('Data: One'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: LStatusBuilder<String>(
            rx2,
            onSuccess: (data) => Text('Data: $data'),
          ),
        ),
      );

      expect(find.text('Data: Two'), findsOneWidget);
    });

    testWidgets('disposes listener on unmount', (tester) async {
      final rx = (LxSuccess<String>('Init')).lx;

      await tester.pumpWidget(
        MaterialApp(
          home: LStatusBuilder<String>(
            rx,
            onSuccess: (data) => Text('Data: $data'),
          ),
        ),
      );

      expect(rx.hasListener, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());

      expect(rx.hasListener, isFalse);
    });
  });
}
