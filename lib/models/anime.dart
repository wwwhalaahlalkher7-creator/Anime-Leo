int? _positiveInt(dynamic value) {
  final n = value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
  return n != null && n > 0 ? n : null;
}

class Anime {
  final int id;
  final String? canonicalId;
  final int? malId;
  final int? anilistId;
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
    this.canonicalId,
    this.malId,
    this.anilistId,
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
        'canonicalId': canonicalId,
        'malId': malId,
        'anilistId': anilistId,
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
        canonicalId: json['canonicalId']?.toString(),
        malId: ((json['malId'] ?? json['mal_id']) is num && ((json['malId'] ?? json['mal_id']) as num).toInt() > 0)
            ? ((json['malId'] ?? json['mal_id']) as num).toInt()
            : _positiveInt(json['malId'] ?? json['mal_id']),
        anilistId: (json['anilistId'] ?? json['anilist_id']) is num
            ? ((json['anilistId'] ?? json['anilist_id']) as num).toInt()
            : int.tryParse('${json['anilistId'] ?? json['anilist_id'] ?? ''}'),
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
