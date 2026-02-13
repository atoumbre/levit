import 'package:levit/levit.dart';

void main() {
  // `levit` exposes reactive, scope, and dart-core APIs from one import.
  final count = 0.lx;
  count.addListener(() {
    print('Count changed: ${count.value}');
  });

  count.value++;
}
