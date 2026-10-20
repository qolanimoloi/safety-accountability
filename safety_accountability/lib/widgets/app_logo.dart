import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double height;
  const AppLogo({super.key, this.height = 120});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final image = Image.asset(
      'assets/images/logo.png',
      height: height,
      fit: BoxFit.contain,
      semanticLabel: 'Safety and Accountability',
      errorBuilder: (_, _, _) => Icon(Icons.shield_rounded, size: height * 0.6, color: const Color(0xFF007BFF)),
    );
    if (!isDark) return image;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: image,
    );
  }
}