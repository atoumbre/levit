/// Platform-neutral WebSocket connection interface used by
/// `LevitWebSocketTransport`.
///
/// Built-in connectors use `dart:io` on VM/mobile/desktop and `dart:js_interop`
/// on web/Wasm without external package dependencies. Implement this interface
/// to inject a custom socket or test double via
/// `LevitWebSocketTransport.connect(..., connectionBuilder: ...)`.
abstract interface class LevitWebSocketConnection {
  /// Stream of incoming frames (typically JSON acknowledgement strings).
  Stream<Object?> get stream;

  /// Completes once the underlying WebSocket handshake succeeds, or completes
  /// with an error if the connection fails.
  Future<void> get ready;

  /// Sends a single text frame over the open connection.
  void send(String data);

  /// Closes the underlying connection and releases its resources.
  Future<void> close([int? code, String? reason]);
}
