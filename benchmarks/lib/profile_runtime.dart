// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'performance_monitor.dart';
import 'package:levit_flutter/tasks.dart';

/// CPU/allocation investigation only. Use release_performance.dart for timings.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kProfileMode) throw StateError('Build this entrypoint in profile mode.');
  Levit.enableAutoLinking();
  registerExtension('ext.levit.profile', (_, parameters) async {
    final workload = parameters['workload']!;
    final enabled = Platform.environment['LEVIT_DIAGNOSTICS'] == 'on';
    final monitor = enabled ? (PerformanceMonitor()..enable()) : null;
    final source = 0.lx;
    var observed = 0;
    source.addListener(() => observed = source.value);
    final computed = workload == 'fanout'
        ? List.generate(128, (index) => LxComputed(() => source.value + index))
        : <LxComputed<int>>[];
    var notifications = 0;
    for (final value in computed) {
      value.addListener(() {
        value.value;
        notifications++;
      });
    }
    final engine = LevitTaskEngine(maxConcurrent: 4);
    var iterations = 0;
    var closed = 0;
    final elapsed = Stopwatch()..start();
    try {
      while (elapsed.elapsedMilliseconds < 5000) {
        switch (workload) {
          case 'notify':
            for (var i = 0; i < 10000; i++) {
              source.value++;
            }
            if (observed != source.value) throw StateError('Lost notification');
          case 'fanout':
            final before = notifications;
            for (var i = 0; i < 100; i++) {
              source.value++;
            }
            if (notifications - before != 12800) {
              throw StateError('Lost computed update');
            }
          case 'scopes':
            for (var i = 0; i < 100; i++) {
              final scope = LevitScope.root('profile');
              final resource = scope.put(() => _Resource(() => closed++));
              if (!identical(scope.find<_Resource>(), resource)) {
                throw StateError('Scope lookup');
              }
              await Future<void>.sync(scope.dispose);
            }
          case 'tasks':
            final List<Object?> values = await Future.wait(
              List.generate(100, (i) => engine.schedule((_) => i)),
            );
            if (values.fold<int>(0, (sum, n) => sum + (n as int)) != 4950) {
              throw StateError('Task completion');
            }
          default:
            throw ArgumentError.value(workload, 'workload');
        }
        await Future<void>.delayed(Duration.zero);
        iterations++;
      }
      if (workload == 'scopes' && closed != iterations * 100) {
        throw StateError('Incomplete cleanup');
      }
      await monitor?.flush();
      if (monitor != null && monitor.dropped != 0) {
        throw StateError('Diagnostic drops');
      }
      return ServiceExtensionResponse.result(
        jsonEncode({
          'workload': workload,
          'diagnostics': enabled,
          'iterations': iterations,
          'elapsedUs': elapsed.elapsedMicroseconds,
        }),
      );
    } finally {
      for (final value in computed.reversed) {
        await Future<void>.sync(value.close);
      }
      await Future<void>.sync(source.close);
      await Future<void>.sync(engine.dispose);
      await monitor?.close();
    }
  });
  print('LEVIT_PROFILE_READY');
}

class _Resource extends LevitScopeDisposable {
  _Resource(this.release);
  final void Function() release;
  @override
  Future<void> onClose() async {
    release();
    await Future<void>.sync(super.onClose);
  }
}
