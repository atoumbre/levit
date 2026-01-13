import 'package:levit_dart/levit_dart.dart';
import 'package:test/test.dart';

// Mimic LevitReactiveTasksMixin
mixin TestMixin on LevitController {
  final mixinReactive = LxInt(0).named('mixinReactive');
}

// Mimic AuthController structure
class TestController extends LevitController with TestMixin {
  late final LxStream<int> stream;
  final fieldReactive = LxInt(0).named('fieldReactive');

  @override
  void onInit() {
    super.onInit();
    // Simulate stream creation
    final s = Stream.value(1);
    stream = autoDispose(LxStream(s).named('stream'));
  }
}

void main() {
  test('Auto-linking registers controller ID', () async {
    // Ensure auto-linking is enabled
    Levit.enableAutoLinking();

    // Check if observer is present
    // We can't easily check private _observers list, but can infer from behavior.

    // Register controller
    Levit.put(() => TestController());

    // Find usage triggers lazy creation? No, put is immediate unless lazyPut.
    // Levit.put creates instance immediately.

    final controller = Levit.find<TestController>();

    // Check if reactive has ownerId
    // Check if reactive has ownerId
    print('Owner ID: ${controller.stream.ownerId}');

    expect(controller.stream.ownerId, isNotNull,
        reason: 'Reactive should have ownerId set by auto-linking');
    expect(controller.stream.ownerId, contains('TestController'));

    // Check field reactive
    expect(controller.fieldReactive.ownerId, isNotNull,
        reason:
            'Field reactive should have ownerId set (Captured during constructor)');
    expect(controller.fieldReactive.ownerId, contains('TestController'));

    // Check mixin reactive
    expect(controller.mixinReactive.ownerId, isNotNull,
        reason: 'Mixin field reactive should have ownerId set');
    expect(controller.mixinReactive.ownerId, contains('TestController'));
  });
}
