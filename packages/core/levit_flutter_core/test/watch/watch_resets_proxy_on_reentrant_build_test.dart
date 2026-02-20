import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

void main() {
  testWidgets('LWatch re-entrant build proxy reset', (tester) async {
    final watchKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: LWatch(
          () => Container(),
          key: watchKey,
        ),
      ),
    );

    // Get the element associated with LWatch
    final element = tester.element(find.byKey(watchKey)) as ComponentElement;

    // Simulate a re-entrant build by setting Lx.proxy to the element itself
    // and explicitly invoking build. This is unnatural in typical Flutter but
    // satisfies the identical(previousProxy, this) branch in watch.dart line 150.
    Lx.proxy = element as LevitReactiveObserver;

    expect(
      // ignore: invalid_use_of_protected_member
      () => element.build(),
      returnsNormally,
    );

    // proxy should be correctly restored to the previous value
    expect(Lx.proxy, equals(element));
  });
}
