/// Recommended single-import kit for Flutter applications using Levit.
///
/// This library composes `levit_flutter_core`, `levit_dart`, and package-local
/// Flutter utilities into one import surface.
library levit_flutter_kit;

import 'package:flutter/widgets.dart';

export 'package:levit_dart/levit_dart.dart';
export 'package:levit_flutter_core/levit_flutter_core.dart';

// Part files require these symbols at library scope for mixin constraints.
import 'package:levit_dart/levit_dart.dart'
    show LevitController, LevitLoopExecutionMixin;

part 'src/mixins/app_lifecycle_mixin.dart';
part 'src/mixins/lifecycle_loop_mixin.dart';
part 'src/widgets/keep_alive.dart';
part 'src/widgets/list_item_monitor.dart';
