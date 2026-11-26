import 'dart:async';

/// Unsupported send port stub for platforms without `dart:isolate`.
final class LevitIsolateSendPort {
  /// Sends [message] across the isolate boundary (unsupported on this platform).
  void send(Object? message) {
    throw UnsupportedError('Dart isolates are not supported on this platform.');
  }
}

/// Unsupported receive port stub for platforms without `dart:isolate`.
final class LevitIsolateReceivePort {
  /// Returns the paired send port (unsupported on this platform).
  LevitIsolateSendPort get sendPort =>
      throw UnsupportedError(
        'Dart isolates are not supported on this platform.',
      );

  /// Subscribes to incoming messages (unsupported on this platform).
  StreamSubscription<dynamic> listen(void Function(dynamic message) onData) =>
      throw UnsupportedError(
        'Dart isolates are not supported on this platform.',
      );

  /// Closes the receive port.
  void close() {}
}

/// Creates a new isolate receive port (throws [UnsupportedError] on web).
LevitIsolateReceivePort createIsolateReceivePort() =>
    throw UnsupportedError('Dart isolates are not supported on this platform.');

/// Creates a remote error carrying [description] and [stackDescription].
Object createIsolateRemoteError(String description, String stackDescription) =>
    StateError('$description\n$stackDescription');

/// Spawns a Dart isolate (throws [UnsupportedError] on web).
Future<void> spawnDartIsolate<T>(
  void Function(T message) entryPoint,
  T message, {
  required LevitIsolateSendPort onError,
  required LevitIsolateSendPort onExit,
  bool errorsAreFatal = true,
  String? debugName,
}) => Future<void>.error(
  UnsupportedError('Dart isolates are not supported on this platform.'),
);

/// Terminates the current isolate (throws [UnsupportedError] on web).
Never exitCurrentIsolate() =>
    throw UnsupportedError('Dart isolates are not supported on this platform.');
