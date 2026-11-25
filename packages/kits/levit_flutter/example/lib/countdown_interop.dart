import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

/// Run with `flutter run -t lib/countdown_interop.dart` from this example package.
void main() {
  Levit.enableAutoLinking();
  runApp(const CountdownInteropApp());
}

/// The feature owns the countdown and adapter. The adapter borrows the duration.
class CountdownInteropController extends LevitController with LevitTimeMixin {
  late final LxCountdown countdown;
  late final ValueListenable<Duration> display;

  @override
  void onInit() {
    super.onInit();
    countdown = startCountdown(
      duration: const Duration(seconds: 5),
      interval: const Duration(milliseconds: 100),
    );
    display = own(countdown.remaining.asValueListenable());
  }
}

class CountdownInteropApp extends StatelessWidget {
  const CountdownInteropApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: LScopedView<CountdownInteropController>.put(
      CountdownInteropController.new,
      autoWatch: false,
      builder: (_, controller) => Scaffold(
        appBar: AppBar(title: const Text('Countdown interoperability')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Flutter's existing API observes the borrowed Levit value.
              ValueListenableBuilder<Duration>(
                valueListenable: controller.display,
                builder: (context, remaining, child) => Text(
                  '${(remaining.inMilliseconds / 1000).toStringAsFixed(1)} s',
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: controller.countdown.pause,
                    child: const Text('Pause'),
                  ),
                  TextButton(
                    onPressed: controller.countdown.resume,
                    child: const Text('Resume'),
                  ),
                  TextButton(
                    onPressed: controller.countdown.stop,
                    child: const Text('Stop'),
                  ),
                  TextButton(
                    onPressed: controller.countdown.start,
                    child: const Text('Restart'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
