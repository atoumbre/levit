import 'package:dev_tool_server/dev_tool_server.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dev_tool/ui/panels/variable_list_panel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VariableListPanel Tests', () {
    late AppSession session;

    setUp(() {
      session = AppSession(sessionId: 'test-session');
      // Populate with dummy data
      session.state.variables[1] = ReactiveModel(
        id: 1,
        name: 'varA',
        ownerId: '1:CtrlA',
      )..value = 'ValueA';

      session.state.variables[2] = ReactiveModel(
        id: 2,
        name: 'varB',
        ownerId: '1:CtrlB',
      )..value = 'ValueB';

      session.state.variables[3] = ReactiveModel(
        id: 3,
        name: 'varC',
        ownerId: '1:CtrlA',
      )..value = 'ValueC';
    });

    testWidgets('Displays all variables when filter is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VariableListPanel(
              session: session,
              filterControllerKey: null,
            ),
          ),
        ),
      );

      expect(find.text('varA'), findsOneWidget);
      expect(find.text('varB'), findsOneWidget);
      expect(find.text('varC'), findsOneWidget);
      expect(find.text('All Reactive Variables'), findsOneWidget);
    });

    testWidgets('Filters variables by controller key', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VariableListPanel(
              session: session,
              filterControllerKey: '1:CtrlA',
            ),
          ),
        ),
      );

      expect(find.text('varA'), findsOneWidget); // Owned by CtrlA
      expect(find.text('varC'), findsOneWidget); // Owned by CtrlA
      expect(find.text('varB'), findsNothing); // Owned by CtrlB
      expect(find.text('Variables in 1:CtrlA'), findsOneWidget);
    });

    testWidgets('Updates filter dynamically', (tester) async {
      // We can't easily update prop in stateless widget without re-pumping.
      // Test re-pump behavior.

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VariableListPanel(
              session: session,
              filterControllerKey: '1:CtrlA',
            ),
          ),
        ),
      );
      expect(find.text('varA'), findsOneWidget);
      expect(find.text('varB'), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VariableListPanel(
              session: session,
              filterControllerKey: '1:CtrlB',
            ),
          ),
        ),
      );

      expect(find.text('varA'), findsNothing);
      expect(find.text('varB'), findsOneWidget);
      expect(find.text('Variables in 1:CtrlB'), findsOneWidget);
    });

    testWidgets('Displays empty state when no matches', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VariableListPanel(
              session: session,
              filterControllerKey: '1:NonExistent',
            ),
          ),
        ),
      );

      expect(find.text('varA'), findsNothing);
      expect(find.text('varB'), findsNothing);
      // Assuming the panel shows "No variables found" or similar
      expect(find.text('No variables found'), findsOneWidget);
    });
  });
}
