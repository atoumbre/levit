import 'websocket_connection.dart';

/// Fallback connector for platforms without `dart:io` or `dart:js_interop`.
LevitWebSocketConnection connectWebSocket(Uri uri) {
  throw UnsupportedError(
    'No built-in WebSocket implementation is available on this platform. '
    'Supply a custom connectionBuilder to LevitWebSocketTransport.connect.',
  );
}
