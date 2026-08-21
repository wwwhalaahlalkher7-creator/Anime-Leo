class CatalogItem {
  final String id;
  final String title;
  final String? titleAr;
  final String image;
  final String? synopsis;
  final double? score;
  final int? year;
  final String? type;
  final String source;
  final String? sourceUrl;

  const CatalogItem({
    required this.id,
    required this.title,
    required this.image,
    this.titleAr,
    this.synopsis,
    this.score,
    this.year,
    this.type,
    required this.source,
    this.sourceUrl,
  });

  factory CatalogItem.fromJson(Map<String, dynamic> json) => CatalogItem(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? 'Unknown',
        titleAr: json['title_ar']?.toString() ?? json['titleAr']?.toString(),
        image: json['image']?.toString() ?? '',
        synopsis: json['synopsis']?.toString(),
        score: (json['score'] as num?)?.toDouble(),
        year: (json['year'] as num?)?.toInt(),
        type: json['type']?.toString(),
        source: json['source']?.toString() ?? 'external',
        sourceUrl: json['source_url']?.toString() ?? json['sourceUrl']?.toString(),
      );
}
