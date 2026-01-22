import 'dart:convert';
import 'dart:io';

import '../core/event.dart';
import '../core/transport.dart';

/// A transport that writes [MonitorEvent]s to a file.
class FileTransport implements LevitTransport {
  final File _file;
  late final IOSink _sink;

  /// Creates a new [FileTransport] writing to [filePath].
  FileTransport(String filePath) : _file = File(filePath) {
    _sink = _file.openWrite(mode: FileMode.append);
  }

  @override
  void send(MonitorEvent event) {
    final category = switch (event) {
      ReactiveEvent _ || ReactiveBatchEvent _ => 'state',
      DependencyEvent _ => 'di',
    };

    _sink.writeln(jsonEncode({
      'category': category,
      ...event.toJson(),
    }));
  }

  @override
  void close() {
    _sink.close();
  }
}
