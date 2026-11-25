# Ergonomics — 0.1.0 disposition

This former proposal is superseded by implemented contracts, not a second roadmap.

- Views resolve when the scope or explicit `args` change. Resolver closure
  identity alone does not refetch. `args` remains the API name; no `deps` alias.
- Typed context/ref store access replaces dynamic key lookup. Definitions plus
  variant tags determine identity, independent of result type and labels.
- Install typed builder overrides before local resolution. The receiving scope
  owns the result; inherited state remains borrowed unless `localOnly` is selected.
- `scope.describe()` returns immutable ancestry, registration, ownership and
  closing metadata without dependency values. The local inspector consumes
  lifecycle progress and reconnect snapshots.
- Flutter scope lifecycle controllers serialize replacement, coalesce requests,
  surface loading/cleanup failures and expose retry and awaited completion.
- `putOrFind` remains a Flutter context convenience. Pure Dart composition uses
  explicit registration and lookup; no extra facade parity API was added.

Use [onboarding](../docs/ONBOARDING.md), [migration](../MIGRATION_0.1.0.md),
[session examples](../examples/scope_playground) and inline DartDoc.
