
## ✓ Follow Dart file conventions (30 / 30)
### [*] 10/10 points: Provide a valid `pubspec.yaml`

### [*] 5/5 points: Provide a valid `README.md`

### [*] 5/5 points: Provide a valid `CHANGELOG.md`

### [*] 10/10 points: Use an OSI-approved license

Detected license: `MIT`.


## ✓ Provide documentation (20 / 20)
### [*] 10/10 points: 20% or more of the public API has dartdoc comments

80 out of 93 API elements (86.0 %) have documentation comments.

Some symbols that are missing documentation: `levit_monitor.DependencyRegisterEvent.DependencyRegisterEvent.new`, `levit_monitor.DependencyRegisterEvent.source`, `levit_monitor.DependencyResolveEvent.DependencyResolveEvent.new`, `levit_monitor.DependencyResolveEvent.source`, `levit_monitor.LevitLogLevel.level`.

### [*] 10/10 points: Package has an example


## ✓ Platform support (20 / 20)
### [*] 20/20 points: Supports 5 of 6 possible platforms (**iOS**, **Android**, Web, **Windows**, **macOS**, **Linux**)

* ✓ Android

* ✓ iOS

* ✓ Windows

* ✓ Linux

* ✓ macOS


These platforms are not supported:

<details>
<summary>
Package not compatible with platform Web
</summary>

Because:
* `package:levit_monitor/levit_monitor.dart` that imports:
* `package:levit_monitor/src/transports/file_transport.dart` that imports:
* `dart:io`
</details>


## ✓ Pass static analysis (50 / 50)
### [*] 50/50 points: code has no errors, warnings, lints, or formatting issues


## ✓ Support up-to-date dependencies (40 / 40)
### [*] 10/10 points: All of the package dependencies are supported in the latest version

|Package|Constraint|Compatible|Latest|Notes|
|:-|:-|:-|:-|:-|
|[`levit_dart`]|`^0.0.5`|0.0.4|0.0.4||
|[`levit_reactive`]|`^0.0.5`|0.0.4|0.0.4||
|[`logger`]|`^2.6.2`|2.6.2|2.6.2||
|[`meta`]|`^1.17.0`|1.18.0|1.18.0||
|[`web_socket_channel`]|`^3.0.3`|3.0.3|3.0.3||

<details><summary>Transitive dependencies</summary>

|Package|Constraint|Compatible|Latest|Notes|
|:-|:-|:-|:-|:-|
|[`async`]|-|2.13.0|2.13.0||
|[`collection`]|-|1.19.1|1.19.1||
|[`crypto`]|-|3.0.7|3.0.7||
|[`levit_scope`]|-|0.0.4|0.0.4||
|[`stream_channel`]|-|2.1.4|2.1.4||
|[`typed_data`]|-|1.4.0|1.4.0||
|[`web`]|-|1.1.1|1.1.1||
|[`web_socket`]|-|1.0.1|1.0.1||
</details>

To reproduce run `dart pub outdated --no-dev-dependencies --up-to-date --no-dependency-overrides`.

[`levit_dart`]: https://pub.dev/packages/levit_dart
[`levit_reactive`]: https://pub.dev/packages/levit_reactive
[`logger`]: https://pub.dev/packages/logger
[`meta`]: https://pub.dev/packages/meta
[`web_socket_channel`]: https://pub.dev/packages/web_socket_channel
[`async`]: https://pub.dev/packages/async
[`collection`]: https://pub.dev/packages/collection
[`crypto`]: https://pub.dev/packages/crypto
[`levit_scope`]: https://pub.dev/packages/levit_scope
[`stream_channel`]: https://pub.dev/packages/stream_channel
[`typed_data`]: https://pub.dev/packages/typed_data
[`web`]: https://pub.dev/packages/web
[`web_socket`]: https://pub.dev/packages/web_socket

### [*] 10/10 points: Package supports latest stable Dart and Flutter SDKs

### [*] 20/20 points: Compatible with dependency constraint lower bounds

`pub downgrade` does not expose any static analysis error.


Points: 160/160.
