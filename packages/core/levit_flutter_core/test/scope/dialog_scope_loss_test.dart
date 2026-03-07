import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

class TestController extends LevitController {
  final value = 'Hello'.lx;
}

void main() {
  testWidgets('Dialog loses access to page LScope', (tester) async {
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
                      builder: (dialogContext) {
                        // return Builder(builder: (c) {
                        // Crucial: we must call runBridged INSIDE the builder function!
                        // If we wrap the `Builder` itself, the zone executes only while instantiating
                        // the widget, not when Flutter actually calls the builder callback.
                        return LScope.runBridged(context, () {
                          try {
                            final controller =
                                dialogContext.levit.find<TestController>();
                            return Text('Found: ${controller.value()}');
                          } catch (e) {
                            return Text('Error: Exception');
                          }
                          // });
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

    // Verify the dialog successfully found the controller
    expect(find.text('Found: Hello'), findsOneWidget);
  });

  testWidgets('runBridged fails for nested widgets in dialogs', (tester) async {
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
                      builder: (dialogContext) {
                        // return Builder(builder: (c) {
                        // We use runBridged here...
                        return LScope.runBridged(context, () {
                          // But we return a separate widget that resolves DI in its OWN build.
                          return _DeepWidget();
                        });
                        // });
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

    // The _DeepWidget should fail because its build happens outside the runBridged zone
    expect(find.text('Error: Exception'), findsOneWidget);
  });
}

class _DeepWidget extends StatelessWidget {
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
