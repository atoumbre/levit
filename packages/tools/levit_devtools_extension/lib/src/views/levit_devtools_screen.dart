import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:levit_monitor/spi.dart';

import '../client/devtools_client.dart';
import '../controller/inspector_controller.dart';
import 'diagnostics_view.dart';
import 'reactive_graph_view.dart';
import 'scope_tree_view.dart';
import 'task_tree_view.dart';
import 'timeline_view.dart';

/// Main Flutter DevTools tab for inspecting a live Levit application.
class LevitDevToolsScreen extends StatelessWidget {
  final LevitDevToolsClient client;
  final bool ownsClient;

  const LevitDevToolsScreen({
    super.key,
    required this.client,
    this.ownsClient = false,
  });

  @override
  Widget build(BuildContext context) {
    return LScopedView<LevitInspectorController>.put(
      () => LevitInspectorController(client, ownsClient: ownsClient),
      autoWatch: false,
      builder: (context, controller) => _LevitDevToolsShell(controller),
    );
  }
}

class _LevitDevToolsShell extends StatefulWidget {
  final LevitInspectorController controller;

  const _LevitDevToolsShell(this.controller);

  @override
  State<_LevitDevToolsShell> createState() => _LevitDevToolsShellState();
}

class _LevitDevToolsShellState extends State<_LevitDevToolsShell>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final LxWorker<int> _tabSyncWorker;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging &&
          widget.controller.activeTabIndex.value != _tabController.index) {
        widget.controller.activeTabIndex.value = _tabController.index;
      }
    });
    _tabSyncWorker = LxWorker<int>(widget.controller.activeTabIndex, (index) {
      if (_tabController.index != index) {
        _tabController.animateTo(index);
      }
    });
  }

  @override
  void dispose() {
    _tabSyncWorker.close();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      body: Column(
        children: [
          _HeaderToolbar(controller: controller),
          const Divider(height: 1),
          Expanded(
            child: LWatch(() {
              controller.revision();
              final isAttached = controller.attached();
              final isLoading = controller.loading();
              if (!isAttached) {
                return _UnattachedEmptyState(
                  loading: isLoading,
                  error: controller.errorMessage(),
                  onRetry: controller.refresh,
                );
              }
              final findingsCount = controller.findings.length;
              return Column(
                children: [
                  Material(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: [
                        Tab(
                          text: 'Scopes (${controller.snapshot.scopes.length})',
                        ),
                        Tab(
                          text:
                              'Reactives (${controller.snapshot.variables.length})',
                        ),
                        Tab(
                          text:
                              'Tasks (${controller.snapshot.taskTrees.length})',
                        ),
                        Tab(
                          text:
                              'Timeline (${controller.snapshot.events.length})',
                        ),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Diagnostics'),
                              if (findingsCount > 0) ...[
                                const SizedBox(width: 6),
                                _CountBadge(
                                  count: findingsCount,
                                  hasError: controller.findings.any(
                                    (f) =>
                                        f.severity ==
                                        LevitDiagnosticSeverity.error,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        ScopeTreeView(controller: controller),
                        ReactiveGraphView(controller: controller),
                        TaskTreeView(controller: controller),
                        TimelineView(controller: controller),
                        DiagnosticsView(controller: controller),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _HeaderToolbar extends StatelessWidget {
  final LevitInspectorController controller;

  const _HeaderToolbar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: LWatch(() {
        controller.revision();
        final isAttached = controller.attached();
        final isPaused = controller.paused();
        final queued = controller.pausedCount();
        final findings = isAttached ? controller.findings : const [];

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.hub_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Levit Inspector',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            Chip(
              avatar: Icon(
                isAttached ? Icons.check_circle : Icons.link_off,
                size: 16,
                color: isAttached ? Colors.green : Colors.orange,
              ),
              label: Text(
                isAttached ? 'Connected (Read-Only)' : 'Not Attached',
              ),
              visualDensity: VisualDensity.compact,
            ),
            if (isAttached) ...[
              OutlinedButton.icon(
                onPressed: controller.togglePause,
                icon: Icon(isPaused ? Icons.play_arrow : Icons.pause, size: 16),
                label: Text(
                  isPaused
                      ? 'Resume${queued > 0 ? ' (+$queued)' : ''}'
                      : 'Pause',
                ),
              ),
              OutlinedButton.icon(
                onPressed: controller.loading() ? null : controller.refresh,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final json = controller.exportRedactedJson();
                  await Clipboard.setData(ClipboardData(text: json));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied redacted snapshot JSON.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.copy_all, size: 16),
                label: const Text('Copy JSON'),
              ),
              if (findings.isNotEmpty)
                ActionChip(
                  avatar: Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color:
                        findings.any(
                              (f) =>
                                  f.severity == LevitDiagnosticSeverity.error,
                            )
                            ? Colors.red
                            : Colors.amber.shade700,
                  ),
                  label: Text('${findings.length} finding(s)'),
                  onPressed: () => controller.activeTabIndex.value = 4,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ],
        );
      }),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final bool hasError;

  const _CountBadge({required this.count, required this.hasError});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: hasError ? Colors.red.shade700 : Colors.amber.shade800,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _UnattachedEmptyState extends StatelessWidget {
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  const _UnattachedEmptyState({
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  static const _snippet =
      '''import 'package:levit_devtools/levit_devtools.dart';

Future<void> main() async {
  Levit.enableAutoLinking();
  await LevitDevTools.attach();
  runApp(const MyApp());
}''';

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LevitDevTools is not attached in the running app',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Attach LevitDevTools in main() before runApp() to stream '
                    'redacted scopes, reactives, tasks, timeline events, and '
                    'diagnostics over the Dart VM Service.',
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const SelectableText(
                      _snippet,
                      style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Last error: $error',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: loading ? null : onRetry,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: Text(
                          loading ? 'Checking...' : 'Retry Connection',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                            const ClipboardData(text: _snippet),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy Snippet'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
