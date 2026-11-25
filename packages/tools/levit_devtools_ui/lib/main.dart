import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'export_stub.dart' if (dart.library.js_interop) 'export_web.dart';
import 'package:levit_monitor/spi.dart';

void main() => runApp(const InspectorApp());

class InspectorApp extends StatelessWidget {
  const InspectorApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Levit Inspector',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff326b59),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    ),
    home: const InspectorScreen(),
  );
}

/// Live read-only projection. Tests can inject a channel and deterministic data.
class InspectorScreen extends StatefulWidget {
  const InspectorScreen({super.key, this.channelFactory});
  final WebSocketChannel Function(Uri)? channelFactory;
  @override
  State<InspectorScreen> createState() => _InspectorScreenState();
}

class _InspectorScreenState extends State<InspectorScreen> {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retry;
  final _state = LevitStateSnapshot();
  List<Map<String, dynamic>> _sessions = [];
  Map<String, dynamic>? _session;
  final List<Map<String, dynamic>> _events = [];
  Map<String, dynamic>? _selectedEvent;
  String? _selected;
  String _connection = 'Connecting';
  String _filter = '';
  String _category = 'all';
  int _view = 0;
  int _viewerDrops = 0;
  @override
  void initState() {
    super.initState();
    _connect();
  }

  void _connect() {
    _retry?.cancel();
    final base = Uri.base;
    final uri = Uri(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      host: base.host.isEmpty ? '127.0.0.1' : base.host,
      port: base.hasPort ? base.port : 9200,
      path: '/inspect',
    );
    try {
      final channel =
          widget.channelFactory?.call(uri) ?? WebSocketChannel.connect(uri);
      _channel = channel;
      _subscription = channel.stream.listen(
        _receive,
        onError: (Object _) => _disconnected(),
        onDone: _disconnected,
      );
      channel.ready.then(
        (_) {
          if (!mounted || _channel != channel) return;
          setState(() => _connection = 'Connected');
          if (_selected != null) _select(_selected!);
        },
        onError: (Object _) {
          if (mounted && _channel == channel) _disconnected();
        },
      );
    } catch (_) {
      _disconnected();
    }
  }

  void _disconnected() {
    if (!mounted || _retry?.isActive == true) return;
    final subscription = _subscription;
    _subscription = null;
    final channel = _channel;
    _channel = null;
    unawaited(subscription?.cancel());
    unawaited(channel?.sink.close());
    setState(() => _connection = 'Disconnected · reconnecting');
    _retry = Timer(const Duration(seconds: 1), _connect);
  }

  void _receive(dynamic raw) {
    if (!mounted || raw is! String) return;
    try {
      final message = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      setState(() {
        _viewerDrops = message['viewerDrops'] as int? ?? 0;
        if (message['kind'] == 'sessions') {
          _sessions = (message['sessions'] as List)
              .map((value) => Map<String, dynamic>.from(value as Map))
              .toList();
          if (_selected == null && _sessions.isNotEmpty) {
            _select(_sessions.first['id'] as String);
          }
          if (_selected != null &&
              !_sessions.any((session) => session['id'] == _selected)) {
            _selected = null;
            _session = null;
            _events.clear();
          }
        } else if (message['kind'] == 'snapshot') {
          final session = Map<String, dynamic>.from(message['session'] as Map);
          if (session['id'] != _selected) return;
          _session = session;
          if (message['sessions'] case final List sessions) {
            _sessions = sessions
                .map((value) => Map<String, dynamic>.from(value as Map))
                .toList();
          }
          _restore(Map<String, dynamic>.from(message['state'] as Map));
          _events
            ..clear()
            ..addAll(
              (message['timeline'] as List).map(
                (event) => Map<String, dynamic>.from(event as Map),
              ),
            );
          if (_events.length > 1000) {
            _events.removeRange(0, _events.length - 1000);
          }
        } else if (message['kind'] == 'event') {
          final session = Map<String, dynamic>.from(message['session'] as Map);
          if (session['id'] != _selected) return;
          _session = session;
          final data = Map<String, dynamic>.from(message['event'] as Map);
          _state.applyEnvelope(LevitEventEnvelope(data));
          if (data['type'] != 'snapshot') {
            _events.add(data);
            if (_events.length > 1000) _events.removeAt(0);
          }
        }
      });
      _channel?.sink.add(jsonEncode({'ack': message['delivery']}));
    } catch (_) {
      _disconnected();
    }
  }

  void _restore(Map<String, dynamic> state) => _state.applyEnvelope(
    LevitEventEnvelope({
      'category': 'snapshot',
      'type': 'snapshot',
      'sessionId': _selected ?? '',
      'seq': 0,
      'timestamp': DateTime.now().toIso8601String(),
      'state': state,
    }),
  );
  void _select(String id) {
    _selected = id;
    _selectedEvent = null;
    _events.clear();
    _session = null;
    _restore({'scopes': [], 'dependencies': [], 'variables': []});
    _channel?.sink.add(jsonEncode({'select': id}));
  }

  @override
  void dispose() {
    _retry?.cancel();
    unawaited(_subscription?.cancel());
    unawaited(_channel?.sink.close());
    super.dispose();
  }

  bool _matches(Object value) =>
      _filter.isEmpty || value.toString().toLowerCase().contains(_filter);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Levit Inspector'),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(child: Text(_connection)),
        ),
        TextButton.icon(
          onPressed: _selected == null
              ? null
              : () => downloadExport(
                  '/export?session=${Uri.encodeQueryComponent(_selected!)}',
                ),
          icon: const Icon(Icons.download),
          label: const Text('Export JSON'),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue:
                      _sessions.any((session) => session['id'] == _selected)
                      ? _selected
                      : null,
                  key: ValueKey(_selected),
                  decoration: const InputDecoration(
                    labelText: 'Application session',
                    border: OutlineInputBorder(),
                  ),
                  items: _sessions
                      .map(
                        (session) => DropdownMenuItem(
                          value: session['id'] as String,
                          child: Text(
                            '${session['appId']} · ${session['id']} ${session['connected'] == true ? '●' : '○'}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (id) {
                    if (id != null) setState(() => _select(id));
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Filter names, IDs or event data',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) =>
                      setState(() => _filter = value.toLowerCase()),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'State snapshots recover current state. Timeline is bounded and may be incomplete. '
              'Producer drops: ${_session?['producerDrops'] ?? 0} · History evictions: ${_session?['droppedHistory'] ?? 0} · '
              'Sequence gaps: ${_session?['missingSequences'] ?? 0} · Viewer drops: $_viewerDrops',
            ),
          ),
        ),
        Expanded(
          child: _selected == null
              ? const Center(
                  child: Text(
                    'Waiting for applications on ws://127.0.0.1:9200/ws',
                  ),
                )
              : Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _view,
                      onDestinationSelected: (value) =>
                          setState(() => _view = value),
                      labelType: NavigationRailLabelType.all,
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.account_tree),
                          label: Text('Ownership'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.hub),
                          label: Text('Reactions'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.task_alt),
                          label: Text('Tasks'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.hourglass_bottom),
                          label: Text('Cleanup'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.timeline),
                          label: Text('Timeline'),
                        ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: switch (_view) {
                        0 => _ownership(),
                        1 => _reactions(),
                        2 => _tasks(),
                        3 => _cleanup(),
                        _ => _timeline(),
                      },
                    ),
                  ],
                ),
        ),
      ],
    ),
  );
  Widget _ownership() {
    final scopes = _state.scopes.values.toList();
    final rendered = <int>{};
    Widget node(LevitScopeModel scope, Set<int> seen) {
      if (seen.contains(scope.id)) return const Text('Scope ancestry cycle');
      rendered.add(scope.id);
      final next = {...seen, scope.id};
      final dependencies = _state.dependencies.values.where(
        (dep) => dep.scopeId == scope.id,
      );
      return ExpansionTile(
        initiallyExpanded: true,
        title: Text('${scope.name} #${scope.id}'),
        subtitle: Text(
          scope.progress['isClosing'] == true
              ? 'Closing · dependencies remain owned until cleanup completes'
              : '${dependencies.length} registrations',
        ),
        children: [
          for (final dep in dependencies.where((dep) => _matches(dep.key)))
            ListTile(
              title: Text(dep.key),
              subtitle: Text(
                '${dep.status.name} · ${dep.type.name} · ${dep.isFactory ? 'factory' : 'singleton'}',
              ),
              trailing: Text(
                '${_state.variables.values.where((value) => value.scopeId == scope.id && value.ownerKey == dep.key).length} reactive values',
              ),
            ),
          for (final child in scopes.where(
            (child) => child.parentScopeId == scope.id,
          ))
            Padding(
              padding: const EdgeInsets.only(left: 18),
              child: node(child, next),
            ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Scopes own registrations; controllers own their reactive resources.',
          style: TextStyle(fontSize: 18),
        ),
        if (scopes.isEmpty)
          const ListTile(
            title: Text(
              'No scope events yet. Attach monitoring before creating application scopes.',
            ),
          ),
        for (final scope in scopes.where(
          (scope) =>
              scope.parentScopeId == null ||
              !scopes.any((parent) => parent.id == scope.parentScopeId),
        ))
          node(scope, {}),
        // A disconnected cycle has no root. Render it too so malformed ancestry
        // is diagnosed instead of silently hiding an entire ownership component.
        for (final scope in scopes.where(
          (scope) => !rendered.contains(scope.id),
        ))
          node(scope, {}),
        for (final variable in _state.variables.values.where(
          (value) =>
              _matches(value.name) &&
              (value.scopeId == null ||
                  !_state.scopes.containsKey(value.scopeId)),
        ))
          ListTile(
            title: Text('${variable.name} #${variable.id}'),
            subtitle: Text(
              'Owner: ${variable.ownerId ?? 'unassigned'} · ${variable.valueType ?? ''}',
            ),
          ),
      ],
    );
  }

  Widget _reactions() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text(
        'Dependency and reaction relationships',
        style: TextStyle(fontSize: 18),
      ),
      for (final value in _state.variables.values.where(
        (value) => _matches('${value.name} ${value.id} ${value.ownerId}'),
      ))
        Card(
          child: ListTile(
            title: Text('${value.name} #${value.id}'),
            subtitle: Text(
              'Value: ${value.value}\nOwner: ${value.ownerId ?? 'unassigned'}\n'
              'Reads: ${value.dependencies.map((id) => '${_state.variables[id]?.name ?? '?'} #$id').join(', ')}\n'
              'Listeners: ${value.listenerCount} · Read by: ${_state.variables.values.where((consumer) => consumer.dependencies.contains(value.id)).map((consumer) => consumer.name).join(', ')}',
            ),
            onTap: () => setState(() {
              _filter = value.id.toString();
              _view = 4;
            }),
          ),
        ),
    ],
  );
  Widget _tasks() {
    final trees = _state.taskTrees.values;
    Widget tree(Map<String, dynamic> group) => ExpansionTile(
      initiallyExpanded: true,
      title: Text('${group['name']} · ${group['id']}'),
      subtitle: Text(
        'Pending ${group['pendingCount']} · Running ${group['runningCount']} · '
        'Deadline ${group['deadline'] ?? 'none'} · Cancellation ${group['cancellationReason'] ?? 'none'}',
      ),
      children: [
        for (final id in group['executionIds'] as List? ?? [])
          ListTile(title: Text('Execution $id')),
        for (final child in group['children'] as List? ?? [])
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: tree(Map<String, dynamic>.from(child as Map)),
          ),
      ],
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Task groups and executions',
          style: TextStyle(fontSize: 18),
        ),
        if (trees.isEmpty)
          const ListTile(
            title: Text('No task adapter attached'),
            subtitle: Text(
              'Attach the optional application adapter to the engines you want to inspect.',
            ),
          ),
        for (final entry in trees.where(_matches))
          tree(Map<String, dynamic>.from(entry['tree'] as Map)),
      ],
    );
  }

  Widget _cleanup() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text(
        'Initialization and pending cleanup',
        style: TextStyle(fontSize: 18),
      ),
      for (final scope in _state.scopes.values.where(
        (scope) =>
            scope.progress['isClosing'] == true ||
            (scope.progress['pendingInitializations'] as int? ?? 0) > 0 ||
            (scope.progress['registrations'] as List? ?? []).any(
              (r) =>
                  r['isClosing'] == true ||
                  (r['pendingInitializations'] as int? ?? 0) > 0,
            ),
      ))
        Card(
          child: ListTile(
            title: Text('${scope.name} #${scope.id}'),
            subtitle: SelectableText(
              const JsonEncoder.withIndent('  ').convert(scope.progress),
            ),
          ),
        ),
      const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'A cancellation request is not completed cleanup. Closing scopes remain visible until their resources finish.',
        ),
      ),
    ],
  );
  Widget _timeline() {
    final filtered = _events.reversed
        .where(
          (event) =>
              (_category == 'all' || event['category'] == _category) &&
              _matches(event),
        )
        .toList();
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              Wrap(
                spacing: 8,
                children: [
                  for (final category in [
                    'all',
                    'state',
                    'di',
                    'custom',
                    'log',
                  ])
                    ChoiceChip(
                      label: Text(category),
                      selected: _category == category,
                      onSelected: (_) => setState(() => _category = category),
                    ),
                ],
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final event = filtered[index];
                    return ListTile(
                      selected: identical(event, _selectedEvent),
                      title: Text(
                        '#${event['seq']} ${event['type']} ${event['name'] ?? event['key'] ?? ''}',
                      ),
                      subtitle: Text(
                        event['type'] == 'state_change'
                            ? '${event['oldValue']} → ${event['newValue']} · owner ${event['ownerId'] ?? 'unassigned'}'
                            : '${event['timestamp']}',
                      ),
                      onTap: () => setState(() => _selectedEvent = event),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        if (_selectedEvent != null)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Update details', style: TextStyle(fontSize: 18)),
                  TextButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy redacted event'),
                    onPressed: () => Clipboard.setData(
                      ClipboardData(
                        text: const JsonEncoder.withIndent(
                          '  ',
                        ).convert(_selectedEvent),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: SelectableText(
                        const JsonEncoder.withIndent(
                          '  ',
                        ).convert(_selectedEvent),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
