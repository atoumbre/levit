import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

void main() {
  group('LWatch Cleanup Strategies', () {
    testWidgets('LWatch cleanup paths (switching strategies)', (tester) async {
      final s1 = 0.lx;
      final s2 = 0.lx;

      await tester.pumpWidget(LWatch(() {
        s1.value;
        return Container();
      }));

      await tester.pumpWidget(LWatch(() {
        s1.value;
        s2.value;
        return Container();
      }));

      await tester.pumpWidget(LWatch(() {
        return Container();
      }));

      await tester.pumpWidget(LWatch(() {
        s1.value;
        return Container();
      }));

      await tester.pumpWidget(LWatch(() {
        return Container();
      }));
    });
  });
}
