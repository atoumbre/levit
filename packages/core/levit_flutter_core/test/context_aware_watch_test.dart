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

  testWidgets('LWatch runs with context when middleware is present',
      (tester) async {
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

  testWidgets('LWatchVar runs with context when middleware is present',
      (tester) async {
    final count = 0.lx.named('consumer_count');

    await tester.pumpWidget(
      LWatchVar<LxNum<int>>(
        count,
        (c) => Text('${c.value}', textDirection: TextDirection.ltr),
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
      LWatchVar<LxNum<int>>(
        count1,
        (c) => Text('${c.value}', textDirection: TextDirection.ltr),
      ),
    );
    expect(find.text('0'), findsOneWidget);

    // Swap reactive by rebuilding widget with new reactive
    await tester.pumpWidget(
      LWatchVar<LxNum<int>>(
        count2,
        (c) => Text('${c.value}', textDirection: TextDirection.ltr),
      ),
    );
    expect(find.text('100'), findsOneWidget);
  });
}
