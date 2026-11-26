import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

void main() {
  testWidgets(
    'mounted direct builder follows reactive updates and unmounts cleanly',
    (tester) async {
      final handle = 1.lx;
      await tester.pumpWidget(
        MaterialApp(home: LBuilder(handle, (value) => Text('$value'))),
      );
      expect(find.text('1'), findsOneWidget);
      expect(handle.hasListener, isTrue);

      handle.value = 2;
      await tester.pump();
      expect(find.text('2'), findsOneWidget);

      handle.value = 3;
      await tester.pump();
      expect(find.text('3'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(handle.hasListener, isFalse);
      await handle.close();
    },
  );

  testWidgets('status builder gets retained null during refresh and failure', (
    tester,
  ) async {
    final next = Completer<String?>();
    final handle = LxFuture<String?>(Future.value(null));
    await handle.wait;
    await tester.pumpWidget(
      MaterialApp(
        home: LStatusBuilder<String?>(
          handle,
          onSuccess: (value) => Text('success:$value'),
          onWaiting: (status) =>
              Text('waiting:${status.hasLastValue}:${status.lastValue}'),
          onError: (status) => Text(
            'error:${status.hasLastValue}:${status.lastValue}:${status.error}',
          ),
        ),
      ),
    );
    expect(find.text('success:null'), findsOneWidget);

    handle.restart(next.future);
    await tester.pump();
    expect(find.text('waiting:true:null'), findsOneWidget);

    final failed = expectLater(handle.wait, throwsStateError);
    next.completeError(StateError('offline'));
    await failed;
    await tester.pump();
    expect(find.textContaining('error:true:null'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await handle.close();
  });

  testWidgets('query switch cannot render an obsolete completion', (
    tester,
  ) async {
    final a = Completer<int>();
    final b = Completer<int>();
    final futures = {
      'a': LxFuture<int>(a.future),
      'b': LxFuture<int>(b.future),
    };
    final selected = 'a'.lx;
    await tester.pumpWidget(
      MaterialApp(
        home: LWatch(
          () => LStatusBuilder<int>(
            futures[selected.value]!,
            onSuccess: (value) => Text('$value'),
            onWaiting: (_) => const Text('waiting'),
          ),
        ),
      ),
    );
    selected.value = 'b';
    await tester.pump();
    b.complete(2);
    await futures['b']!.wait;
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
    a.complete(1);
    await futures['a']!.wait;
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await selected.close();
    for (final item in futures.values) {
      await item.close();
    }
  });
}
