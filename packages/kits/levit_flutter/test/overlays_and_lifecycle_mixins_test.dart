import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

class _LifecycleProbeController extends LevitController
    with LevitAppLifecycleMixin {
  int resumedCalls = 0;

  @override
  void onAppResumed() {
    resumedCalls++;
  }
}

void main() {
  testWidgets(
    'showLevitDialog keeps captured scope after launching widget unmounts',
    (tester) async {
      final showLauncher = true.lx;
      final rebuildDialog = 0.lx;

      await tester.pumpWidget(
        MaterialApp(
          home: LScope(
            dependencyFactory: (s) => s.put<String>(() => 'captured-value'),
            child: LWatch(() {
              if (!showLauncher.value) {
                return const Scaffold(body: Text('replaced'));
              }
              return Scaffold(
                body: Builder(
                  builder: (launcherContext) => ElevatedButton(
                    onPressed: () {
                      unawaited(
                        showLevitDialog<void>(
                          context: launcherContext,
                          builder: (dialogContext) => LWatch(() {
                            final tick = rebuildDialog.value;
                            final value = dialogContext.levit.find<String>();
                            return AlertDialog(content: Text('$value:$tick'));
                          }),
                        ),
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              );
            }),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('captured-value:0'), findsOneWidget);

      // Unmount the launcher widget while the dialog remains open, then rebuild dialog.
      showLauncher.value = false;
      await tester.pumpAndSettle();
      rebuildDialog.value = 1;
      await tester.pumpAndSettle();

      expect(find.text('captured-value:1'), findsOneWidget);
      await showLauncher.close();
      await rebuildDialog.close();
    },
  );

  testWidgets(
    'LevitAppLifecycleMixin detaches on requestCancel and ignores double onInit leak',
    (tester) async {
      final controller = _LifecycleProbeController();
      controller.onInit();
      controller.onInit();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(controller.resumedCalls, 1);

      controller.requestCancel();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(controller.resumedCalls, 1);

      await controller.onClose();
    },
  );
}
