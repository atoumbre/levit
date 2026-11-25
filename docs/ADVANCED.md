# Advanced Levit helpers

These APIs remain supported in 0.1.0. Start with scopes, owners, state and widgets
before adding them. Import the normal `levit`/`levit_flutter` kit.

| API | Use and responsibility |
| --- | --- |
| `LevitSelectionMixin` | Selection behavior belongs in a controller; choose stable domain IDs so list replacement does not change selection identity. |
| `LevitTimeMixin` | Own timers/countdowns within the feature. Countdown ticks use monotonic elapsed time; `pause` freezes the precise remainder, `resume` excludes paused time, and `stop` resets. App suspension alone does not pause time. |
| Numeric reactive conveniences | Use for small local arithmetic; keep domain validation and units in application methods. Ordinary `.value` assignments remain the clearest shared vocabulary. |
| `LKeepAlive` | Retain a deliberately offscreen subtree. Retention extends its scope lifetime; invisibility is not disposal. |
| `staticDeps: true` | Opt into a fixed computed dependency graph only when all executions read the same dependencies. Conditional branches and replaced resource producers need dynamic tracking. |
| `Levit.batchAsync` | Coalesce notifications in the current async context; this is not value isolation, rollback or an IO transaction. Outside writes and concurrent batches remain independent. Prefer awaiting IO then a short synchronous `Levit.batch` commit. |

Independent resource owners use `LevitResourceOwnership` with a supported
disposable contract. Explicit `own(resource, dispose: ...)` adapts other resources;
no method-name guessing occurs. Aliases are non-owning views of existing local
singleton registrations. Factory results stay owned by the registering scope;
await `releaseFactoryInstance` for early release.

Dedicated isolate entrypoints remain available. Their cancellation channel is
connected to task groups; completion waits for isolate exit. Async wrappers,
stream completion policies, and consuming versus owning views remain supported.
`runGuardedAsync(discardResultOnClose: true)` discards obsolete results; use
structured tasks when cancellation and descendant lifetime matter.

The [Flutter kit example](../packages/kits/levit_flutter/example) includes a local
mount/unmount recipe and countdown/ValueListenable interoperability. Mount
callbacks describe widget lifetime, not viewport visibility. For browser-safe
monitor models use the protocol/default entrypoint; file transport requires the
IO entrypoint. Persistent storage/cache/restoration belongs in the ecosystem.
