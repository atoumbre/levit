import 'dart:async';

/// An observable completion boundary shared by synchronous and stream fixtures.
/// Waiting belongs inside the timed run; verification must only inspect results.
class BenchmarkObserver<T> {
  T? value;
  int count = 0;
  T? _target;
  Completer<void>? _pending;

  void record(T next) {
    value = next;
    count++;
    if (_pending != null && next == _target) {
      _pending!.complete();
      _pending = null;
    }
  }

  Future<void> waitFor(T expected) {
    if (value == expected) return Future<void>.value();
    if (_pending != null) throw StateError('Overlapping benchmark iterations');
    _target = expected;
    final pending = _pending = Completer<void>();
    return pending.future.timeout(const Duration(seconds: 5));
  }
}
