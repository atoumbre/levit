## Levit Bubbles

A minimal Flutter example demonstrating **Levit as a lifecycle-aware, time-driven reactive runtime**, not just a state container.

This app renders animated circles (“bubbles”) that:

* Spawn over time
* Move via discrete target updates
* Gradually shrink and self-dispose
* Pause and resume based on **app lifecycle** *and* **user intent**

---

### What this example demonstrates

#### 1. Reactive domain models

Each circle is a self-contained reactive entity:

* `position` and `radius` are `LxVar`s
* Reactivity lives **with the data**, not in widgets
* UI watches domain state directly

This enables fine-grained updates without centralizing all state in a controller.

---

#### 2. Controllers orchestrate time, not UI

`CircleController` is responsible for **behavior over time**:

* Spawning new circles
* Emitting new movement targets
* Applying decay (shrink)

These behaviors are implemented as **named execution loops**, each with its own cadence.

The controller never manages animations or rendering.

---

#### 3. Multiple concurrent execution loops

The app runs several loops simultaneously:

* `spawn` — emits new entities
* `path` — emits new spatial targets (like a location stream)
* `shrink` — applies gradual decay

Each loop is:

* Independent
* Lifecycle-aware
* Pausable / resumable

This models real systems more accurately than single-tick or event-only approaches.

---

#### 4. Lifecycle-aware execution

Using `LevitLoopLifecycleMixin`, all loops:

* Pause automatically when the app goes to background
* Resume when the app returns to foreground

Additionally, **domain pause** (user pressing pause) is kept separate from **app lifecycle pause**.

This distinction is explicit and intentional.

---

#### 5. Flutter handles motion, Levit handles intent

The controller emits *discrete state changes*.

Flutter widgets (`AnimatedPositioned`, `AnimatedContainer`) interpolate smoothly between them.

No `Ticker`, no `AnimationController`, no manual stream wiring.

Levit emits intent. Flutter renders motion.

---

### Why this example exists

This example is not about drawing circles.

It demonstrates how Levit enables:

* Deterministic time-based logic
* Explicit lifecycle control
* Reactive domain modeling
* Clean separation between **behavior**, **state**, and **rendering**

All with minimal boilerplate.

---

### Key takeaway

Levit is best understood as:

> A runtime for orchestrating reactive systems over time — not just a state management library.

This example shows that philosophy in its smallest complete form.

## Countdown and ValueListenable interoperability

Run `flutter run -t lib/countdown_interop.dart` from this directory. A scoped
controller owns a five-second elapsed-time countdown and a borrowing adapter.
Flutter's ValueListenableBuilder displays its value; Pause, Resume, Stop and Restart
exercise explicit timing controls. Unmounting the feature closes both resources.
The adapter never takes ownership of its source, and this example uses no storage.
