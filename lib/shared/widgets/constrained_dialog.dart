import 'package:flutter/material.dart';

class ConstrainedDialog extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry insetPadding;

  const ConstrainedDialog({
    super.key,
    required this.child,
    this.maxWidth = 550,
    this.insetPadding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: insetPadding,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}
