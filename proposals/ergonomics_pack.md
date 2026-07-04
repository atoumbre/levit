# Levit Ergonomics Pack

This document proposes a small package of API ergonomics improvements across
`levit_flutter_core`, `levit_scope`, and `levit_dart_core`.
It is a design note, not an implemented API contract.

## Why this exists

Levit's core runtime model is already coherent:

- scopes own registrations
- controllers own cleanup
- reactive values own recomputation triggers
- Flutter widgets attach that model to the tree

The remaining friction is mostly ergonomic rather than architectural.
There are a few places where users can already achieve the desired behavior,
but only through low-level or inconsistent APIs:

- `LAsyncView` and `LView` can already use manual dependency keys, but the
  current `args` API is easy to miss and easy to misuse.
- `putOrFind(...)` exists only on the Flutter context extension surface, not in
  pure Dart accessors.
- scope debugging is still thinner than the ownership model suggests.

None of these require a runtime rewrite.
They are small, visible improvements that make the framework easier to adopt.

## Goals

- Remove a known `LAsyncView` / resolver identity issue.
- Make view re-resolution intent explicit and readable.
- Add `putOrFind(...)` parity across Flutter and pure Dart surfaces.
- Expose scope ancestry metadata for debugging and diagnostics.
- Preserve existing runtime semantics.
- Keep migration cost low.

## Non-goals

- Redesign `LView` / `LAsyncView` lifecycle semantics.
- Change dependency resolution order.
- Add code generation requirements.
- Introduce a new ownership model.
- Replace existing APIs in one breaking step.

## Proposed Feature Groups

## Group 1: View Resolution Ergonomics

### Problem

`LAsyncView` currently re-resolves when either:

- the inherited scope changes, or
- the resolver identity changes, when no explicit update keys are provided

That behavior is technically correct, but it is easy to trigger accidentally
with anonymous closures.
The framework already exposes `args` as a manual update key, but that name is
generic and does not clearly communicate intent.

In practice, users see a warning and are told to either:

- avoid anonymous closures, or
- remember to pass `args`

That is a real ergonomics gap.

### Proposal

Add a first-class `deps` API to `LView` and `LAsyncView`.

Example:

```dart
LView<UserController>(
  resolver: (context) => context.levit.find<UserController>(),
  deps: [userId],
  builder: (context, controller) => Text(controller.name()),
)

LAsyncView<User>(
  resolver: (context) => repo.fetchUser(userId),
  deps: [userId],
  builder: (context, user) => Text(user.name),
)
```

### Public API Direction

Add:

```dart
final List<Object?>? deps;
```

to:

- `LView`
- `LAsyncView`
- relevant factory constructors such as `.store(...)` and `.put(...)`

### Compatibility

Keep `args` temporarily as a backward-compatible alias.

Effective behavior:

```dart
effectiveDeps = deps ?? args;
```

`deps` should be the preferred name in docs and examples.
`args` can remain for one compatibility window, then be deprecated or retired
later once the new API is established.

### Behavior

- `deps` becomes the primary signal for re-resolution.
- If `deps` is provided, resolver identity should not be used to decide updates.
- Anonymous-closure warnings should only fire when neither `deps` nor legacy
  `args` is provided.
- Sync and async view variants should share the same dependency-key comparison logic.

### Why this is a quick win

- the comparison machinery already exists
- the change is mostly API naming and plumbing
- tests already cover the current update path
- the user-facing value is immediate

## Group 2: Core Scope Ergonomics

This group packages two related improvements:

- `putOrFind(...)` parity
- richer scope debug metadata

Both are about making Levit's ownership model easier to use and easier to inspect.

### 2A. `putOrFind(...)` parity

### Problem

`putOrFind(...)` already exists on the Flutter context extension surface, but
not on the core pure-Dart accessors.

That means:

- Flutter widget code gets the convenience
- pure Dart controllers, services, and tests do not

This is an unnecessary inconsistency.

### Proposal

Add `putOrFind(...)` to:

- `LevitScope`
- `Ls`
- `Levit`

Example:

```dart
final api = Levit.putOrFind<ApiClient>(() => ApiClient());
final repo = Ls.putOrFind<UserRepository>(() => UserRepository());
final local = scope.putOrFind<CheckoutState>(() => CheckoutState());
```

### Proposed Semantics

- if a matching dependency is already resolvable, return it
- otherwise register and return a new local instance

This should match the existing Flutter-context behavior as closely as possible.

### Design Constraints

- do not change existing `put(...)` or `find(...)` semantics
- respect tag-based lookup
- preserve scope ownership rules
- avoid hidden cross-scope mutation

### 2B. Scope debug metadata

### Problem

Levit's main value proposition is explicit ownership and deterministic hierarchy,
but the scope surface still exposes relatively little ancestry metadata.

Today, users can infer structure manually, but there is no first-class way to ask:

- how deep is this scope?
- what is its ancestry?
- what path led to this scope?

That makes debugging, warnings, and diagnostics less informative than they could be.

### Proposal

Add lightweight metadata getters to `LevitScope`.

Suggested surface:

```dart
LevitScope? get parent;
bool get isRoot;
int get depth;
List<String> get ancestorNames;
String get debugPath;
```

Example:

```dart
expect(scope.depth, 3);
expect(scope.ancestorNames, ['root', 'app', 'checkout']);
expect(scope.debugPath, 'root/app/checkout/payment');
```

### Intended uses

- test assertions
- debug logs
- duplicate-name warnings
- monitor metadata
- troubleshooting scope ownership problems

### Design constraints

- keep getters cheap and deterministic
- do not require middleware or monitoring to be useful
- preserve `toString()` stability unless there is clear value in extending it

## Proposed Rollout

### Phase 1: View ergonomics

Implement `deps` for:

- `LView`
- `LAsyncView`
- `LView.store(...)`
- `LAsyncView.store(...)`
- `LView.put(...)`
- `LAsyncView.put(...)`

Then:

- centralize dependency-key comparison
- keep `args` as compatibility alias
- update anonymous-closure warning conditions

### Phase 2: Core parity

Implement `putOrFind(...)` on:

- `LevitScope`
- `Ls`
- `Levit`

Then align docs/examples so the same convenience exists in Flutter and pure Dart code.

### Phase 3: Scope metadata

Add:

- `parent`
- `isRoot`
- `depth`
- `ancestorNames`
- `debugPath`

to `LevitScope`, and only then decide whether any warnings or logs should adopt
that metadata.

## Testing Strategy

### View ergonomics tests

Add or extend tests in `packages/core/levit_flutter_core/test/view`:

- unchanged `deps` does not re-resolve
- changed `deps` does re-resolve
- warning is suppressed when `deps` is provided
- legacy `args` path still works during the compatibility window

### `putOrFind(...)` tests

Add tests across:

- root scope
- child scope
- tagged resolution
- ancestor reuse
- missing registration creation

Pure Dart tests should be the primary contract.
Existing Flutter-context tests remain useful as parity coverage.

### Scope metadata tests

Add tests for:

- root scope metadata
- nested scope depth
- ancestor name order
- debug path formatting
- duplicate names in ancestry without breaking path generation

## Documentation Updates

If accepted, update:

- root `README.md`
- `packages/core/levit_flutter_core/README.md`
- `packages/core/levit_dart_core/README.md`
- `packages/core/levit_scope/README.md`

Documentation should:

- prefer `deps` over `args`
- show one pure-Dart `putOrFind(...)` example
- show one debugging example using `debugPath` or `depth`

## Expected Outcome

This proposal does not change Levit's ownership model.
It makes the existing model easier to use correctly.

Expected benefits:

- fewer accidental async re-resolutions
- clearer view update intent
- better parity between Flutter and pure Dart surfaces
- stronger debugging around scope ancestry

In short:

- Group 1 reduces widget-level friction
- Group 2 strengthens core ownership ergonomics

These are small features, but they remove visible rough edges in exactly the
areas Levit wants to be strongest: clarity, ownership, and predictable behavior.
