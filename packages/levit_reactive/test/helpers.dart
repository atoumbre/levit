import 'dart:async';
import 'package:levit_reactive/levit_reactive.dart';

class User {
  final String name;
  final int age;
  User(this.name, this.age);
}

class MockObserver implements LevitReactiveObserver {
  final List<Stream> streams = [];
  final List<LevitReactiveNotifier> notifiers = [];
  final List<LxReactive> reactives = [];

  @override
  void addStream<T>(Stream<T> stream) {
    streams.add(stream);
  }

  @override
  void addNotifier(LevitReactiveNotifier notifier) {
    notifiers.add(notifier);
  }

  @override
  void addReactive(LxReactive reactive) {
    reactives.add(reactive);
  }
}

class TestMiddleware extends LevitReactiveMiddleware {
  final void Function(LevitReactiveChange)? onAfter;
  final bool allowChange;

  TestMiddleware({this.onAfter, this.allowChange = true});

  @override
  LxOnSet? get onSet => (next, reactive, change) {
        if (!allowChange) {
          return (value) {}; // Do nothing, blocking change
        }
        return (value) {
          next(value);
          onAfter?.call(change);
        };
      };
}

/// Middleware that uses the default wrapper implementation
class MinimalMiddleware extends LevitReactiveMiddleware {
  final List<LevitReactiveChange> changes = [];

  @override
  LxOnSet? get onSet => (next, reactive, change) {
        return (value) {
          next(value);
          changes.add(change);
        };
      };
}

class DefaultMiddleware extends LevitReactiveMiddleware {
  // Uses default implementation (pass-through)
}

/// Mutable user class for testing mutate()
class MutableUser {
  String name;
  int age;
  MutableUser(this.name, this.age);
}
