import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

class TestController extends LevitController {
  final value = 'Hello'.lx;
}

void main() {
  testWidgets('LScope.capture provides page scope to dialogs', (tester) async {
    const buttonKey = Key('open_dialog');

    await tester.pumpWidget(
      MaterialApp(
        home: LScope.put(
          () => TestController(),
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: const Center(child: Text('Page')),
                floatingActionButton: FloatingActionButton(
                  key: buttonKey,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => LScope.capture(
                        context,
                        child: Builder(
                          builder: (dialogContext) {
                            try {
                              final controller =
                                  dialogContext.levit.find<TestController>();
                              return Text('Found: ${controller.value()}');
                            } catch (e) {
                              return Text('Error: Exception');
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(buttonKey));
    await tester.pumpAndSettle();

    expect(find.text('Found: Hello'), findsOneWidget);
  });

  testWidgets('LScope.capture preserves access for nested dialog widgets',
      (tester) async {
    const buttonKey = Key('open_dialog');

    await tester.pumpWidget(
      MaterialApp(
        home: LScope.put(
          () => TestController(),
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: const Center(child: Text('Page')),
                floatingActionButton: FloatingActionButton(
                  key: buttonKey,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => LScope.capture(
                        context,
                        child: const _DeepWidget(),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(buttonKey));
    await tester.pumpAndSettle();

    expect(find.text('Found: Hello'), findsOneWidget);
  });

  testWidgets(
      'runBridged alone still does not transfer scope to nested widgets',
      (tester) async {
    const buttonKey = Key('open_dialog');

    await tester.pumpWidget(
      MaterialApp(
        home: LScope.put(
          () => TestController(),
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: const Center(child: Text('Page')),
                floatingActionButton: FloatingActionButton(
                  key: buttonKey,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) {
                        return LScope.runBridged(context, () {
                          return const _DeepWidget();
                        });
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(buttonKey));
    await tester.pumpAndSettle();

    expect(find.text('Error: Exception'), findsOneWidget);
  });
}

class _DeepWidget extends StatelessWidget {
  const _DeepWidget();

  @override
  Widget build(BuildContext context) {
    try {
      final controller = context.levit.find<TestController>();
      return Text('Found: ${controller.value()}');
    } catch (e) {
      return Text('Error: Exception');
    }
  }
}
