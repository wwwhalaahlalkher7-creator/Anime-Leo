class PopularCharacter {
  final int id;
  final String name;
  final String imageUrl;
  final int favorites;
  final int rank;

  const PopularCharacter({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.favorites = 0,
    this.rank = 0,
  });

  factory PopularCharacter.fromJson(Map<String, dynamic> json) => PopularCharacter(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name']?.toString() ?? 'Unknown',
        imageUrl: json['imageUrl']?.toString() ?? '',
        favorites: (json['favorites'] as num?)?.toInt() ?? 0,
        rank: (json['rank'] as num?)?.toInt() ?? 0,
      );
}

class CharacterAnimeEntry {
  final int id;
  final String title;
  final String? imageUrl;
  final String? role;

  const CharacterAnimeEntry({required this.id, required this.title, this.imageUrl, this.role});

  factory CharacterAnimeEntry.fromJson(Map<String, dynamic> json) => CharacterAnimeEntry(
        id: (json['id'] as num?)?.toInt() ?? 0,
        title: json['title']?.toString() ?? 'Unknown Anime',
        imageUrl: json['imageUrl']?.toString(),
        role: json['role']?.toString(),
      );
}

class CharacterDetails {
  final int id;
  final String name;
  final String imageUrl;
  final int favorites;
  final String? about;
  final List<CharacterAnimeEntry> anime;

  const CharacterDetails({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.favorites = 0,
    this.about,
    this.anime = const [],
  });

  factory CharacterDetails.fromJson(Map<String, dynamic> json) => CharacterDetails(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name']?.toString() ?? 'Unknown',
        imageUrl: json['imageUrl']?.toString() ?? '',
        favorites: (json['favorites'] as num?)?.toInt() ?? 0,
        about: json['about']?.toString(),
        anime: json['anime'] is List
            ? (json['anime'] as List)
                .whereType<Map>()
                .map((e) => CharacterAnimeEntry.fromJson(Map<String, dynamic>.from(e)))
                .where((e) => e.id > 0)
                .toList()
            : const [],
      );
}
