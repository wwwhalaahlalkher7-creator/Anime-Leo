import 'package:flutter/material.dart';
import '../core/config.dart';

class AdSlot extends StatelessWidget {
  final double height;
  final bool? enabled;

  const AdSlot({
    super.key,
    this.height = 52,
    this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    if (!(enabled ?? enableAds)) return const SizedBox.shrink();

    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(vertical: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: const Text(
        'مساحة إعلانية',
        style: TextStyle(fontSize: 12),
      ),
    );
  }
}
