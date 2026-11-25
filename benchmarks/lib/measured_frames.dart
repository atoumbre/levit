import 'dart:async';
import 'dart:ui';

/// Matches engine timing batches to measured frame IDs, excluding
/// warmup frames regardless of when their timing records arrive.
class MeasuredFrames {
  MeasuredFrames(this.count);
  final int count;
  final _measured = <int>{};
  final _received = <int, FrameTiming>{};
  final _complete = Completer<void>();

  Future<void> get complete => _complete.future;

  void measure(int frameNumber) {
    if (frameNumber < 0 ||
        !_measured.add(frameNumber) ||
        _measured.length > count) {
      throw StateError('Expected distinct measured frames.');
    }
    _checkComplete();
  }

  void receive(List<FrameTiming> frames) {
    for (final frame in frames) {
      _received[frame.frameNumber] = frame;
    }
    _checkComplete();
  }

  void _checkComplete() {
    if (!_complete.isCompleted &&
        _measured.length == count &&
        _measured.every(_received.containsKey)) {
      _complete.complete();
    }
  }

  List<Map<String, int>> get samples {
    if (!_complete.isCompleted) {
      throw StateError('Frame timings are incomplete.');
    }
    return _measured.map((timestamp) {
      final frame = _received[timestamp]!;
      return {
        'buildUs': frame.buildDuration.inMicroseconds,
        'rasterUs': frame.rasterDuration.inMicroseconds,
        'totalUs': frame.totalSpan.inMicroseconds,
      };
    }).toList();
  }
}
