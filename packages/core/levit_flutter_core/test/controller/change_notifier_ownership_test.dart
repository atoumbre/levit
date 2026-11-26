import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

class _TrackingNotifier extends ChangeNotifier {
  bool disposed = false;

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

class _FormController extends LevitController {
  late final textController = own(TextEditingController(text: 'initial'));
  late final focusNode = own(FocusNode());
  late final notifier = own(_TrackingNotifier());
}

void main() {
  group('Flutter ChangeNotifier ownership adapter', () {
    testWidgets(
      'disposes owned ChangeNotifier resources without a callback on LScope unmount',
      (tester) async {
        final lifecycle = LevitScopeLifecycleController();
        late _FormController controller;

        await tester.pumpWidget(
          LScope(
            lifecycle: lifecycle,
            configure: (scope) {
              controller = scope.put(_FormController.new);
              // Force lazy field initialization while mounted.
              expect(controller.textController.text, 'initial');
              expect(controller.focusNode.hasFocus, isFalse);
              expect(controller.notifier.disposed, isFalse);
            },
            child: const SizedBox.shrink(),
          ),
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await lifecycle.close();

        expect(controller.notifier.disposed, isTrue);
        expect(
          () => controller.textController.addListener(() {}),
          throwsFlutterError,
        );
        expect(
          () => controller.focusNode.addListener(() {}),
          throwsFlutterError,
        );
      },
    );

    test(
      'LevitFlutter.ensureInitialized enables ChangeNotifier ownership outside widget trees',
      () async {
        LevitFlutter.ensureInitialized();
        final scope = Levit.createScope('non-widget-flutter-scope');
        final controller = scope.put(_FormController.new);
        final notifier = controller.notifier;

        expect(notifier.disposed, isFalse);
        await scope.dispose();
        expect(notifier.disposed, isTrue);
      },
    );
  });
}
