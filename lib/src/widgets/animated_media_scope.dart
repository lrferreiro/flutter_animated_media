import 'package:flutter/widgets.dart';

import '../cache/media_loader.dart';

/// Supplies one injectable loader to a subtree, without a global override.
class AnimatedMediaScope extends InheritedWidget {
  const AnimatedMediaScope({
    super.key,
    required this.loader,
    required super.child,
  });
  final MediaLoader loader;

  static MediaLoader? loaderOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AnimatedMediaScope>()?.loader;

  @override
  bool updateShouldNotify(AnimatedMediaScope oldWidget) =>
      oldWidget.loader != loader;
}
