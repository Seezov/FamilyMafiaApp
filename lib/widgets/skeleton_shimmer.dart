import 'package:flutter/material.dart';

class SkeletonShimmer extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const SkeletonShimmer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
  });

  factory SkeletonShimmer.text({
    Key? key,
    required double width,
    double height = 14,
  }) =>
      SkeletonShimmer(
        key: key,
        width: width,
        height: height,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      );

  factory SkeletonShimmer.circle({
    Key? key,
    required double radius,
  }) =>
      SkeletonShimmer(
        key: key,
        width: radius * 2,
        height: radius * 2,
        borderRadius: BorderRadius.all(Radius.circular(radius)),
      );

  factory SkeletonShimmer.card({
    Key? key,
    required double width,
    required double height,
  }) =>
      SkeletonShimmer(
        key: key,
        width: width,
        height: height,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      );

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final baseColor = cs.surfaceContainerHighest;
    final highlightColor = cs.surfaceContainerLow;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _controller.value, 0),
              end: Alignment(-1.0 + 2.0 * _controller.value + 1.0, 0),
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}
