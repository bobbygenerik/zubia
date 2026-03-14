import 'package:flutter/material.dart';

/// The official Zubia Z logo displaying the app icon asset.
class ZubiaLogo extends StatelessWidget {
  final String? semanticLabel;
  final bool excludeFromSemantics;

  const ZubiaLogo({
    super.key,
    this.semanticLabel,
    this.excludeFromSemantics = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        'assets/icon/app_icon.png',
        fit: BoxFit.cover,
        semanticLabel: semanticLabel,
        excludeFromSemantics: excludeFromSemantics,
      ),
    );
  }
}
