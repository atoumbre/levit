# Levit ecosystem roadmap

## Boundary decision

Approved during 0.1.0 preparation: persistence belongs in a separate ecosystem
repository and release stream. These items were explicitly moved from the original
M7; they are **planned, not implemented**, and do not block the main 0.1.0 release.
This document is the handoff roadmap; it does not create or publish another repository.

The main repository owns scopes, deterministic cleanup, reactive state, structured
work, diagnostics and first-party Flutter bindings. Ecosystem integrations depend
on public Levit APIs. Runtime packages must not import ecosystem packages or host
storage-specific interfaces, serialization policy, codecs or migrations. Add core
extension points only when an integration demonstrates a missing general capability.

## E1 — Versioned persistence foundation

Proposed optional Dart package: `levit_persistence` (name subject to availability).

- [ ] Define a storage interface, typed versioned codecs and memory storage here,
  in the ecosystem, along with an IO-only file adapter.
- [ ] Require stable namespaced keys and explicit schema migrations.
- [ ] Restore before exposing persisted state through Levit's async initialization.
- [ ] Serialize/coalesce writes so delayed old writes cannot overwrite newer state.
- [ ] Flush pending writes through awaited owner cleanup; surface write failures.
- [ ] Report corrupt or unsupported data visibly and return the configured default.
- [ ] Keep persisted state lifetimes explicit and avoid global storage singletons.
- [ ] Document suitability for settings and disposable caches; durable workflow
  execution and database/ORM behavior remain outside scope.

Acceptance: restart and schema migration, missing/corrupt/unsupported records,
write failure, coalescing, ordering under delayed IO, and disposal during IO.
Exercise every storage implementation through the same contract tests.

## E2 — Platform integrations and restoration

Proposed optional Flutter package: `levit_persistence_flutter`.

- [ ] Add a SharedPreferencesAsync storage adapter for settings/disposable caches.
- [ ] Provide a Flutter restoration adapter and runnable example with explicit codecs.
- [ ] Keep platform imports out of the Dart storage/codec library and IO imports
  out of browser entrypoints.
- [ ] Verify restore-before-exposure and awaited write cleanup in widget tests.
- [ ] Publish platform support and migration instructions per adapter.

The borrowing ValueListenable adapter stays in the main Flutter bindings. It is
native observation interoperability and has no persistence or storage dependency.

## E3 — Persistent task-result cache

- [ ] Reuse E1 storage and codecs in an adapter for Levit's public task-cache API.
- [ ] Define cache namespaces, schema/version handling, freshness and invalidation.
- [ ] Preserve task ownership/cancellation rules and drain pending cache IO on close.
- [ ] Demonstrate the difference between caching completed results and resuming
  unfinished work; durable workflow scheduling is not included.

## Independent release and compatibility

- [ ] Use independent package versions, changelogs and release gates. Do not tie
  ecosystem delivery dates or version numbers to the main runtime release.
- [ ] Test against supported published Levit versions using only their public APIs.
- [ ] Keep integration fixtures for initialization, subscription ownership, errors
  and awaited cleanup. Run them before declaring a runtime version supported.
- [ ] Maintain browser builds where supported, adapter tests, analysis, documentation
  and publication dry-runs in the ecosystem repository.
- [ ] Link published integrations from main-repository documentation once available.

See the [revised 0.1.0 plan](release_0.1.0_plan.md) and
[implementation progress](release_0.1.0_progress.md).
