/// The official Flutter integration kit for the Levit ecosystem.
///
/// This kit provides the necessary widgets and hooks to connect Levit's
/// reactive state and dependency injection with the Flutter widget tree.
library levit_flutter_kit;

import 'package:flutter/widgets.dart';
import 'package:levit_flutter/levit_flutter.dart';

export 'package:levit_dart/levit_dart.dart';
export 'package:levit_flutter_core/levit_flutter_core.dart';

part 'src/mixins/app_lifecycle_mixin.dart';
part 'src/mixins/lifecycle_loop_mixin.dart';
part 'src/widgets/keep_alive.dart';
part 'src/widgets/list_item_monitor.dart';
