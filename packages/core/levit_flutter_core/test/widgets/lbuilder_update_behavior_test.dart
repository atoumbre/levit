import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

void main() {
  group('LBuilder Update', () {
    testWidgets('LWatchVar update coverage', (tester) async {
      final v1 = 0.lx;
      final v2 = 1.lx;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LBuilder(
            v1,
            (v) => Text('V: ${v}'),
          ),
        ),
      );
      expect(find.text('V: 0'), findsOneWidget);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LBuilder(
            v2,
            (v) => Text('V: ${v}'),
          ),
        ),
      );
      expect(find.text('V: 1'), findsOneWidget);
    });
  });
}
