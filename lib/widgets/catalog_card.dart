import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/catalog_item.dart';
import '../screens/catalog_details_screen.dart';

class CatalogCard extends StatelessWidget {
  final CatalogItem item;
  final double width;

  const CatalogCard({super.key, required this.item, this.width = double.infinity});

  String get displayTitle => item.title.trim().isNotEmpty ? item.title.trim() : (item.titleAr?.trim() ?? 'Unknown');

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CatalogDetailsScreen(item: item))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: item.image,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  errorWidget: (_, __, ___) => Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: Center(
                child: Text(displayTitle, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, height: 1.2)),
              ),
            ),
            const SizedBox(height: 2),
            Text('⭐ ${item.score ?? '—'}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .55))),
          ],
        ),
      ),
    );
  }
}
