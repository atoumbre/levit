import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../levit_monitor.dart';

/// A transport that writes [MonitorEvent]s to a file.
class FileTransport extends LevitTransport {
  final File _file;
  late final IOSink _sink;
  late final Future<void> _sinkDone;
  Future<void>? _closing;
  final List<AsyncError> _failures = [];

  /// Creates a new [FileTransport] writing to [filePath].
  FileTransport(String filePath) : _file = File(filePath) {
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
  void send(MonitorEvent event) {
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
  Future<void> close() => _closing ??= () async {
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
