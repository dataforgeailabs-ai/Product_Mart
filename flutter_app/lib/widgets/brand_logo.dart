import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.white = false, this.height = 42});

  final bool white;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      white
          ? 'assets/brand/logo-horizontal-white.png'
          : 'assets/brand/logo-horizontal-red.png',
      height: height,
      fit: BoxFit.contain,
      semanticLabel: 'Misty Go Delivery',
    );
  }
}
