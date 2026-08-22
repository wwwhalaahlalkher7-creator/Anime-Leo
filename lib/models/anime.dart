int? _positiveInt(dynamic value) {
  final n = value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
  return n != null && n > 0 ? n : null;
}

class AnimeCharacter {
  final int id;
  final String name;
  final String? imageUrl;
  final String? role;
  const AnimeCharacter({required this.id, required this.name, this.imageUrl, this.role});
}

class AnimeRelation {
  final String relation;
  final List<AnimeRelatedEntry> entries;
  const AnimeRelation({required this.relation, required this.entries});
}

class AnimeRelatedEntry {
  final int id;
  final String title;
  final String? type;
  const AnimeRelatedEntry({required this.id, required this.title, this.type});
}

class AnimeRecommendation {
  final int id;
  final String title;
  final String? imageUrl;
  const AnimeRecommendation({required this.id, required this.title, this.imageUrl});
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
  final String? source;
  final String? duration;
  final String? airedFrom;
  final String? airedTo;
  final String? rating;
  final int? rank;
  final int? members;
  final int? popularity;
  final String? season;
  final int? seasonYear;
  final String? broadcastDay;
  final String? broadcastTime;
  final List<String> studioNames;
  final String? trailerUrl;
  final String? trailerImageUrl;
  final String? backgroundImageUrl;
  final List<AnimeCharacter> characters;
  final List<AnimeRelation> relations;
  final List<AnimeRecommendation> recommendations;

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
    this.source,
    this.duration,
    this.airedFrom,
    this.airedTo,
    this.rating,
    this.rank,
    this.members,
    this.popularity,
    this.season,
    this.seasonYear,
    this.broadcastDay,
    this.broadcastTime,
    this.studioNames = const [],
    this.trailerUrl,
    this.trailerImageUrl,
    this.backgroundImageUrl,
    this.characters = const [],
    this.relations = const [],
    this.recommendations = const [],
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
        'source': source,
        'duration': duration,
        'airedFrom': airedFrom,
        'airedTo': airedTo,
        'rating': rating,
        'rank': rank,
        'members': members,
        'popularity': popularity,
        'season': season,
        'seasonYear': seasonYear,
        'broadcastDay': broadcastDay,
        'broadcastTime': broadcastTime,
        'studioNames': studioNames,
        'trailerUrl': trailerUrl,
        'trailerImageUrl': trailerImageUrl,
        'backgroundImageUrl': backgroundImageUrl,
        'characters': characters.map((e) => {'id': e.id, 'name': e.name, 'imageUrl': e.imageUrl, 'role': e.role}).toList(),
        'relations': relations.map((r) => {'relation': r.relation, 'entries': r.entries.map((e) => {'id': e.id, 'title': e.title, 'type': e.type}).toList()}).toList(),
        'recommendations': recommendations.map((e) => {'id': e.id, 'title': e.title, 'imageUrl': e.imageUrl}).toList(),
      };

  static List<AnimeCharacter> parseCharacters(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<Map>().map((e) => AnimeCharacter(
      id: (e['id'] as num?)?.toInt() ?? 0,
      name: e['name']?.toString() ?? 'Unknown',
      imageUrl: e['imageUrl']?.toString(),
      role: e['role']?.toString(),
    )).where((e) => e.id > 0).toList();
  }

  static List<AnimeRelation> parseRelations(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<Map>().map((r) => AnimeRelation(
      relation: r['relation']?.toString() ?? 'Related',
      entries: (r['entries'] is List) ? (r['entries'] as List).whereType<Map>().map((e) => AnimeRelatedEntry(
        id: (e['id'] as num?)?.toInt() ?? 0,
        title: e['title']?.toString() ?? 'Unknown',
        type: e['type']?.toString(),
      )).where((e) => e.id > 0).toList() : const [],
    )).where((r) => r.entries.isNotEmpty).toList();
  }

  static List<AnimeRecommendation> parseRecommendations(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<Map>().map((e) => AnimeRecommendation(
      id: (e['id'] as num?)?.toInt() ?? 0,
      title: e['title']?.toString() ?? 'Unknown',
      imageUrl: e['imageUrl']?.toString(),
    )).where((e) => e.id > 0).toList();
  }

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
        source: json['source']?.toString(),
        duration: json['duration']?.toString(),
        airedFrom: json['airedFrom']?.toString() ?? json['aired_from']?.toString(),
        airedTo: json['airedTo']?.toString() ?? json['aired_to']?.toString(),
        rating: json['rating']?.toString(),
        rank: (json['rank'] as num?)?.toInt(),
        members: (json['members'] as num?)?.toInt(),
        popularity: (json['popularity'] as num?)?.toInt(),
        season: json['season']?.toString(),
        seasonYear: (json['seasonYear'] as num?)?.toInt(),
        broadcastDay: json['broadcastDay']?.toString(),
        broadcastTime: json['broadcastTime']?.toString(),
        studioNames: (json['studioNames'] is List) ? (json['studioNames'] as List).map((e) => e.toString()).toList() : const [],
        trailerUrl: json['trailerUrl']?.toString(),
        trailerImageUrl: json['trailerImageUrl']?.toString(),
        backgroundImageUrl: json['backgroundImageUrl']?.toString(),
        characters: parseCharacters(json['characters']),
        relations: parseRelations(json['relations']),
        recommendations: parseRecommendations(json['recommendations']),
      );
}
