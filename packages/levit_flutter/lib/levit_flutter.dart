/// Flutter widgets for the Levit framework.
///
/// This library provides the integration layer between Levit's core reactive/DI
/// systems and Flutter's widget tree.
///
/// It enables:
/// *   **Automatic UI Updates**: Widgets that rebuild when reactive state changes ([LWatch]).
/// *   **Dependency Injection**: Widgets that manage controller lifecycles and scoping ([LScope], [LMultiScope]).
/// *   **Async State Handling**: Unified builders for futures, streams, and async computed values ([LStatusBuilder]).
///
/// ## Key Widgets
///
/// *   **[LWatch]**: The primary building block for reactive UIs. It automatically detects
///     which reactive variables are accessed during its build and subscribes to them.
/// *   **[LScope]**: Provides a local dependency injection scope. Controllers registered
///     here are automatically disposed when the widget is removed.
/// *   **[LView]**: A convenient base class for stateless widgets that need access
///     to a controller.
/// *   **[LStatusBuilder]**: A powerful widget for handling the various states of asynchronous
///     operations (Idle, Waiting, Success, Error).
library;

export 'package:levit_dart/levit_dart.dart';

export 'src/scope.dart'
    hide LMultiScopeElement, LScopedViewElement, LScopeElement;
export 'src/status_builder.dart';
export 'src/view.dart';
export 'src/watch.dart' hide LConsumerElement, LWatchElement;
