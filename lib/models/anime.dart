class Anime {
  final int id;
  final String title;
  final String image;
  final String? titleAr;
  final String? synopsis;
  final List<String> genres;
  final String? status;
  final double? score;
  final int? year;
  final String? type;
  final int? episodes;

  const Anime({
    required this.id,
    required this.title,
    required this.image,
    this.titleAr,
    this.synopsis,
    this.genres = const [],
    this.status,
    this.score,
    this.year,
    this.type,
    this.episodes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'image': image,
        'titleAr': titleAr,
        'synopsis': synopsis,
        'genres': genres,
        'status': status,
        'score': score,
        'year': year,
        'type': type,
        'episodes': episodes,
      };

  factory Anime.fromJson(Map<String, dynamic> json) => Anime(
        id: (json['id'] as num?)?.toInt() ?? 0,
        title: json['title']?.toString() ?? 'Unknown Anime',
        image: json['image']?.toString() ?? json['image_url']?.toString() ?? '',
        titleAr: json['titleAr']?.toString() ?? json['title_ar']?.toString(),
        synopsis: json['synopsis']?.toString(),
        genres: (json['genres'] is List)
            ? (json['genres'] as List).map((e) => e.toString()).toList()
            : const [],
        status: json['status']?.toString(),
        score: (json['score'] as num?)?.toDouble(),
        year: (json['year'] as num?)?.toInt(),
        type: json['type']?.toString(),
        episodes: (json['episodes'] as num?)?.toInt(),
      );
}
