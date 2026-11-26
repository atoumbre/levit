/// Framework-independent helpers for isolated Levit tests.
///
/// Re-exports `package:levit_dart_core/levit_dart_core.dart` alongside
/// [LevitTestScope] and [LevitTestException].
library;

import 'dart:async';
import 'levit_dart_core.dart';
export 'levit_dart_core.dart';

/// Owns one test's isolated root [LevitScope], typed store overrides, and
/// explicitly tracked asynchronous work.
///
/// Register `await testScope.close()` in your test framework's teardown so
/// cleanup failures fail the test deterministically. [settle] waits on real
/// completion signals rather than arbitrary timers.
///
/// ```dart
/// late LevitTestScope testScope;
///
/// setUp(() {
///   testScope = LevitTestScope(
///     overrides: [
///       counterStore.overrideWith((ref) => ref.own(10.lx)),
///     ],
///   );
/// });
///
/// tearDown(() => testScope.close());
///
/// test('increments counter in isolation', () {
///   testScope.run(() {
///     final count = counterStore.find();
///     count.increment();
///     expect(count(), 11);
///   });
/// });
/// ```
///
/// {@category Testing}
base class LevitTestScope {
  /// The isolated root [LevitScope] owned by this test boundary.
  final LevitScope scope;
  final Set<Future<void>> _pending = {};
  final List<AsyncError> _errors = [];
  Future<void>? _closing;

  /// Creates an isolated root scope named [name] and applies [overrides].
  LevitTestScope({
    String name = 'test',
    Iterable<LevitOverride> overrides = const [],
  }) : scope = LevitScope.root(name) {
    scope.applyOverrides(overrides);
  }

  /// Runs [body] with [scope] bound as the active scope in the current [Zone].
  T run<T>(T Function() body) => scope.run(body);

  /// Tracks an asynchronous [operation] without consuming its result or hiding
  /// its error from callers.
  ///
  /// Any error from [operation] is also recorded for [settle] and [close].
  /// Throws a [StateError] if called after [close] has started.
  Future<T> track<T>(Future<T> operation) {
    if (_closing != null) throw StateError('Test scope is closing.');
    late final Future<void> observed;
    observed = operation
        .then<void>(
          (_) {},
          onError: (Object error, StackTrace stack) {
            _errors.add(AsyncError(error, stack));
          },
        )
        .whenComplete(() => _pending.remove(observed));
    _pending.add(observed);
    return operation;
  }

  /// Waits until all [track]ed operations and pending scope initializations
  /// have completed, then throws [LevitTestException] if any errors were
  /// recorded.
  Future<void> settle() async {
    do {
      await Future.wait(_pending.toList());
      await scope.waitForInitialization();
    } while (_pending.isNotEmpty);
    if (_errors.isNotEmpty) throw LevitTestException(_errors);
  }

  /// Disposes [scope], awaits all tracked work via [settle], and throws
  /// [LevitTestException] if any task or teardown error occurred.
  ///
  /// Idempotent: subsequent calls return the same [Future].
  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    final errors = <AsyncError>[];
    // Disposal signals cancellation before waiting for test-tracked operations.
    final cleanup = scope.dispose().catchError((
      Object error,
      StackTrace stack,
    ) {
      errors.add(AsyncError(error, stack));
    });
    try {
      await settle();
    } catch (error, stack) {
      errors.add(AsyncError(error, stack));
    }
    await cleanup;
    if (errors.isNotEmpty) throw LevitTestException(errors);
  }
}

/// Aggregate exception containing all task and teardown failures observed in a
/// [LevitTestScope].
///
/// {@category Testing}
final class LevitTestException implements Exception {
  /// Unmodifiable list of asynchronous failures collected before or during
  /// teardown.
  final List<AsyncError> failures;

  /// Creates a test exception from [failures].
  LevitTestException(Iterable<AsyncError> failures)
    : failures = List.unmodifiable(failures);
  @override
  String toString() =>
      'LevitTestException: ${failures.map((failure) => failure.error).join('; ')}';
}
