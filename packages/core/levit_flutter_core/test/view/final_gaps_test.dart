import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

class MockMiddleware extends LevitReactiveMiddleware {
  @override
  void Function(LxReactive, LxListenerContext?)? get startedListening =>
      (_, __) {};
  @override
  void Function(LxReactive, LxListenerContext?)? get stoppedListening =>
      (_, __) {};
  @override
  void Function(LxReactive, List<LxReactive>)? get onGraphChange => (_, __) {};
}

void main() {
  group('levit_flutter_core Final Gaps', () {
    setUpAll(() {
      LevitReactiveMiddleware.add(MockMiddleware());
    });

    testWidgets('LAsyncView UnimplementedError coverage', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LAsyncView<int>(
            resolver: (context) => Future.value(1),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isA<UnimplementedError>());
    });

    testWidgets('LAsyncView default error coverage', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LAsyncView<int>(
            resolver: (context) => Future.error('fail'),
            builder: (context, val) => Text('$val'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Error: fail'), findsOneWidget);
    });

    testWidgets('LWatchStatus context and lifecycle coverage', (tester) async {
      final x = LxVar<LxStatus<int>>(LxIdle());

      await tester.pumpWidget(
        MaterialApp(
          home: LWatchStatus<int>(
            x,
            onSuccess: (val) => Text('Val: $val'),
          ),
        ),
      );

      // Hits mount context (383, 389-393 in watch.dart)

      x.value = LxSuccess(42);
      await tester.pump();
      expect(find.text('Val: 42'), findsOneWidget);

      // Trigger unmount context (376 in watch.dart)
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('LWatchStatus default error coverage', (tester) async {
      final x = LxVar<LxStatus<int>>(LxError('err', StackTrace.empty));
      await tester.pumpWidget(
        MaterialApp(
          home: LWatchStatus<int>(x, onSuccess: (v) => Text('$v')),
        ),
      );
      expect(find.textContaining('Error: err'), findsOneWidget);
    });

    testWidgets('LWatch addReactive coverage', (tester) async {
      final x = 0.lx;
      await tester.pumpWidget(
        MaterialApp(
          home: LWatch(() {
            // Accessing x.value will now call addReactive on LWatch proxy (60 in watch.dart)
            // because onGraphChange is provided in middleware.
            return Text('Val: ${x.value}');
          }),
        ),
      );
    });
  });
}
