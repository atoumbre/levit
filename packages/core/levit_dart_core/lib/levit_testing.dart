/// Framework-independent helpers for isolated Levit tests.
library;

import 'dart:async';
import 'levit_dart_core.dart';
export 'levit_dart_core.dart';

/// Owns one test's scope, overrides and explicitly tracked asynchronous work.
/// Register [close] in the test framework's teardown, and await it so cleanup
/// failures fail the test. [settle] uses completion signals, not timer guesses.
final class LevitTestScope {
  final LevitScope scope;
  final Set<Future<void>> _pending = {};
  final List<AsyncError> _errors = [];
  Future<void>? _closing;

  LevitTestScope({
    String name = 'test',
    Iterable<LevitOverride> overrides = const [],
  }) : scope = LevitScope.root(name) {
    scope.applyOverrides(overrides);
  }

  T run<T>(T Function() body) => scope.run(body);

  /// Tracks a task without consuming its result or hiding its error from callers.
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

  Future<void> settle() async {
    do {
      await Future.wait(_pending.toList());
      await scope.waitForInitialization();
    } while (_pending.isNotEmpty);
    if (_errors.isNotEmpty) throw LevitTestException(_errors);
  }

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

/// All observed task and teardown failures from a test boundary.
final class LevitTestException implements Exception {
  final List<AsyncError> failures;
  LevitTestException(Iterable<AsyncError> failures)
    : failures = List.unmodifiable(failures);
  @override
  String toString() =>
      'LevitTestException: ${failures.map((failure) => failure.error).join('; ')}';
}
