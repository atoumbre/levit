import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

class _PageController extends LevitController {
  final value = 'Hello'.lx;
}

void main() {
  testWidgets('showLevitDialog preserves page scope for find', (tester) async {
    const buttonKey = Key('open_dialog');

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: LScope.put(
          () => _PageController(),
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: const Center(child: Text('Page')),
                floatingActionButton: FloatingActionButton(
                  key: buttonKey,
                  onPressed: () {
                    showLevitDialog(
                      context: context,
                      builder: (dialogContext) {
                        try {
                          final controller =
                              dialogContext.levit.find<_PageController>();
                          return AlertDialog(
                            content: Text('Found: ${controller.value()}'),
                          );
                        } catch (_) {
                          return const AlertDialog(
                            content: Text('Error: Exception'),
                          );
                        }
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

    expect(find.text('Found: Hello'), findsOneWidget);
  });

  testWidgets('showLevitModalBottomSheet preserves page scope for find',
      (tester) async {
    const buttonKey = Key('open_sheet');

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: LScope.put(
          () => _PageController(),
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: const Center(child: Text('Page')),
                floatingActionButton: FloatingActionButton(
                  key: buttonKey,
                  onPressed: () {
                    showLevitModalBottomSheet(
                      context: context,
                      builder: (sheetContext) {
                        try {
                          final controller =
                              sheetContext.levit.find<_PageController>();
                          return SizedBox(
                            height: 120,
                            child: Center(
                              child: Text('Found: ${controller.value()}'),
                            ),
                          );
                        } catch (_) {
                          return const SizedBox(
                            height: 120,
                            child: Center(child: Text('Error: Exception')),
                          );
                        }
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

    expect(find.text('Found: Hello'), findsOneWidget);
  });
}
