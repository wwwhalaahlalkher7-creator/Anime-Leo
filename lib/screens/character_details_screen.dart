import 'package:flutter/material.dart';
import '../core/app_language.dart';
import '../core/app_state.dart';
import '../models/anime.dart';
import '../models/character.dart';
import '../repositories/anime_repository.dart';
import '../services/analytics_service.dart';
import '../services/remote_config_service.dart';
import '../widgets/cached_anime_image.dart';
import '../widgets/ui_states.dart';
import 'anime_details_screen.dart';

class CharacterDetailsScreen extends StatefulWidget {
  final int characterId;
  final AppState state;
  final AnalyticsService analytics;
  const CharacterDetailsScreen({super.key, required this.characterId, required this.state, required this.analytics});
  @override
  State<CharacterDetailsScreen> createState() => _CharacterDetailsScreenState();
}

class _CharacterDetailsScreenState extends State<CharacterDetailsScreen> {
  final repository = AnimeRepository();
  late Future<CharacterDetails> future;
  @override
  void initState() { super.initState(); future = repository.getCharacterDetails(widget.characterId); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(AppLanguage.instance.text('الشخصية', 'Character'))),
    body: FutureBuilder<CharacterDetails>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError || !snapshot.hasData) return UiStateCard(icon: Icons.person_off_outlined, title: AppLanguage.instance.text('تعذر تحميل الشخصية', 'Couldn\'t load character'), message: snapshot.error?.toString() ?? 'Unknown error', actionLabel: AppLanguage.instance.text('إعادة المحاولة', 'Retry'), onAction: () => setState(() => future = repository.getCharacterDetails(widget.characterId)));
        final c = snapshot.data!;
        return RefreshIndicator(onRefresh: () async => setState(() => future = repository.getCharacterDetails(widget.characterId)), child: ListView(padding: const EdgeInsets.all(16), children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(borderRadius: BorderRadius.circular(18), child: SizedBox(width: 132, height: 188, child: CachedAnimeImage(url: c.imageUrl, fit: BoxFit.cover))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Row(children: [const Icon(Icons.favorite, color: Colors.redAccent, size: 18), const SizedBox(width: 6), Text(_format(c.favorites), style: const TextStyle(fontWeight: FontWeight.w800))]),
              if (c.about?.trim().isNotEmpty == true) ...[const SizedBox(height: 14), Text(c.about!, maxLines: 8, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.45))],
            ])),
          ]),
          const SizedBox(height: 24),
          Text(AppLanguage.instance.text('الأعمال', 'Anime'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          ...c.anime.map((entry) => Card(child: ListTile(
            leading: SizedBox(width: 48, height: 64, child: ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedAnimeImage(url: entry.imageUrl ?? '', fit: BoxFit.cover))),
            title: Text(entry.title, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: entry.role?.isNotEmpty == true ? Text(entry.role!) : null,
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AnimeDetailsScreen(anime: Anime(id: entry.id, malId: entry.id, title: entry.title, image: entry.imageUrl ?? ''), state: widget.state, remoteConfig: RemoteConfig.disabled, analytics: widget.analytics))),
          ))),
        ]));
      },
    ),
  );
}
String _format(int value) { if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M'; if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K'; return '$value'; }
