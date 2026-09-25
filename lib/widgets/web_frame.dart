import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Keeps the phone-first layout readable in a wide browser window: centres
/// [child] in a column at most [maxWidth] wide and reports that width via
/// [MediaQuery], so screens that size themselves from it don't stretch.
class WebFrame extends StatelessWidget {
  const WebFrame({super.key, required this.child, this.maxWidth = 600});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = math.min(media.size.width, maxWidth);
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: SizedBox(
          width: width,
          child: MediaQuery(
            data: media.copyWith(size: Size(width, media.size.height)),
            child: child,
          ),
        ),
      ),
    );
  }
}
