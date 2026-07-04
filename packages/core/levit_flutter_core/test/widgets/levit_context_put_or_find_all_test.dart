import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

class _TestService {}

void main() {
  testWidgets('putOrFind creates global instance if missing', (tester) async {
    Levit.reset(force: true);
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      final service =
          context.levit.putOrFind<_TestService>(() => _TestService());
      return Text('S: ${service.hashCode}');
    })));
    expect(Levit.isRegistered<_TestService>(), true);
  });
  testWidgets('putOrFind uses existing scoped instance', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: LScope(
            dependencyFactory: (s) => s.put<_TestService>(() => _TestService()),
            child: Builder(builder: (context) {
              context.levit.putOrFind<_TestService>(() => _TestService());
              return Container();
            }))));
  });
}
