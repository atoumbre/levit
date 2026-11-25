import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

void main() {
  testWidgets('nullable reads in a build never mutate the source', (
    tester,
  ) async {
    final value = LxVar<String?>('kept');
    var changes = 0;
    value.addListener(() => changes++);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: LWatch(() => Text(value() ?? 'empty')),
      ),
    );
    expect(find.text('kept'), findsOneWidget);
    expect(changes, 0);
    value.value = null;
    await tester.pump();
    expect(find.text('empty'), findsOneWidget);
    expect(changes, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await value.close();
  });
}
