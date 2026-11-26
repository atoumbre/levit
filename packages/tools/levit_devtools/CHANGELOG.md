## 0.1.0

- Initial release of `levit_devtools`:
  - Read-only Flutter DevTools extension (Scopes, Reactives, Tasks, Timeline, Diagnostics tabs).
  - `LevitVmServiceTransport` streaming redacted `LevitEventEnvelope` updates and serving `ext.levit.getSnapshot`, `ext.levit.getHistory`, and `ext.levit.getDiagnostics` over `dart:developer`.
  - `LevitDevTools.attach()` convenience bootstrap (automatic no-op in release builds).
