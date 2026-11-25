part of '../monitor_library.dart';

/// A transport that broadcasts events to multiple underlying transports.
class LevitMultiTransport extends LevitTransport {
  /// The list of active transports.
  final List<LevitTransport> transports;

  /// Creates a [LevitMultiTransport] that delegates to the provided [transports].
  LevitMultiTransport(this.transports);

  @override
  int get droppedEvents =>
      transports.fold(0, (sum, transport) => sum + transport.droppedEvents);
  Future<void> _all(FutureOr<void> Function(LevitTransport) operation) async {
    final failures = <AsyncError>[];
    for (final transport in transports) {
      try {
        await operation(transport);
      } catch (error, stack) {
        failures.add(AsyncError(error, stack));
      }
    }
    if (failures.isNotEmpty) throw LevitMonitorException(failures);
  }

  @override
  Future<void> send(LevitMonitorEvent event) =>
      _all((transport) => transport.send(event.freeze()));
  @override
  Future<void> flush() => _all((transport) => transport.flush());
  @override
  Future<void> close() => _all((transport) => transport.close());

  @override
  Stream<void> get onConnect {
    // Surface a connect signal when any underlying transport reconnects.
    if (transports.isEmpty) return const Stream.empty();
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

    controller.onCancel = () async {
      for (final sub in subscriptions) {
        await sub.cancel();
      }
      subscriptions.clear();
    };

    return controller.stream;
  }
}
