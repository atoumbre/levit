import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

// A middleware that has listener hooks, thus forcing 'hasListenerMiddlewares' to true
class ListenerMiddleware extends LevitReactiveMiddleware {
  @override
  void Function(LxReactive reactive, LxListenerContext? context)?
  get startedListening => (rx, ctx) {};

  @override
  void Function(LxReactive reactive, LxListenerContext? context)?
  get stoppedListening => (rx, ctx) {};
}

void main() {
  setUp(() {
    Lx.addMiddleware(ListenerMiddleware());
  });

  tearDown(() {
    Lx.clearMiddlewares();
  });

  testWidgets('LWatch runs with context when middleware is present', (
    tester,
  ) async {
    final count = 0.lx.named('count');

    await tester.pumpWidget(
      LWatch(
        () => Text('${count.value}', textDirection: TextDirection.ltr),
        debugLabel: 'TestWatch',
      ),
    );

    expect(find.text('0'), findsOneWidget);

    count.value++;
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('LWatchVar runs with context when middleware is present', (
    tester,
  ) async {
    final count = 0.lx.named('consumer_count');

    await tester.pumpWidget(
      LBuilder<int>(
        count,
        (c) => Text('${c}', textDirection: TextDirection.ltr),
      ),
    );

    expect(find.text('0'), findsOneWidget);

    count.value = 10;
    await tester.pump();
    expect(find.text('10'), findsOneWidget);
  });

  testWidgets('LWatchVar updates widget properly with context', (tester) async {
    final count1 = 0.lx;
    final count2 = 100.lx;

    await tester.pumpWidget(
      LBuilder<int>(
        count1,
        (c) => Text('${c}', textDirection: TextDirection.ltr),
      ),
    );
    expect(find.text('0'), findsOneWidget);

    // Swap reactive by rebuilding widget with new reactive
    await tester.pumpWidget(
      LBuilder<int>(
        count2,
        (c) => Text('${c}', textDirection: TextDirection.ltr),
      ),
    );
    expect(find.text('100'), findsOneWidget);
  });

  testWidgets(
    'LWatch notifies listener middleware when dropping a dynamic dependency',
    (tester) async {
      final showSecond = true.lx.named('showSecond');
      final first = 1.lx.named('first');
      final second = 2.lx.named('second');
      final stopped = <String?>[];

      Lx.clearMiddlewares();
      Lx.addMiddleware(_RecordingListenerMiddleware(onStop: stopped.add));

      await tester.pumpWidget(
        LWatch(() {
          final total = showSecond.value
              ? first.value + second.value
              : first.value;
          return Text('$total', textDirection: TextDirection.ltr);
        }, debugLabel: 'DynamicWatch'),
      );
      expect(find.text('3'), findsOneWidget);

      showSecond.value = false;
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
      expect(stopped, contains('second'));
    },
  );

  testWidgets(
    'LSelectorBuilder skips rebuilds when selected value stays equal',
    (tester) async {
      final count = 1.lx;
      var builds = 0;

      await tester.pumpWidget(
        LSelectorBuilder<bool>(() => count.value.isEven, (isEven) {
          builds++;
          return Text('$isEven', textDirection: TextDirection.ltr);
        }),
      );
      expect(find.text('false'), findsOneWidget);
      expect(builds, 1);

      count.value = 3; // Still odd -> equal derived value
      await tester.pump();
      expect(builds, 1);

      count.value = 4; // Now even -> rebuilds once
      await tester.pump();
      expect(find.text('true'), findsOneWidget);
      expect(builds, 2);
    },
  );
}

class _RecordingListenerMiddleware extends LevitReactiveMiddleware {
  _RecordingListenerMiddleware({required this.onStop});
  final void Function(String? name) onStop;

  @override
  void Function(LxReactive reactive, LxListenerContext? context)?
  get startedListening => (rx, ctx) {};

  @override
  void Function(LxReactive reactive, LxListenerContext? context)?
  get stoppedListening =>
      (rx, ctx) => onStop(rx.name);
}
