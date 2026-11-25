import 'dart:ui';
import 'package:benchmarks/measured_frames.dart';
import 'package:flutter_test/flutter_test.dart';

FrameTiming frame(int vsync) => FrameTiming(
  vsyncStart: vsync * 1000,
  buildStart: vsync * 1000 + 1,
  buildFinish: vsync * 1000 + 3,
  rasterStart: vsync * 1000 + 4,
  rasterFinish: vsync * 1000 + 7,
  rasterFinishWallTime: 0,
  frameNumber: vsync,
);

void main() {
  test(
    'delayed timing batches exclude warmup and wait for every measured frame',
    () async {
      final frames = MeasuredFrames(2);
      frames.measure(20);
      frames.measure(30);
      frames.receive([frame(10), frame(20)]);
      expect(() => frames.samples, throwsStateError);
      frames.receive([frame(30)]);
      await frames.complete;
      expect(frames.samples, hasLength(2));
      expect(frames.samples.first, {'buildUs': 2, 'rasterUs': 3, 'totalUs': 7});
    },
  );
  test('timing can arrive before measurement bookkeeping', () async {
    final frames = MeasuredFrames(1)..receive([frame(10), frame(20)]);
    frames.measure(20);
    await frames.complete;
    expect(frames.samples, hasLength(1));
  });
  test('duplicate frames cannot satisfy a measurement count', () {
    final frames = MeasuredFrames(2)..measure(20);
    expect(() => frames.measure(20), throwsStateError);
  });
}
