/// Recommended single-import kit for Flutter applications using Levit.
///
/// This library composes `levit_flutter_core`, `levit_dart`, and package-local
/// Flutter utilities into one import surface. For advanced task orchestration,
/// also import `package:levit_flutter/tasks.dart`.
library levit_flutter_kit;

import 'dart:async';

import 'package:flutter/widgets.dart';

export 'package:levit_dart/levit_dart.dart';
export 'package:levit_flutter_core/levit_flutter_core.dart' hide Ls, Lx;
export 'src/overlays.dart';

// Part files require these symbols at library scope for mixin constraints.
import 'package:levit_dart/levit_dart.dart'
    show LevitController, LevitLoopMixin;

part 'src/mixins/app_lifecycle_mixin.dart';
part 'src/mixins/lifecycle_loop_mixin.dart';
part 'src/widgets/keep_alive.dart';
