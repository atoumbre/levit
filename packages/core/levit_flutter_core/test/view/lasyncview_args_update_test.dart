import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

void main() {
  testWidgets('LAsyncView updates when args change', (tester) async {
    int callCount = 0;
    Future<int> mockResolver(BuildContext context) async {
      callCount++;
      return callCount;
    }

    // 1. Initial build with args [1]
    await tester.pumpWidget(MaterialApp(
      home: LAsyncView<int>(
        resolver: mockResolver,
        args: const [1],
        builder: (context, val) => Text('Value: $val'),
        loading: (_) => const Text('Loading...'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Value: 1'), findsOneWidget);
    expect(callCount, 1);

    // 2. Rebuild with SAME args -> Should NOT update
    await tester.pumpWidget(MaterialApp(
      home: LAsyncView<int>(
        resolver: mockResolver,
        args: const [1],
        builder: (context, val) => Text('Value: $val'),
        loading: (_) => const Text('Loading...'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(callCount, 1); // Still 1

    // 3. Rebuild with DIFFERENT args (content) -> Should update
    await tester.pumpWidget(MaterialApp(
      home: LAsyncView<int>(
        resolver: mockResolver,
        args: const [2],
        builder: (context, val) => Text('Value: $val'),
        loading: (_) => const Text('Loading...'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Value: 2'), findsOneWidget);
    expect(callCount, 2); // Updated

    // 4. Rebuild with DIFFERENT args (length) -> Should update
    await tester.pumpWidget(MaterialApp(
      home: LAsyncView<int>(
        resolver: mockResolver,
        args: const [2, 3],
        builder: (context, val) => Text('Value: $val'),
        loading: (_) => const Text('Loading...'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Value: 3'), findsOneWidget);
    expect(callCount, 3); // Updated

    // 5. Rebuild with NULL args vs List -> Should update (covered by null logic)
    await tester.pumpWidget(MaterialApp(
      home: LAsyncView<int>(
        resolver: mockResolver,
        args: null,
        builder: (context, val) => Text('Value: $val'),
        loading: (_) => const Text('Loading...'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Value: 4'), findsOneWidget);
    expect(callCount, 4); // Updated
  });

  testWidgets('LAsyncView _argsMatch helper coverage', (tester) async {
    // This specifically targets lines 216-220 in view.dart
    int callCount = 0;
    Future<int> mockResolver(BuildContext context) async {
      callCount++;
      return callCount;
    }

    // Start with [1, 2]
    await tester.pumpWidget(MaterialApp(
      home: LAsyncView<int>(
        resolver: mockResolver,
        args: const [1, 2],
        builder: (context, val) => Text('Value: $val'),
        loading: (_) => const Text('Loading...'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(callCount, 1);

    // Verify length mismatch logic
    await tester.pumpWidget(MaterialApp(
      home: LAsyncView<int>(
        resolver: mockResolver,
        args: const [1, 2, 3],
        builder: (context, val) => Text('Value: $val'),
        loading: (_) => const Text('Loading...'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(callCount, 2);

    // Verify content mismatch at index
    await tester.pumpWidget(MaterialApp(
      home: LAsyncView<int>(
        resolver: mockResolver,
        args: const [1, 99, 3],
        builder: (context, val) => Text('Value: $val'),
        loading: (_) => const Text('Loading...'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(callCount, 3);
  });
}
