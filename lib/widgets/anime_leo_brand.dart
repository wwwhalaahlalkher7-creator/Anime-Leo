import 'package:flutter/material.dart';

/// Branded Anime Leo wordmark rendered from the supplied artwork.
/// The source artwork already contains the white/blue glow used by the brand.
class AnimeLeoWordmark extends StatelessWidget {
  final double width;
  final double height;

  const AnimeLeoWordmark({
    super.key,
    this.width = 120,
    this.height = 36,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Anime Leo',
      image: true,
      child: SizedBox(
        width: width,
        height: height,
        child: Image.asset(
          'assets/anime_leo_wordmark.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
