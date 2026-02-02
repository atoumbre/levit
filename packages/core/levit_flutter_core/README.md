# levit_flutter_core

[![Pub Version](https://img.shields.io/pub/v/levit_flutter_core)](https://pub.dev/packages/levit_flutter_core)
[![Platforms](https://img.shields.io/badge/platforms-flutter-blue)](https://pub.dev/packages/levit_flutter_core)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/atoumbre/levit/graph/badge.svg?token=AESOtS4YPg&flags=levit_flutter_core)](https://codecov.io/github/atoumbre/levit)

**The essential Flutter bindings for the Levit ecosystem.**

`levit_flutter_core` connects your reactive business logic (`levit_reactive`) and dependency injection (`levit_scope`) directly to the Flutter widget tree. It provides widgets for **Listening** to state and **Providing** dependencies.

---

## Why use this?

Flutter is declarative; your state management should be too. `levit_flutter_core` offers:

*   **Granular Rebuilds**: `LWatch` rebuilds *only* what changed. No `setState` spaghetti.
*   **Scoped Access**: `LScope` provides dependencies strictly to its subtree.
*   **Automatic Disposal**: Resources are cleaned up as soon as widgets leave the screen.
*   **Zero-Boilerplate Views**: `LView` resolves controllers automatically.

---

## Core Widgets

### 1. The Watcher: `LWatch`
The bread and butter of your UI. Wraps any widget and rebuilds it when reactive state changes.

```dart
// Controller
final count = 0.lx;

// UI
LWatch(() {
  return Text("Count: ${count.value}");
});
```

### 2. The Provider: `LScope`
Creates a dependency injection container tied to the widget tree.

```dart
LScope.put(
  () => ProfileController(),
  child: const ProfilePage(),
)
```

### 3. The Connector: `LView`
A base class for pages or complex widgets. It finds your controller and builds the UI.

```dart
class HomePage extends LView<HomeController> {
  @override
  Widget buildView(BuildContext context, HomeController controller) {
    return Scaffold(
      appBar: AppBar(title: Text(controller.title())), 
      body: LWatch(() => Text(controller.userData())),
    );
  }
}
```

---

## Advanced Usage

### Async Views
For screens that depend on async data (like user profiles), use `LAsyncView` or `LAsyncScopedView`.

```dart
LAsyncView.put(
  () async => await UserService.loadProfile(),
  loading: (context) => const CircularProgressIndicator(),
  error: (context, err) => Text('Error: $err'),
  builder: (context, controller) => ProfileContent(controller),
);
```

### Status Builders
For reactive variables that represent network states (`LxStatus`), use `LStatusBuilder`.

```dart
LStatusBuilder(
  controller.userStatus,
  onWaiting: () => const Spinner(),
  onError: (err, stack) => ErrorPage(err),
  onSuccess: (user) => Text('Welcome ${user.name}'),
);
```

---

## Installation

This package is usually installed as a transitive dependency of `levit`.

```yaml
dependencies:
  levit: ^latest
```

If you are building a Flutter package that depends on Levit but not the full framework, you can depend on it directly:

```yaml
dependencies:
  levit_flutter_core: ^latest
```
