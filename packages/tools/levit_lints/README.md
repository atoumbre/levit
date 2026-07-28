# levit_lints

Native Dart analyzer rules for Levit lifecycle and reactive-state safety.

The package uses Dart's analyzer-plugin API and does not depend on any Levit
runtime package.

## Enable

Analyzer plugins require Dart 3.10 or newer. Add the package directly to the
top-level `plugins` section:

```yaml
plugins:
  levit_lints:
    version: ^0.0.11
    diagnostics:
      avoid_plain_lx_status_fields: true
      avoid_preconstructed_levit_put: true
      must_call_super_levit_lifecycle: true
      unowned_levit_resource: true
```

For local development, replace `version` with an absolute `path`.

## Rules

| Rule | Detects |
| :-- | :-- |
| `avoid_plain_lx_status_fields` | Mutable plain `LxStatus` owner fields and fields that retain a `.status` snapshot. |
| `avoid_preconstructed_levit_put` | `Levit.put(() => existingController)` when the returned expression is already a resource owner. |
| `must_call_super_levit_lifecycle` | `onInit`/`onClose` owner overrides that omit the corresponding `super` call. |
| `unowned_levit_resource` | Discarded `StreamSubscription`/`Timer` expressions and lazy reactive owner fields not wrapped in `own`/`autoDispose`. |

The rules intentionally require a resolved `LevitResourceOwner` or
`LevitController` hierarchy. Unrelated classes with similarly named methods are
not reported.
