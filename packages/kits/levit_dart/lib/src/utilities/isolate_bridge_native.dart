import 'dart:async';
import 'dart:isolate';

/// Platform-neutral send port abstraction backed by `dart:isolate`.
final class LevitIsolateSendPort {
  final SendPort _raw;

  /// Wraps a native [SendPort].
  const LevitIsolateSendPort(this._raw);

  /// Sends [message] across the isolate boundary.
  void send(Object? message) => _raw.send(message);
}

/// Platform-neutral receive port abstraction backed by `dart:isolate`.
final class LevitIsolateReceivePort {
  final ReceivePort _raw = ReceivePort();

  /// Returns the send port paired with this receive port.
  LevitIsolateSendPort get sendPort => LevitIsolateSendPort(_raw.sendPort);

  /// Subscribes to incoming messages from the isolate.
  StreamSubscription<dynamic> listen(void Function(dynamic message) onData) =>
      _raw.listen(onData);

  /// Closes the underlying receive port.
  void close() => _raw.close();
}

/// Creates a new isolate receive port.
LevitIsolateReceivePort createIsolateReceivePort() => LevitIsolateReceivePort();

/// Creates a remote error carrying [description] and [stackDescription].
Object createIsolateRemoteError(String description, String stackDescription) =>
    RemoteError(description, stackDescription);

/// Spawns a Dart isolate running [entryPoint] with [message].
Future<void> spawnDartIsolate<T>(
  void Function(T message) entryPoint,
  T message, {
  required LevitIsolateSendPort onError,
  required LevitIsolateSendPort onExit,
  bool errorsAreFatal = true,
  String? debugName,
}) => Isolate.spawn<T>(
  entryPoint,
  message,
  onError: onError._raw,
  onExit: onExit._raw,
  errorsAreFatal: errorsAreFatal,
  debugName: debugName,
);

/// Terminates the current isolate immediately.
Never exitCurrentIsolate() => Isolate.exit();
