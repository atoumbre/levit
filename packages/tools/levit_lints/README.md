# levit_lints

Native Dart analyzer rules for Levit lifecycle, reactive-state, and widget
scoping usage, with no Levit runtime dependency. Requires Dart 3.12+.

## Enable

Add this in the **root** `analysis_options.yaml` of your package/workspace:

```yaml
plugins:
  levit_lints:
    version: ^0.1.0
    diagnostics:
      await_levit_lifecycle: true
      avoid_global_levit_in_widgets: true
      discarded_levit_future: true
      must_call_super_levit_lifecycle: true
      unowned_levit_resource: true
      avoid_plain_lx_status_fields: true
      avoid_preconstructed_levit_put: true
      avoid_redundant_outer_lwatch: true
      avoid_unscoped_overlay: true
```

When developing inside a local checkout of the Levit monorepo, replace
`version: ^0.1.0` with `path: /absolute/path/to/levit/packages/tools/levit_lints`.

No runtime dependency or `custom_lint` runner is needed. Restart the analysis
server after changing plugin configuration; run `dart analyze --fatal-infos` or
`flutter analyze` in CI. This uses the
[supported native analyzer plugin configuration](https://dart.dev/tools/analyzer-plugins).

## Rules and limits

| Rule | Detects |
| :-- | :-- |
| `await_levit_lifecycle` | Async `super.onInit/onBeforeClose/onClose` calls that are neither awaited nor directly returned. Explicit `unawaited` is insufficient for lifecycle delegation. |
| `avoid_global_levit_in_widgets` | Resolved global `Levit.find*` calls inside Flutter `Widget`/`State` implementations, including aliased imports. Use `context.levit.find*`. |
| `discarded_levit_future` | Directly discarded futures from known Levit disposal, scope replacement and worker cleanup APIs. Await, return, retain, or explicitly observe the future. |
| `must_call_super_levit_lifecycle` | Owner lifecycle overrides that omit the corresponding super call. |
| `unowned_levit_resource` | Discarded subscriptions/timers and lazy reactive owner fields outside `own`. |
| `avoid_plain_lx_status_fields` | Mutable plain status fields and retained `.status` snapshots. |
| `avoid_preconstructed_levit_put` | A registration builder returning an already constructed owner. |
| `avoid_redundant_outer_lwatch` | Returning a root `LWatch` inside `LView` / `LScopedView` / `LAsyncView` when `autoWatch` is enabled. |
| `avoid_unscoped_overlay` | Raw `showDialog` / `showModalBottomSheet` inside Levit Flutter widgets without `LScope.capture` (use `showLevitDialog` / `showLevitModalBottomSheet`). |

The three async/scoping rules resolve API/library identity. Similar names on
unrelated types do not trigger them. Widget analysis cannot infer the runtime
scope tree, so the lookup rule consistently recommends context lookup in widget
classes. It does not inspect arbitrary top-level builder helpers.

These are local diagnostics, **not general cancellation or control-flow analysis**.
Stored futures must still be observed by the application. The rules do not prove
that a callback returns every nested future, that every branch delegates, or
that cancellation stops external IO. Existing ownership rules use resolved type
hierarchies and conventional Levit type names.

```dart
@override
Future<void> onBeforeClose() async {
  await super.onBeforeClose();
  await flushApplicationWork();
}
```

For an intentional exception, use a namespaced suppression with a reason:
`// ignore: levit_lints/avoid_global_levit_in_widgets`.

## Validation

`dart test` tests violations and valid patterns using resolved mock API libraries.
`scripts/check_lint_plugin.dart` in the repository checks actual native-plugin
loading and diagnostics in a temporary consuming package. Publication is a
separate release action.
