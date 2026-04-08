import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

class _TestService {}

void main() {
  testWidgets('lazyPutAsync returns a finder function', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: LScope(
            dependencyFactory: (s) => s.put<String>(() => 'dummy'),
            child: Builder(builder: (context) {
              final finder = context.levit
                  .lazyPutAsync<_TestService>(() async => _TestService());
              return TextButton(
                  onPressed: () async {
                    await finder();
                  },
                  child: const Text('Find'));
            }))));
    expect(find.text('Find'), findsOneWidget);
  });
}
