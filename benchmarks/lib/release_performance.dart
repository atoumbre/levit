// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'performance_monitor.dart';
import 'measured_frames.dart';
import 'package:levit_flutter/tasks.dart';

const _samples = 30;
const _warmups = 5;
const _reference = String.fromEnvironment(
  'LEVIT_REFERENCE',
  defaultValue: 'candidate',
);

/// A native profile/release entrypoint, not a flutter_test benchmark.
/// Each process runs exactly one diagnostic state; teardown is checked per round.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Levit.enableAutoLinking();
  if (kDebugMode) throw StateError('Use --profile or --release.');
  final host = GlobalKey<_PerformanceHostState>();
  runApp(MaterialApp(home: _PerformanceHost(key: host)));
  final diagnosticsMode = Platform.environment['LEVIT_DIAGNOSTICS'];
  if (diagnosticsMode != 'off' && diagnosticsMode != 'on') {
    throw ArgumentError('Set LEVIT_DIAGNOSTICS to off or on.');
  }
  final enabled = diagnosticsMode == 'on';
  final measurements = <Map<String, Object?>>[];
  try {
    await _nextFrame();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (var round = 0; round < 3; round++) {
      Levit.enableWatchMonitoring = enabled;
      final monitor = enabled ? (PerformanceMonitor()..enable()) : null;
      try {
        Future<void> sample(
          String name,
          Future<void> Function() body, {
          int warmups = _warmups,
          int samples = _samples,
        }) async {
          final elapsed = <int>[];
          final bodies = <int>[];
          final eventsBefore = monitor?.sink.events ?? 0;
          final minimumWarmupUs = warmups == 0 ? 0 : 500000;
          final warming = Stopwatch()..start();
          var completedWarmups = 0;
          while (elapsed.length < samples) {
            final measured =
                completedWarmups >= warmups &&
                warming.elapsedMicroseconds >= minimumWarmupUs;
            if (measured) warming.stop();
            final stopwatch = Stopwatch()..start();
            await body();
            final bodyUs = stopwatch.elapsedMicroseconds;
            // Drain stream delivery and microtasks in both revisions.
            await Future<void>.delayed(Duration.zero);
            stopwatch.stop();
            final delivered = monitor?.sink.events;
            await monitor?.flush();
            if (monitor != null &&
                (monitor.dropped != 0 || delivered != monitor.sink.events)) {
              throw StateError('Incomplete diagnostics delivery in $name');
            }
            if (measured) {
              elapsed.add(stopwatch.elapsedMicroseconds);
              bodies.add(bodyUs);
            } else {
              completedWarmups++;
            }
          }
          measurements.add({
            'workload': name,
            'diagnostics': enabled,
            'round': round,
            'samplesUs': elapsed,
            'bodySamplesUs': bodies,
            'warmups': completedWarmups,
            'minimumWarmupUs': minimumWarmupUs,
            'warmupElapsedUs': warming.elapsedMicroseconds,
            'deliveredEvents': (monitor?.sink.events ?? 0) - eventsBefore,
            'rssBytes': ProcessInfo.currentRss,
          });
        }

        final source = 0.lx;
        var observed = 0;
        source.addListener(() => observed = source.value);
        await sample('notify_10000', () async {
          for (var i = 0; i < 10000; i++) {
            source.value++;
          }
          _check(observed == source.value, 'Notification completion');
        });
        final computed = List.generate(
          128,
          (index) => LxComputed(() => source.value + index),
        );
        var computedNotifications = 0;
        var computedChecksum = 0;
        for (final value in computed) {
          value.addListener(() {
            computedNotifications++;
            computedChecksum += value.value;
          });
        }
        await sample('fanout_128_x_100', () async {
          final before = computedNotifications;
          for (var i = 0; i < 100; i++) {
            source.value++;
          }
          _check(
            computedNotifications == before + 12800 && computedChecksum > 0,
            'Every computed consumer must observe every update',
          );
          _check(
            computed.last.value == source.value + 127,
            'Computed completion',
          );
        });
        for (final value in computed.reversed) {
          await Future<void>.sync(value.close);
        }
        await Future<void>.sync(source.close);

        var closed = 0;
        await sample('scope_lifetime_100', () async {
          final before = closed;
          for (var i = 0; i < 100; i++) {
            final scope = LevitScope.root('performance');
            final resource = scope.put(() => _Resource(() => closed++));
            _check(
              identical(scope.find<_Resource>(), resource),
              'Scope lookup',
            );
            await Future<void>.sync(scope.dispose);
          }
          _check(closed == before + 100, 'Scope cleanup');
        });

        final engine = LevitTaskEngine(maxConcurrent: 4);
        await sample('tasks_100', () async {
          final List<Object?> results = await Future.wait(
            List.generate(100, (index) => engine.schedule((_) => index)),
          );
          _check(
            results.fold<int>(0, (sum, value) => sum + (value as int)) == 4950,
            'Task completion',
          );
        });
        await Future<void>.sync(engine.dispose);

        final frames = MeasuredFrames(60);
        SchedulerBinding.instance.addTimingsCallback(frames.receive);
        final version = 0.lx;
        try {
          await host.currentState!.mount(
            LWatch(() {
              final current = version.value;
              return ListView.builder(
                itemCount: 1000,
                itemExtent: 24,
                itemBuilder: (_, index) => Text('Row $index: $current'),
              );
            }),
          );
          for (var i = 0; i < 10; i++) {
            version.value++;
            await _nextFrame();
          }
          await sample(
            'list_1000_frame',
            () async {
              version.value++;
              await _nextFrame();
              frames.measure(
                WidgetsBinding
                    .instance
                    .platformDispatcher
                    .frameData
                    .frameNumber,
              );
              _check(version.value > 10, 'UI update');
            },
            warmups: 0,
            samples: 60,
          );
          await frames.complete.timeout(const Duration(seconds: 5));
          measurements.last['frameTimings'] = frames.samples;
        } finally {
          SchedulerBinding.instance.removeTimingsCallback(frames.receive);
          await host.currentState!.mount(const SizedBox.shrink());
          await Future<void>.sync(version.close);
        }
        await monitor?.flush();
        _check(monitor == null || monitor.dropped == 0, 'Diagnostic drops');
      } finally {
        await monitor?.close();
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    print(
      'LEVIT_PERFORMANCE_JSON:${jsonEncode({
        'reference': _reference,
        'diagnosticsMode': diagnosticsMode,
        'middlewareDetached': true,
        'activityGuard': Platform.environment['LEVIT_PERFORMANCE_RUN'] == '1',
        'mode': kProfileMode ? 'profile' : 'release',
        'dart': Platform.version,
        'os': Platform.operatingSystemVersion,
        'processors': Platform.numberOfProcessors,
        'physicalSize': [view.physicalSize.width, view.physicalSize.height],
        'pixelRatio': view.devicePixelRatio,
        'displayId': view.display.id,
        'refreshRate': view.display.refreshRate,
        'historyCapacity': 10000,
        'candidateQueueCapacity': 65536,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'measurements': measurements,
      })}',
    );
    exit(0);
  } catch (error, stack) {
    print('LEVIT_PERFORMANCE_FAILED: $error\n$stack');
    exit(1);
  }
}

void _check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> _nextFrame() =>
    SchedulerBinding.instance.endOfFrame.timeout(const Duration(seconds: 5));

class _Resource extends LevitScopeDisposable {
  _Resource(this.release);
  final void Function() release;
  @override
  Future<void> onClose() async {
    release();
    await Future<void>.sync(super.onClose);
  }
}

class _PerformanceHost extends StatefulWidget {
  const _PerformanceHost({super.key});
  @override
  State<_PerformanceHost> createState() => _PerformanceHostState();
}

class _PerformanceHostState extends State<_PerformanceHost> {
  Widget child = const SizedBox.shrink();
  Future<void> mount(Widget next) async {
    setState(() => child = next);
    await _nextFrame();
  }

  @override
  Widget build(BuildContext context) => Scaffold(body: child);
}
