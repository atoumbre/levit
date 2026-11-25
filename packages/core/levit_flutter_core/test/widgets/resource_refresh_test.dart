import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

void main() {
  testWidgets('mounted direct builder follows the same handle across refresh', (
    tester,
  ) async {
    var generation = 0;
    final resource = LxResource<int, LxVar<int>>(() => (++generation).lx);
    final handle = resource;
    handle.value;
    await tester.pumpWidget(
      MaterialApp(home: LBuilder(handle, (value) => Text('$value'))),
    );
    expect(find.text('1'), findsOneWidget);
    expect(handle.isActive, isTrue);
    await resource.refresh();
    await tester.pump();
    expect(find.text('2'), findsOneWidget);

    handle.producer.value = 3;
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(handle.isActive, isFalse);
    await resource.close();
  });

  testWidgets('status builder gets retained null during refresh and failure', (
    tester,
  ) async {
    final next = Completer<String?>();
    var builds = 0;
    final resource = LxResource<LxStatus<String?>, LxFuture<String?>>(
      () => ++builds == 1
          ? LxFuture(Future.value(null))
          : LxFuture(next.future, previous: const LxSuccess<String?>(null)),
    );
    final handle = resource;
    handle.value;
    await handle.producer.wait;
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
    await resource.refresh();
    await tester.pump();
    expect(find.text('waiting:true:null'), findsOneWidget);
    final failed = expectLater(handle.producer.wait, throwsStateError);
    next.completeError(StateError('offline'));
    await failed;
    await tester.pump();
    expect(find.textContaining('error:true:null'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await resource.close();
  });

  testWidgets('query switch cannot render an obsolete completion', (
    tester,
  ) async {
    final a = Completer<int>();
    final b = Completer<int>();
    final resources = {
      'a': LxResource<LxStatus<int>, LxFuture<int>>(() => LxFuture(a.future)),
      'b': LxResource<LxStatus<int>, LxFuture<int>>(() => LxFuture(b.future)),
    };
    final selected = 'a'.lx;
    await tester.pumpWidget(
      MaterialApp(
        home: LWatch(
          () => LStatusBuilder<int>(
            resources[selected.value]!,
            onSuccess: (value) => Text('$value'),
            onWaiting: (_) => const Text('waiting'),
          ),
        ),
      ),
    );
    selected.value = 'b';
    await tester.pump();
    b.complete(2);
    await resources['b']!.producer.wait;
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
    a.complete(1);
    await resources['a']!.producer.wait;
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await selected.close();
    for (final item in resources.values) {
      await item.close();
    }
  });
}
