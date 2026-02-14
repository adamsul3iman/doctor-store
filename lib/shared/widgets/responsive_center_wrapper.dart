import 'package:flutter/material.dart';

class ResponsiveCenterWrapper extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveCenterWrapper({
    super.key,
    required this.child,
    this.maxWidth = 1200,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sidePadding = constraints.maxWidth > maxWidth
            ? (constraints.maxWidth - maxWidth) / 2
            : 0.0;

        final resolvedPadding = padding ?? const EdgeInsets.symmetric(horizontal: 16);

        return Padding(
          padding: EdgeInsets.only(left: sidePadding, right: sidePadding),
          child: Padding(
            padding: resolvedPadding,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class SliverResponsiveCenterPadding extends StatelessWidget {
  final Widget sliver;
  final double maxWidth;
  final double minSidePadding;

  const SliverResponsiveCenterPadding({
    super.key,
    required this.sliver,
    this.maxWidth = 1200,
    this.minSidePadding = 16,
  });

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final side = width > maxWidth ? (width - maxWidth) / 2 : 0.0;
        final horizontal = side + minSidePadding;

        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: horizontal),
          sliver: sliver,
        );
      },
    );
  }
}
