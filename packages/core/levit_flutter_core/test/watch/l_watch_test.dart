import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

void main() {
  group('Reactive widget subscriptions and rebuilds', () {
    testWidgets('LWatch rebuilds for implicit reactive reads and unmounts', (
      tester,
    ) async {
      final v = 0.lx;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LWatch(() {
            return Text('Val: ${v.value}');
          }),
        ),
      );

      expect(find.text('Val: 0'), findsOneWidget);
      v.value = 1;
      await tester.pump();
      expect(find.text('Val: 1'), findsOneWidget);

      // Dispose to hit unmount/cleanupAll (Lines 203-206)
      await tester.pumpWidget(Container());
    });

    testWidgets('LBuilder switches to a replacement reactive source', (
      tester,
    ) async {
      final v1 = 0.lx;
      final v2 = 10.lx;

      Widget buildWatch(LxVar<int> v) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: LBuilder<int>(v, (x) => Text('Val: ${x}')),
        );
      }

      await tester.pumpWidget(buildWatch(v1));
      expect(find.text('Val: 0'), findsOneWidget);

      // Update with different reactive (Line 252)
      await tester.pumpWidget(buildWatch(v2));
      expect(find.text('Val: 10'), findsOneWidget);

      // Dispose (Line 271)
      await tester.pumpWidget(Container());
    });

    testWidgets(
      'LStatusBuilder renders status transitions and a replacement source',
      (tester) async {
        final status = LxVar<LxStatus<String>>(LxWaiting());

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: LStatusBuilder<String>(
              status,
              onSuccess: (data) => Text('Success: $data'),
              onWaiting: (status) => const Text('Waiting'),
              onError: (status) => Text('Error: ${status.error}'),
            ),
          ),
        );

        expect(find.text('Waiting'), findsOneWidget);

        status.value = LxSuccess('Done');
        await tester.pump();
        expect(find.text('Success: Done'), findsOneWidget);

        status.value = LxError('Fail', null);
        await tester.pump();
        expect(find.text('Error: Fail'), findsOneWidget);

        // Update logic (Line 355)
        final status2 = LxVar<LxStatus<String>>(LxSuccess('New'));
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: LStatusBuilder<String>(
              status2,
              onSuccess: (data) => Text('Success: $data'),
            ),
          ),
        );
        expect(find.text('Success: New'), findsOneWidget);

        // Dispose (Line 385)
        await tester.pumpWidget(Container());
      },
    );
  });
}
