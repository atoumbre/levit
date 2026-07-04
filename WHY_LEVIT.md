# Why Levit

Levit is for teams whose hardest state problems are really ownership, teardown, and update-traceability problems.

It combines:

- Scoped dependency ownership
- Deterministic cleanup
- Fine-grained reactive propagation
- Flutter rebuild boundaries
- One runtime model across pure Dart and Flutter
- Opt-in runtime observability

If that sounds heavier than a minimal state package, that is intentional.
Levit is designed for applications where lifecycle mistakes, unclear dependency ownership, and broad rebuild behavior are already creating bugs, cost, or hesitation.

## The Problem Behind "State Management"

Many application stacks split these concerns across separate tools:

- State and derivation
- Dependency resolution
- Lifecycle and disposal
- Widget rebuild boundaries
- Diagnostics

That often works early on.
As the codebase grows, the seams start to matter:

- state survives longer than the feature that created it
- dependencies can be resolved, but no one is sure who owns them
- widgets rebuild, but the triggering read is hard to trace
- shared Dart logic and Flutter UI follow different architectural rules

Levit takes a different position:

> Scope ownership, cleanup, and reactive propagation should belong to the same runtime model.

That is why the ecosystem is layered the way it is:

- [`levit_scope`](./packages/core/levit_scope) defines ownership and deterministic disposal
- [`levit_reactive`](./packages/core/levit_reactive) defines change propagation and dependency tracking
- [`levit_dart_core`](./packages/core/levit_dart_core) composes both into controllers, stores, and the `Levit` facade
- [`levit_flutter_core`](./packages/core/levit_flutter_core) maps that model onto Flutter widget lifecycles
- [`levit_monitor`](./packages/core/levit_monitor) adds runtime diagnostics when needed, without forcing them into the default runtime

## The Promise

Levit helps teams answer a small set of high-value questions with confidence:

- What owns this object?
- When does it get disposed?
- What scope can resolve it?
- What caused this recomputation or rebuild?
- Can the same rules apply in Flutter, shared domain packages, services, and CLI tools?

The framework is opinionated about those questions:

- Scopes own registrations
- Controllers own cleanup
- Reactive values propagate changes deterministically
- Flutter widgets opt into focused rebuild boundaries
- Monitoring stays optional

## What Makes Levit Different

Levit is not mainly trying to win on the fewest concepts.
It is trying to make several concerns coherent together:

- Dependency scope
- Lifecycle ownership
- Reactive propagation
- Widget rebuild boundaries
- Runtime diagnostics

Flutter developers will reasonably compare this with Riverpod, Bloc, or Provider.
Those tools are often centered on modeling and delivering application state inside Flutter.
Levit is aimed at a broader problem: making ownership, teardown, reactive propagation, and Flutter bindings part of one runtime model that still works outside the widget tree.

That is the core value proposition:

> Levit gives Dart and Flutter teams deterministic ownership and reactive precision when lifecycle bugs and unclear boundaries are becoming expensive.

## What Levit Optimizes For

### 1. Deterministic ownership

Levit is strongest when object lifetime should be obvious from structure.

A child scope can override parent dependencies without mutating parent state.
When the child scope goes away, its registrations go away with it.
That reduces bugs where state outlives the feature, route, or subtree that created it.

### 2. Fine-grained reactive updates

The reactive model tracks what was actually read, then recomputes or rebuilds only where needed.

In Flutter, that shows up through widgets such as:

- `LWatch` for proxy-tracked reactive reads
- `LBuilder` for explicit single-reactive rebuilds
- `LStatusBuilder` for status-oriented async rendering

This is not only about micro-benchmarks.
It is also about keeping rebuild boundaries intentional and easier to inspect.

### 3. One architecture across Dart and Flutter

Levit is not Flutter-only.
The same model applies to:

- Pure Dart services
- Shared domain logic
- Command-line tools
- Flutter application code

That matters when the UI should not be the only place where lifecycle discipline exists.

### 4. Operational visibility

With [`levit_monitor`](./packages/core/levit_monitor), observability becomes part of the architecture instead of an afterthought.

You can attach diagnostics, redact sensitive values, and export runtime events without changing the ownership model underneath.

## Where Levit Fits Best

Levit is a good fit when:

- The codebase is medium to large and lifecycle bugs are already expensive
- The team wants explicit scope boundaries and deterministic teardown
- The same architectural rules should work in shared Dart code and Flutter UI
- Performance matters enough that broad rebuild patterns become a real cost
- The team values runtime introspection and debuggability

Typical examples:

- Multi-feature Flutter applications with feature-scoped controllers
- Apps with shared domain packages used by Flutter and non-Flutter targets
- Products that need stronger lifecycle guarantees than ad hoc dependency wiring provides

## When Not To Use Levit

Levit is not the best choice for every project.

You may not need it if:

- The app is small enough that manual ownership is still obvious everywhere
- The team wants the smallest possible API surface over explicit architectural control
- Introducing scopes, controllers, and reactive boundaries would be more ceremony than value
- The project does not benefit from shared Dart and Flutter architectural semantics

The tradeoff is straightforward:

- Levit gives you stronger ownership and lifecycle guarantees
- In return, it asks you to work with a more explicit model

That trade can be worth it in larger systems and unnecessary in smaller ones.

## Evidence

The pitch is backed by concrete material in this repo:

- Benchmark methodology: [`benchmarks/README.md`](./benchmarks/README.md)
- Comparative results: [`reports/bench_mark_report.md`](./reports/bench_mark_report.md)
- Stress results for reactive, DI, and Flutter bindings: [`reports/stress_test_report.md`](./reports/stress_test_report.md)
- Worked examples: [`examples/`](./examples), [`packages/kits/levit_flutter/example/README.md`](./packages/kits/levit_flutter/example/README.md)

These are not a substitute for trying the framework in your own workload, but they do show that the claims are meant to be testable.

## A Practical Mental Model

If you only remember one thing, remember this:

1. A scope defines who can resolve what.
2. A controller defines who owns cleanup for a unit of logic.
3. A reactive value defines what can trigger recomputation or rebuild.
4. Flutter bindings define where that runtime model attaches to the widget tree.

That is the center of the framework.
Most of the package surface exists to make those four rules practical in different contexts.

In practice, that can stay small:

```dart
return LScopedView<CounterController>.put(
  () => CounterController(),
  builder: (context, controller) =>
      LWatch(() => Text('Count: ${controller.count()}')),
);
```

## How To Adopt It

If you are evaluating Levit, start with the entry point that matches the job you are trying to do:

- Building a pure Dart application, service, CLI, or shared domain package: start with [`levit`](./packages/kits/levit).
- Building a Flutter application: start with [`levit_flutter`](./packages/kits/levit_flutter).
- Composing your own runtime surface on top of the core ownership model: start with [`levit_dart_core`](./packages/core/levit_dart_core).
- Using the Flutter bindings directly without the higher-level Flutter kit: start with [`levit_flutter_core`](./packages/core/levit_flutter_core).
- Adding telemetry, event export, or runtime diagnostics: add [`levit_monitor`](./packages/core/levit_monitor) separately.

From there:

- Use the root [`README.md`](./README.md) for ecosystem structure and quick onboarding.
- Use package READMEs for package boundaries and package-specific guidance.
- Use DartDoc for the public API contract.

## The Short Version

Levit is valuable when your application needs lifecycle rigor, clear ownership, and reactive precision more than it needs the smallest possible conceptual surface.

If your team keeps asking:

- What owns this?
- When does it go away?
- What caused this update?
- Can the same model survive outside the widget tree?

then Levit has a clear reason to exist.
