import 'dart:async';
import 'package:levit_reactive/levit_reactive.dart';

class User {
  final String name;
  final int age;
  User(this.name, this.age);
}

class MockObserver implements LevitStateObserver {
  final List<Stream> streams = [];
  final List<LevitStateNotifier> notifiers = [];
  final List<LxReactive> reactives = [];

  @override
  void addStream<T>(Stream<T> stream) {
    streams.add(stream);
  }

  @override
  void addNotifier(LevitStateNotifier notifier) {
    notifiers.add(notifier);
  }

  @override
  void addReactive(LxReactive reactive) {
    reactives.add(reactive);
  }
}

class TestMiddleware extends LevitStateMiddleware {
  final void Function(LevitStateChange)? onAfter;
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
class MinimalMiddleware extends LevitStateMiddleware {
  final List<LevitStateChange> changes = [];

  @override
  LxOnSet? get onSet => (next, reactive, change) {
        return (value) {
          next(value);
          changes.add(change);
        };
      };
}

class DefaultMiddleware extends LevitStateMiddleware {
  // Uses default implementation (pass-through)
}

/// Mutable user class for testing mutate()
class MutableUser {
  String name;
  int age;
  MutableUser(this.name, this.age);
}
