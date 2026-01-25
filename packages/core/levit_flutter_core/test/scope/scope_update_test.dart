import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

void main() {
  testWidgets('LScope update rebuilds children', (tester) async {
    int buildCount = 0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: LScope(
          dependencyFactory: (s) => s.put(() => 'A', tag: 'tag1'),
          child: Builder(builder: (context) {
            buildCount++;
            return const SizedBox();
          }),
        ),
      ),
    );

    expect(buildCount, 1);

    // Rebuild with different tag to trigger didUpdateWidget
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: LScope(
          dependencyFactory: (s) => s.put(() => 'A', tag: 'tag2'),
          child: Builder(builder: (context) {
            buildCount++;
            return const SizedBox();
          }),
        ),
      ),
    );

    expect(buildCount, 2);
  });
}
