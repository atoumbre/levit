import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

void main() {
  runApp(
    LScope.put(
      () => RouteJournalController(),
      child: const RouteScopesApp(),
    ),
  );
}

class RouteScopesApp extends StatelessWidget {
  const RouteScopesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Levit Route Scopes',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        useMaterial3: true,
      ),
      routes: {
        '/': (_) => const DashboardRoute(),
        '/editor': (_) => const EditorRoute(),
        '/async-profile': (_) => const AsyncProfileRoute(),
        '/preview': (_) => const PreviewRoute(),
      },
    );
  }
}

class RouteJournalController extends LevitController {
  final entries = LxList<String>().named('entries');
  int _nextId = 1;

  @override
  void onInit() {
    super.onInit();
    autoDispose(entries);
    log('App ready');
  }

  void log(String message) {
    entries.insert(0, '${_nextId++}. $message');
    if (entries.length > 10) {
      entries.removeRange(10, entries.length);
    }
  }
}

class RouteCounterController extends LevitController {
  final String title;
  final String summary;
  final VoidCallback onClosed;
  final count = 0.lx.named('count');

  RouteCounterController({
    required this.title,
    required this.summary,
    required this.onClosed,
  });

  @override
  void onInit() {
    super.onInit();
    autoDispose(count);
  }

  void increment() {
    count.value++;
  }

  @override
  void onClose() {
    onClosed();
    super.onClose();
  }
}

class DashboardRoute extends StatelessWidget {
  const DashboardRoute({super.key});

  @override
  Widget build(BuildContext context) {
    final journal = context.levit.find<RouteJournalController>();

    return LRouteScope(
      name: 'dashboard-route',
      dependencyFactory: (scope) {
        scope.put<RouteCounterController>(
          () => RouteCounterController(
            title: 'Dashboard',
            summary:
                'This controller lives as long as the home route stays in the navigator stack.',
            onClosed: () => journal.log('Dashboard disposed'),
          ),
        );
      },
      child: LView<RouteCounterController>(
        builder: (context, controller) => _RouteScreen(
          routeLabel: controller.title,
          summary: controller.summary,
          accentColor: const Color(0xFF0F766E),
          counter: controller.count,
          onIncrement: () {
            controller.increment();
            journal.log('Dashboard counter -> ${controller.count.value}');
          },
          primaryAction: FilledButton(
            onPressed: () {
              journal.log('Navigate to sync route');
              Navigator.of(context).pushNamed('/editor');
            },
            child: const Text('Open sync route'),
          ),
          secondaryAction: FilledButton.tonal(
            onPressed: () {
              journal.log('Navigate to async route');
              Navigator.of(context).pushNamed('/async-profile');
            },
            child: const Text('Open async route'),
          ),
        ),
      ),
    );
  }
}

class EditorRoute extends StatelessWidget {
  const EditorRoute({super.key});

  @override
  Widget build(BuildContext context) {
    final journal = context.levit.find<RouteJournalController>();

    return LRouteScope(
      name: 'editor-route',
      dependencyFactory: (scope) {
        scope.put<RouteCounterController>(
          () => RouteCounterController(
            title: 'Editor Route',
            summary:
                'Use LRouteScope when the route owns sync controller setup and should survive being covered.',
            onClosed: () => journal.log('Editor route disposed'),
          ),
        );
      },
      child: LView<RouteCounterController>(
        builder: (context, controller) => _RouteScreen(
          routeLabel: controller.title,
          summary: controller.summary,
          accentColor: const Color(0xFF7C3AED),
          counter: controller.count,
          onIncrement: () {
            controller.increment();
            journal.log('Editor counter -> ${controller.count.value}');
          },
          primaryAction: FilledButton(
            onPressed: () {
              journal.log('Editor covered by preview');
              Navigator.of(context).pushNamed('/preview');
            },
            child: const Text('Cover with preview'),
          ),
          secondaryAction: FilledButton.tonal(
            onPressed: () {
              journal.log('Leave editor route');
              Navigator.of(context).pop();
            },
            child: const Text('Back'),
          ),
        ),
      ),
    );
  }
}

class AsyncProfileRoute extends StatelessWidget {
  const AsyncProfileRoute({super.key});

  @override
  Widget build(BuildContext context) {
    final journal = context.levit.find<RouteJournalController>();

    return LAsyncRouteScope(
      name: 'async-profile-route',
      dependencyFactory: (scope) async {
        journal.log('Async profile loading started');
        await Future<void>.delayed(const Duration(milliseconds: 700));
        scope.put<RouteCounterController>(
          () => RouteCounterController(
            title: 'Async Profile Route',
            summary:
                'Use LAsyncRouteScope when the route owns an async setup step before exposing local dependencies.',
            onClosed: () => journal.log('Async profile route disposed'),
          ),
        );
        journal.log('Async profile loading finished');
      },
      loading: (context) => const _AsyncRouteLoading(),
      child: LView<RouteCounterController>(
        builder: (context, controller) => _RouteScreen(
          routeLabel: controller.title,
          summary: controller.summary,
          accentColor: const Color(0xFF2563EB),
          counter: controller.count,
          onIncrement: () {
            controller.increment();
            journal.log(
              'Async profile counter -> ${controller.count.value}',
            );
          },
          primaryAction: FilledButton(
            onPressed: () {
              journal.log('Async profile covered by preview');
              Navigator.of(context).pushNamed('/preview');
            },
            child: const Text('Cover with preview'),
          ),
          secondaryAction: FilledButton.tonal(
            onPressed: () {
              journal.log('Leave async profile route');
              Navigator.of(context).pop();
            },
            child: const Text('Back'),
          ),
        ),
      ),
    );
  }
}

class PreviewRoute extends StatelessWidget {
  const PreviewRoute({super.key});

  @override
  Widget build(BuildContext context) {
    final journal = context.levit.find<RouteJournalController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Preview Route')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This route is intentionally plain Flutter.',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Push it on top of a route-scoped page to watch the underlying route switch to covered, then pop it to watch that route become current again.',
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  journal.log('Preview route popped');
                  Navigator.of(context).pop();
                },
                child: const Text('Close preview'),
              ),
              const SizedBox(height: 24),
              const Expanded(child: _JournalPanel()),
            ],
          ),
        ),
      ),
    );
  }
}

class _AsyncRouteLoading extends StatelessWidget {
  const _AsyncRouteLoading();

  @override
  Widget build(BuildContext context) {
    final visibility = LRouteScope.visibilityOf(context)!;

    return Scaffold(
      appBar: AppBar(title: const Text('Async Profile Route')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LBuilder<LRouteVisibility>(
                visibility,
                (value) => Chip(
                  avatar: const Icon(Icons.route, size: 18),
                  label: Text('Visibility: ${value.name}'),
                ),
              ),
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text(
                'LAsyncRouteScope is preparing route-local dependencies before the page content is exposed.',
              ),
              const SizedBox(height: 24),
              const Expanded(child: _JournalPanel()),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteScreen extends StatelessWidget {
  final String routeLabel;
  final String summary;
  final Color accentColor;
  final LxReactive<int> counter;
  final VoidCallback onIncrement;
  final Widget primaryAction;
  final Widget secondaryAction;

  const _RouteScreen({
    required this.routeLabel,
    required this.summary,
    required this.accentColor,
    required this.counter,
    required this.onIncrement,
    required this.primaryAction,
    required this.secondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(routeLabel)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RouteLifecycleReporter(routeLabel: routeLabel),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: accentColor.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      routeLabel,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(summary),
                    const SizedBox(height: 12),
                    const _VisibilityChip(),
                    const SizedBox(height: 12),
                    LBuilder<int>(
                      counter,
                      (value) => Text(
                        'Route-local counter: $value',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: onIncrement,
                          icon: const Icon(Icons.add),
                          label: const Text('Increment local state'),
                        ),
                        primaryAction,
                        secondaryAction,
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Route Journal',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Expanded(child: _JournalPanel()),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisibilityChip extends StatelessWidget {
  const _VisibilityChip();

  @override
  Widget build(BuildContext context) {
    final visibility = LRouteScope.visibilityOf(context)!;

    return LBuilder<LRouteVisibility>(
      visibility,
      (value) => Chip(
        avatar: Icon(
          switch (value) {
            LRouteVisibility.current => Icons.visibility,
            LRouteVisibility.covered => Icons.layers,
            LRouteVisibility.inactive => Icons.visibility_off,
          },
          size: 18,
        ),
        label: Text('Visibility: ${value.name}'),
      ),
    );
  }
}

class _JournalPanel extends StatelessWidget {
  const _JournalPanel();

  @override
  Widget build(BuildContext context) {
    final journal = context.levit.find<RouteJournalController>();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LBuilder<List<String>>(
          journal.entries,
          (entries) {
            final snapshot = List<String>.of(entries, growable: false);
            if (snapshot.isEmpty) {
              return const Center(child: Text('No route events yet.'));
            }

            return ListView.separated(
              itemCount: snapshot.length,
              itemBuilder: (context, index) => Text(snapshot[index]),
              separatorBuilder: (_, __) => const Divider(height: 12),
            );
          },
        ),
      ),
    );
  }
}

class _RouteLifecycleReporter extends StatefulWidget {
  final String routeLabel;

  const _RouteLifecycleReporter({required this.routeLabel});

  @override
  State<_RouteLifecycleReporter> createState() =>
      _RouteLifecycleReporterState();
}

class _RouteLifecycleReporterState extends State<_RouteLifecycleReporter> {
  LxReactive<LRouteVisibility>? _source;
  LxWorker<LRouteVisibility>? _worker;
  LRouteVisibility? _lastLogged;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextSource = LRouteScope.visibilityOf(context);
    if (identical(_source, nextSource)) return;

    _worker?.close();
    _source = nextSource;
    _lastLogged = null;

    if (nextSource == null) return;

    _worker = LxWorker<LRouteVisibility>(nextSource, (value) {
      if (!mounted || value == _lastLogged) return;
      _lastLogged = value;
      context.levit
          .find<RouteJournalController>()
          .log('${widget.routeLabel}: ${value.name}');
    });
  }

  @override
  void dispose() {
    _worker?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
