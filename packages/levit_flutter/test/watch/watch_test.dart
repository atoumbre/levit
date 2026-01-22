import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

void main() {
  setUp(() {
    Levit.reset(force: true);
  });

  group('LWatch', () {
    testWidgets('rebuilds when Lx value changes', (tester) async {
      final count = 0.lx;

      await tester.pumpWidget(
        MaterialApp(
          home: LWatch(() => Text('Count: ${count.value}')),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      count.value = 1;
      await tester.pump();

      expect(find.text('Count: 1'), findsOneWidget);
    });

    testWidgets('handles multiple Lx values', (tester) async {
      final a = 1.lx;
      final b = 2.lx;

      await tester.pumpWidget(
        MaterialApp(
          home: LWatch(() => Text('Sum: ${a.value + b.value}')),
        ),
      );

      expect(find.text('Sum: 3'), findsOneWidget);

      a.value = 10;
      await tester.pumpAndSettle();
      expect(find.text('Sum: 12'), findsOneWidget);

      b.value = 20;
      await tester.pumpAndSettle();
      expect(find.text('Sum: 30'), findsOneWidget);
    });

    testWidgets('disposes subscriptions on unmount', (tester) async {
      final count = 0.lx;
      final showWatch = true.lx;

      await tester.pumpWidget(
        MaterialApp(
          home: LWatch(() => showWatch.value
              ? LWatch(() => Text('Count: ${count.value}'))
              : const Text('Hidden')),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      showWatch.value = false;
      await tester.pump();

      expect(find.text('Hidden'), findsOneWidget);

      count.value = 100;
      await tester.pump();

      expect(find.text('Hidden'), findsOneWidget);
    });

    testWidgets('builds correctly with debugLabel set', (tester) async {
      final count = 0.lx;

      await tester.pumpWidget(
        MaterialApp(
          home: LWatch(
            () => Text('Count: ${count.value}'),
            debugLabel: 'test-counter',
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      count.value = 1;
      await tester.pump();

      expect(find.text('Count: 1'), findsOneWidget);
    });
  });

  group('LConsumer', () {
    testWidgets('resubscribes when Lx changes', (tester) async {
      final value1 = 'First'.lx;
      final value2 = 'Second'.lx;
      final useFirst = ValueNotifier(true);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: useFirst,
            builder: (_, first, __) => LConsumer<LxVar<String>>(
              first ? value1 : value2,
              (value) => Text('Value: ${value.value}'),
            ),
          ),
        ),
      );

      expect(find.text('Value: First'), findsOneWidget);

      useFirst.value = false;
      await tester.pumpAndSettle();

      expect(find.text('Value: Second'), findsOneWidget);

      value2.value = 'Updated';
      await tester.pumpAndSettle();

      expect(find.text('Value: Updated'), findsOneWidget);
    });
  });

  group('LWatch coverage', () {
    testWidgets('removes unused dependencies', (tester) async {
      final rxA = 0.lx;
      final rxB = 0.lx;
      bool useB = true;

      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: LWatch(() {
          final a = rxA.value;
          if (useB) {
            final b = rxB.value;
            return Text('$a-$b');
          }
          return Text('$a');
        }),
      ));

      expect(find.text('0-0'), findsOneWidget);

      rxB.value = 1;
      await tester.pump();
      expect(find.text('0-1'), findsOneWidget);

      useB = false;
      rxA.value = 1;
      await tester.pump();
      expect(find.text('1'), findsOneWidget);

      rxB.value = 2;
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('cancels raw stream subscriptions when dependencies change',
        (tester) async {
      final controller = StreamController<int>.broadcast();
      bool useStream = true;
      final trigger = 0.lx;

      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: LWatch(() {
          final _ = trigger.value;
          if (useStream) {
            Lx.proxy?.addStream(controller.stream);
            return const Text('Stream');
          }
          return const Text('Hidden');
        }),
      ));

      expect(controller.hasListener, isTrue);

      useStream = false;
      trigger.value++;
      await tester.pump();

      expect(find.text('Hidden'), findsOneWidget);
      expect(controller.hasListener, isFalse);

      await controller.close();
    });
  });
}
