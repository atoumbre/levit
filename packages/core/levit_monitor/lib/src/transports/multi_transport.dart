part of '../../levit_monitor.dart';

/// A transport that broadcasts events to multiple underlying transports.
class MultiTransport implements LevitTransport {
  /// The list of active transports.
  final List<LevitTransport> transports;

  /// Creates a [MultiTransport] that delegates to the provided [transports].
  MultiTransport(this.transports);

  @override
  void send(MonitorEvent event) {
    for (final transport in transports) {
      try {
        transport.send(event);
      } catch (e) {
        // Suppress errors from individual transports to prevent disrupting others
        print('Error sending event to transport ${transport.runtimeType}: $e');
      }
    }
  }

  @override
  Future<void> close() async {
    for (final transport in transports) {
      try {
        await transport.close();
      } catch (e) {
        print('Error closing transport ${transport.runtimeType}: $e');
      }
    }
  }

  @override
  Stream<void> get onConnect {
    // Merge onConnect streams from all transports
    if (transports.isEmpty) return const Stream.empty();

    // We want to notify if ANY transport connects.
    // Ideally, we might want to merge them.
    final controller = StreamController<void>.broadcast();
    final subscriptions = <StreamSubscription>[];

    void onData(dynamic _) {
      if (!controller.isClosed) {
        controller.add(null);
      }
    }

    controller.onListen = () {
      for (final transport in transports) {
        subscriptions.add(transport.onConnect.listen(onData));
      }
    };

    controller.onCancel = () {
      for (final sub in subscriptions) {
        sub.cancel();
      }
      subscriptions.clear();
    };

    return controller.stream;
  }
}
