import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../levit_monitor.dart';

/// An IO-only transport that appends frozen [LevitMonitorEvent]s to a file as
/// newline-delimited JSON (NDJSON).
///
/// Available from `package:levit_monitor/levit_monitor_io.dart` (not supported
/// in browser builds). Asynchronous `IOSink` errors are recorded immediately
/// and surfaced as [LevitMonitorException] on [flush] or [close]. Calling
/// [send] after [close] starts throws a [StateError].
///
/// ```dart
/// import 'package:levit_monitor/levit_monitor_io.dart';
///
/// await LevitMonitor.attach(
///   transport: LevitFileTransport('logs/levit_events.ndjson'),
/// );
/// ```
///
/// {@category Middleware & Monitoring}
class LevitFileTransport extends LevitTransport {
  final File _file;
  late final IOSink _sink;
  late final Future<void> _sinkDone;
  Future<void>? _closing;
  final List<AsyncError> _failures = [];

  /// Creates a [LevitFileTransport] opening [filePath] in [FileMode.append].
  LevitFileTransport(String filePath) : _file = File(filePath) {
    _sink = _file.openWrite(mode: FileMode.append);
    // Observe asynchronous IO failures immediately, even before flush/close.
    _sinkDone = _sink.done.then<void>((_) {}, onError: _recordFailure);
  }

  void _recordFailure(Object error, StackTrace stack) {
    if (_failures.length < 32) _failures.add(AsyncError(error, stack));
  }

  @override
  Stream<void> get onConnect => const Stream<void>.empty();

  @override
  void send(LevitMonitorEvent event) {
    if (_closing != null) throw StateError('File transport is closing.');
    _sink.writeln(jsonEncode(event.freeze().toJson()));
  }

  @override
  Future<void> flush() async {
    try {
      await _sink.flush();
    } catch (error, stack) {
      _recordFailure(error, stack);
    }
    if (_failures.isNotEmpty) throw LevitMonitorException(_failures);
  }

  @override
  Future<void> close() =>
      _closing ??= () async {
        try {
          await flush();
        } catch (_) {
          /* Recorded; still release the sink. */
        }
        try {
          await _sink.close();
        } catch (error, stack) {
          _recordFailure(error, stack);
        }
        await _sinkDone;
        if (_failures.isNotEmpty) throw LevitMonitorException(_failures);
      }();
}
