import 'package:levit_reactive/levit_reactive.dart';
import 'package:test/test.dart';

class _Capture extends LevitReactiveMiddleware {
  final captured = <LxReactive>[];
  @override
  void Function(LxReactive) get onInit => (r) {
    void take() => captured.add(r);
    if (!Lx.deferAutoLink(r, take)) take();
  };
}

void main() {
  test(
    'resource activity and diagnostic owner follow real subscriptions',
    () async {
      final changes = <bool>[];
      final r = LxResource<int, LxVar<int>>(
        () => 1.lx,
        ownerId: 'controller',
        onActivityChanged: changes.add,
      );
      final unrelated = 2.lx;
      final c = LxComputed(() => r.value + Lx.untracked(() => unrelated.value));
      void tick() {
        c.value;
      }

      c.addListener(tick);
      expect(c.value, 3);
      expect(r.producer.ownerId, 'controller');
      unrelated.value++;
      expect(c.value, 3);
      await c.close();
      expect(changes, [true, false]);
      await r.close();
      await unrelated.close();
    },
  );
  test(
    'nested ownership hands independent siblings back to ambient capture',
    () async {
      final capture = _Capture();
      LevitReactiveMiddleware.add(capture, token: 'capture');
      late LxVar<int> sibling, child;
      final parent = Lx.createOwned(() {
        child = Lx.createOwned(() {
          sibling = 3.lx;
          return 1.lx;
        });
        return 2.lx;
      });
      expect(capture.captured, [sibling]);
      expect(LevitReactiveMiddleware.remove(capture), true);
      await child.close();
      await parent.close();
      await sibling.close();
    },
  );
}
