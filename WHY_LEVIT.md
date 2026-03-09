# Why Levit

Levit exists for teams that want more than a state container.

Levit is a deterministic reactive architecture built to solve the lifecycle, dependency, and rebuild issues that plague scaling Dart and Flutter applications.

It combines:

- Explicit ownership through scopes and controllers
- Fine-grained reactive updates
- Predictable teardown and disposal
- A shared mental model across pure Dart and Flutter
- Opt-in runtime observability

If that sounds heavier than a typical state-management package, that is intentional.
Levit is designed for applications where lifecycle mistakes, unclear dependency ownership, and broad rebuild behavior become recurring sources of bugs and performance cost.

## The Core Thesis

Most application stacks split lifecycle, dependency management, and reactive state across separate tools.
That often works at first, but over time it creates friction:

- State exists, but ownership is unclear
- Dependencies are available, but disposal is inconsistent
- Rebuilds happen, but the reason is hard to trace
- Shared Dart logic and Flutter UI end up with different architectural rules

Levit takes a different position:

> Scope ownership, reactive propagation, and cleanup should be part of the same runtime model.

That is the reason the ecosystem is layered the way it is:

- [`levit_scope`](./packages/core/levit_scope) defines ownership and deterministic disposal
- [`levit_reactive`](./packages/core/levit_reactive) defines change propagation and dependency tracking
- [`levit_dart_core`](./packages/core/levit_dart_core) composes both into controllers, stores, and the `Levit` facade
- [`levit_flutter_core`](./packages/core/levit_flutter_core) maps that model onto Flutter widget lifecycles
- [`levit_monitor`](./packages/core/levit_monitor) adds opt-in runtime diagnostics when needed

## What Problem Levit Solves

Levit is built for applications where these questions matter:

- Who owns this object?
- When is it disposed?
- What scope can resolve it?
- Which reactive read caused this rebuild?
- Can the same architecture work in Flutter, CLI tools, server code, and shared domain logic?

The framework is opinionated about those questions:

- Scopes own registrations
- Controllers own cleanup
- Reactive values propagate changes deterministically
- Flutter widgets opt into precise rebuild boundaries
- Monitoring is available, but not forced into the default runtime

## What Levit Optimizes For

### 1. Deterministic ownership

Levit is strongest when object lifetime should be obvious from structure.

A child scope can override parent dependencies without mutating parent state.
When the child scope goes away, its registrations go away with it.
That reduces the class of bugs where state outlives the feature or subtree that created it.

### 2. Fine-grained reactive updates

The reactive model is designed to track exactly what was read, then rebuild or recompute only where needed.

In Flutter, that shows up through widgets such as:

- `LWatch` for proxy-tracked reactive reads
- `LBuilder` for explicit single-reactive rebuilds
- `LStatusBuilder` for status-oriented async rendering

This is not just about performance metrics.
It is also about keeping rebuild boundaries intentional and easy to inspect.

### 3. One architecture across Dart and Flutter

Levit is not Flutter-only.

The same model applies to:

- Pure Dart services
- Shared domain logic
- Command-line tools
- Flutter application code

That matters when the UI should not be the only place where lifecycle discipline exists.

### 4. Operational visibility

With [`levit_monitor`](./packages/core/levit_monitor), observability becomes part of the architecture instead of a patch added later.

You can attach diagnostics, redact sensitive values, and export runtime events without changing the underlying ownership model.

## What Makes It Different

Levit is not primarily trying to win on the fewest concepts.

Its value is in making several concerns coherent together:

- Dependency scope
- Lifecycle ownership
- Reactive propagation
- Widget rebuild boundaries
- Runtime diagnostics

Many libraries are strong in one or two of those areas.
Levit's proposition is that the combination is more valuable than any single piece on its own.

Flutter developers will reasonably compare this with Riverpod, Bloc, or Provider.
Those tools are often centered on modeling and delivering application state inside Flutter.
Levit is trying to solve a slightly broader problem: make scope ownership, lifecycle cleanup, reactive propagation, and Flutter bindings part of one runtime model that also remains usable in pure Dart code.

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

That trade can be very good in larger systems and unnecessary in smaller ones.

## What Levit Is Not

Levit is not:

- Just a widget toolkit
- Just a DI package
- Just a signal/reactive primitive library
- Just an async status wrapper
- A framework that hides lifecycle under convenience APIs

It can feel simple in use, but its goal is not to erase structure.
Its goal is to make structure explicit and reliable.

## A Practical Mental Model

If you only remember one thing, remember this:

1. A scope defines who can resolve what.
2. A controller defines who owns cleanup for a unit of logic.
3. A reactive value defines what can trigger recomputation or rebuild.
4. Flutter bindings define where that runtime model attaches to the widget tree.

That is the center of the framework.
Most of the package surface exists to make those four rules practical in different contexts.

In practice, that can stay small. A child scope can own a controller, and a reactive read can drive a precise rebuild boundary in just a few lines:

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

- Use the root [`README.md`](./README.md) for ecosystem structure.
- Use package READMEs for package boundaries and onboarding.
- Use DartDoc for the public API contract.

## The Short Version

Levit is valuable when your application needs lifecycle rigor, clear ownership, and reactive precision more than it needs the smallest possible conceptual surface.

It is a framework for teams that want to answer these questions with confidence:

- What owns this?
- When does it go away?
- What caused this update?
- Can the same model survive outside the widget tree?

If those questions matter in your codebase, Levit has a clear reason to exist.
