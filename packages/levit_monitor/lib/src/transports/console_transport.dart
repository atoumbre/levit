import '../core/event.dart';
import '../core/transport.dart';

/// A transport that prints events to the console with enhanced formatting.
class ConsoleTransport implements LevitTransport {
  /// Whether to output ANSI color codes.
  final bool useColors;

  /// Optional prefix for log lines.
  final String prefix;

  /// Creates a new [ConsoleTransport].
  const ConsoleTransport({
    this.useColors = true,
    this.prefix = '[Levit]',
  });

  @override
  void send(MonitorEvent event) {
    final color = useColors ? _colorFor(event) : '';
    final reset = useColors ? '\x1B[0m' : '';
    final icon = _iconFor(event);

    switch (event) {
      case StateChangeEvent e:
        print(
            '$color$icon $prefix VAL: ${e.reactive.name ?? 'Anon'} -> ${e.change.newValue}$reset');
      case BatchEvent e:
        print(
            '$color$icon $prefix BATCH: ${e.change.batchId} (${e.change.length} changes)$reset');
      case ReactiveInitEvent e:
        print(
            '$color$icon $prefix INIT: ${e.reactive.name ?? 'Anon'} = ${e.reactive.value}$reset');
      case ReactiveDisposeEvent e:
        print(
            '$color$icon $prefix DISPOSE: ${e.reactive.name ?? 'Anon'}$reset');
      case GraphChangeEvent e:
        print(
            '$color$icon $prefix GRAPH: ${e.reactive.name} dependencies changed$reset');
      case DIRegisterEvent e:
        print(
            '$color$icon $prefix DI: REGISTER ${e.key} in ${e.scopeName}#${e.scopeId} (${e.source})$reset');
      case DIResolveEvent e:
        print(
            '$color$icon $prefix DI: RESOLVE ${e.key} in ${e.scopeName}#${e.scopeId} (${e.source})$reset');
      case DIDeleteEvent e:
        print(
            '$color$icon $prefix DI: DELETE ${e.key} from ${e.scopeName}#${e.scopeId} (${e.source})$reset');
      case DIInstanceCreateEvent e:
        print('$color$icon $prefix DI: CREATE ${e.key}$reset');
      case DIInstanceInitEvent e:
        print('$color$icon $prefix DI: INIT ${e.key}$reset');
    }
  }

  String _colorFor(MonitorEvent event) {
    return switch (event) {
      StateChangeEvent _ => '\x1B[36m', // Cyan
      BatchEvent _ => '\x1B[35m', // Magenta
      DIEvent e => _diColor(e),
      ReactiveEvent _ => '\x1B[33m', // Yellow
    };
  }

  String _diColor(DIEvent event) {
    return switch (event) {
      DIRegisterEvent _ => '\x1B[32m', // Green
      DIResolveEvent _ => '\x1B[34m', // Blue
      DIDeleteEvent _ => '\x1B[31m', // Red
      _ => '\x1B[32m',
    };
  }

  String _iconFor(MonitorEvent event) {
    return switch (event) {
      StateChangeEvent _ => '⚡',
      BatchEvent _ => '🔗',
      DIRegisterEvent _ => '📦',
      DIResolveEvent _ => '🔍',
      DIDeleteEvent _ => '🗑️',
      ReactiveEvent _ => '⚙️',
      DIEvent _ => '🛠️',
    };
  }

  @override
  void close() {}
}
