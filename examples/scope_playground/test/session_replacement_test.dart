import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_testing.dart';
import 'package:levit_example_scope_playground/session_replacement.dart';

void main() {
  testWidgets(
    'rapid replacement drains old session and coalesces intermediate requests',
    (tester) async {
      final lifecycle = LevitScopeLifecycleController();
      final events = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: SessionReplacementPage(lifecycle: lifecycle, events: events),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Session 1'), findsOneWidget);
      await tester.tap(find.text('Next session'));
      await tester.pump();
      expect(find.text('Waiting for session cleanup'), findsOneWidget);
      await tester.tap(find.text('Next session'));
      await tester.pump();
      expect(events, ['opened:Session 1', 'closing:Session 1']);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Session 3'), findsOneWidget);
      expect(events, [
        'opened:Session 1',
        'closing:Session 1',
        'closed:Session 1',
        'opened:Session 3',
      ]);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      await lifecycle
          .close(); // observe cleanup errors, not just the completion signal
      expect(events.last, 'closed:Session 3');
    },
  );

  testWidgets(
    'typed widget override is local and receiving scope owns its value',
    (tester) async {
      final test = LevitTestScope();
      addTearDown(test.close);
      final parent = sessionLabel.findIn(test.scope);
      final lifecycle = LevitScopeLifecycleController();
      LxVar<String>? overridden;
      await test.run(
        () => tester.pumpWidget(
          MaterialApp(
            home: LScope(
              lifecycle: lifecycle,
              configure: (scope) {
                expect(sessionLabel.findIn(scope), same(parent));
                scope.applyOverrides([
                  sessionLabel.overrideWith((ref) {
                    final value = ref.own('Test session'.lx);
                    overridden = value;
                    return value;
                  }),
                ]);
              },
              child: const SessionLabel(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Test session'), findsOneWidget);
      expect(parent.value, 'Guest');
      overridden!.value = 'Changed';
      await tester.pump();
      expect(find.text('Changed'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await lifecycle.close();
      expect(overridden!.isDisposed, isTrue);
      expect(parent.isDisposed, isFalse);
    },
  );
}
