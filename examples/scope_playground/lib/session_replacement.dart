import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

void main() {
  Levit.enableAutoLinking();
  runApp(const MaterialApp(home: SessionReplacementPage()));
}

final sessionLabel = LevitStore((ref) => ref.own('Guest'.lx));

class SessionConnection implements LevitDisposable {
  SessionConnection(
    this.name,
    this.events, {
    this.cleanupDelay = const Duration(seconds: 1),
  });
  final String name;
  final List<String> events;
  final Duration cleanupDelay;
  @override
  Future<void> dispose() async {
    events.add('closing:$name');
    await Future<void>.delayed(cleanupDelay);
    events.add('closed:$name');
  }
}

class SessionReplacementPage extends StatefulWidget {
  const SessionReplacementPage({
    super.key,
    this.lifecycle,
    this.events,
    this.cleanupDelay = const Duration(seconds: 1),
  });
  final LevitScopeLifecycleController? lifecycle;
  final List<String>? events;
  final Duration cleanupDelay;
  @override
  State<SessionReplacementPage> createState() => _SessionReplacementPageState();
}

class _SessionReplacementPageState extends State<SessionReplacementPage> {
  late final lifecycle = widget.lifecycle ?? LevitScopeLifecycleController();
  late final events = widget.events ?? <String>[];
  var session = 1;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Replace session during cleanup')),
    body: Column(
      children: [
        FilledButton(
          onPressed: () => setState(() => session++),
          child: const Text('Next session'),
        ),
        Expanded(
          child: LAsyncScope(
            lifecycle: lifecycle,
            args: [session],
            dependencyFactory: (scope) async {
              final label = 'Session $session';
              events.add('opened:$label');
              scope.put(
                () => SessionConnection(
                  label,
                  events,
                  cleanupDelay: widget.cleanupDelay,
                ),
              );
              scope.applyOverrides([
                sessionLabel.overrideWith((ref) => ref.own(label.lx)),
              ]);
            },
            loading: (context) =>
                const Center(child: Text('Waiting for session cleanup')),
            error: (context, error) => Column(
              children: [
                Text('Session failed: $error'),
                TextButton(
                  onPressed: lifecycle.retry,
                  child: const Text('Retry'),
                ),
              ],
            ),
            child: const SessionLabel(),
          ),
        ),
      ],
    ),
  );
}

class SessionLabel extends StatelessWidget {
  const SessionLabel({super.key});
  @override
  Widget build(BuildContext context) {
    final label = context.levit.findStore(sessionLabel);
    return Center(child: LWatch(() => Text(label.value)));
  }
}
