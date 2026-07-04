import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

class ObserverLifecycleController extends LevitController
    with LevitAppLifecycleMixin {
  final List<AppLifecycleState> observedStates = <AppLifecycleState>[];

  @override
  void onAppResumed() => observedStates.add(AppLifecycleState.resumed);

  @override
  void onAppPaused() => observedStates.add(AppLifecycleState.paused);

  @override
  void onAppInactive() => observedStates.add(AppLifecycleState.inactive);

  @override
  void onAppDetached() => observedStates.add(AppLifecycleState.detached);

  @override
  void onAppHidden() => observedStates.add(AppLifecycleState.hidden);
}

void main() {
  group('LevitAppLifecycleMixin observer', () {
    testWidgets('registers on init and stops receiving events on close', (
      tester,
    ) async {
      final controller = ObserverLifecycleController();
      final states = <AppLifecycleState>[
        AppLifecycleState.paused,
        AppLifecycleState.resumed,
        AppLifecycleState.inactive,
        AppLifecycleState.detached,
        AppLifecycleState.hidden,
      ];

      controller.onInit();

      for (final state in states) {
        tester.binding.handleAppLifecycleStateChanged(state);
        await tester.pump();
      }

      expect(controller.observedStates, states);

      controller.onClose();

      for (final state in states) {
        tester.binding.handleAppLifecycleStateChanged(state);
        await tester.pump();
      }

      expect(controller.observedStates, states);
    });
  });
}
