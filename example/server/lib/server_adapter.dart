import 'dart:io' as io;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Adapter to allow mocking static io.serve.
///
/// This class abstracts the `shelf_io.serve` call, making it possible to
/// test the server startup logic without actually binding to a port or
/// requiring a real network interface.
class ServerAdapter {
  /// Starts an HTTP server.
  ///
  /// *   [handler]: The shelf handler to serve.
  /// *   [address]: The address to bind to (e.g., 'localhost', '0.0.0.0').
  /// *   [port]: The port to listen on.
  Future<io.HttpServer> serve(shelf.Handler handler, Object address, int port) {
    return shelf_io.serve(handler, address, port);
  }
}
