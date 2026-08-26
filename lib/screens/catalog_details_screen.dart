import 'package:flutter/material.dart';
import '../models/catalog_item.dart';
import '../core/app_language.dart';
import '../core/link_launcher.dart';
import '../services/translation_service.dart';
import '../widgets/cached_anime_image.dart';
import 'manga_chapters_screen.dart';

class CatalogDetailsScreen extends StatefulWidget {
  final CatalogItem item;
  const CatalogDetailsScreen({super.key, required this.item});

  @override
  State<CatalogDetailsScreen> createState() => _CatalogDetailsScreenState();
}

class _CatalogDetailsScreenState extends State<CatalogDetailsScreen> {
  String? arabicSynopsis;
  bool translating = false;

  @override
  void initState() {
    super.initState();
    _translateIfNeeded();
  }

  Future<void> _translateIfNeeded() async {
    if (!AppLanguage.instance.isArabic) return;
    final source = widget.item.synopsis?.trim() ?? '';
    if (source.isEmpty) return;
    if (source.runes.any((r) => r >= 0x0600 && r <= 0x06ff)) return;
    setState(() => translating = true);
    final result = await TranslationService.instance.toArabicGeneric(key: 'catalog_${widget.item.source}_${widget.item.id}', text: source);
    if (!mounted) return;
    setState(() {
      translating = false;
      arabicSynopsis = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    // External catalog titles are intentionally English in both app interfaces.
    final title = widget.item.title.trim().isNotEmpty ? widget.item.title.trim() : (widget.item.titleAr?.trim() ?? 'Unknown');
    final synopsis = AppLanguage.instance.isArabic ? (arabicSynopsis ?? widget.item.synopsis) : widget.item.synopsis;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            actions: [
              if (widget.item.sourceUrl != null)
                IconButton(tooltip: AppLanguage.instance.text('فتح المصدر', 'Open source'), onPressed: () => LinkLauncher.open(context, widget.item.sourceUrl!), icon: const Icon(Icons.open_in_new)),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              background: Stack(fit: StackFit.expand, children: [
                CachedAnimeImage(url: widget.item.image, fit: BoxFit.cover),
                const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xF205081A)]))),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (widget.item.score != null) _Chip('⭐ ${widget.item.score}'),
                  if (widget.item.year != null) _Chip('${widget.item.year}'),
                  if (widget.item.type != null) _Chip(widget.item.type!),
                  _Chip(widget.item.source == 'tmdb' ? 'TMDB' : widget.item.source == 'mangadex' ? 'MangaDex' : widget.item.source),
                ]),
                const SizedBox(height: 22),
                Text(AppLanguage.instance.text('القصة', 'Synopsis'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                if (translating) const LinearProgressIndicator(minHeight: 2),
                const SizedBox(height: 8),
                Text(synopsis?.trim().isNotEmpty == true ? synopsis! : AppLanguage.instance.text('لا يوجد وصف متاح حاليًا.', 'No synopsis available.')),
                const SizedBox(height: 24),
                if (widget.item.source == 'mangadex') ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MangaChaptersScreen(manga: widget.item))),
                      icon: const Icon(Icons.menu_book_outlined),
                      label: Text(AppLanguage.instance.text('قراءة الفصول العربية', 'Read Arabic chapters')),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AppLanguage.instance.text('القراءة تتم من خوادم MangaDex مباشرة؛ Anime Leo لا يستضيف صفحات المانجا.', 'Pages are loaded directly from MangaDex; Anime Leo does not host manga pages.'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ] else if (widget.item.sourceUrl != null)
                  SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => LinkLauncher.open(context, widget.item.sourceUrl!), icon: const Icon(Icons.open_in_new), label: Text(AppLanguage.instance.text('عرض صفحة TMDB', 'View TMDB page')))),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip(this.text);
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)), child: Text(text));
}
