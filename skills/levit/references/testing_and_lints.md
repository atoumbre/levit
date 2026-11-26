# Testing & `levit_lints` (Levit 0.1.0)

## Pure Dart Tests

Prefer isolated scopes over mutating and resetting the global root scope:

```dart
import 'package:levit/levit.dart';
import 'package:test/test.dart';

void main() {
  test('increments counter inside an isolated scope', () async {
    await Levit.runInScope(() async {
      final ctrl = Levit.put(() => CounterController());
      ctrl.increment();
      expect(ctrl.count.value, 1);
    });
  });
}
```

For `LevitStore` overrides in unit tests:

```dart
final scope = Levit.createScope(name: 'test');
addTearDown(scope.dispose);

scope.applyOverrides([
  userStore.overrideWith((ref) => FakeUser(name: 'Test')),
]);
```

## Flutter Widget Tests

Mount an `LScope`, capture the scope or register fakes inside `onConfigure`, and await scope disposal on teardown:

```dart
testWidgets('updates counter text on tap', (tester) async {
  Levit.enableAutoLinking();
  LevitScope? testScope;

  await tester.pumpWidget(
    MaterialApp(
      home: LScope(
        onConfigure: (scope) {
          testScope = scope;
          scope.put(() => CounterController());
        },
        child: const CounterPage(),
      ),
    ),
  );

  await tester.tap(find.byIcon(Icons.add));
  await tester.pump();
  expect(find.text('1'), findsOneWidget);

  await tester.pumpWidget(const SizedBox.shrink());
  await testScope?.dispose();
});
```

## Enabling `levit_lints`

`levit_lints` is a native Dart 3.12+ analyzer plugin (`analysis_server_plugin`) that flags lifecycle, ownership, registration, and reactive-status issues directly in the IDE and `dart analyze`.

In `analysis_options.yaml`:

```yaml
plugins:
  levit_lints: ^0.1.0
```

Key checks enforced by `levit_lints`:
- Missing `super.onInit()` / `super.onBeforeClose()` / `super.onClose()` calls in `LevitController` subclasses.
- Unowned reactives or disposables created inside controllers/scopes.
- Unsafe `Levit.find` inside widgets where `context.levit.find` should be used.
- Redundant outer `LWatch` wrapping an `autoWatch: true` view.
- Invalid or unawaited lifecycle disposal and reactive status handling pitfalls.
