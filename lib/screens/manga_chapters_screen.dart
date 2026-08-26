import 'package:flutter/material.dart';
import '../core/app_language.dart';
import '../models/catalog_item.dart';
import '../services/manga_api_service.dart';
import 'manga_reader_screen.dart';

class MangaChaptersScreen extends StatefulWidget {
  final CatalogItem manga;
  const MangaChaptersScreen({super.key, required this.manga});
  @override
  State<MangaChaptersScreen> createState() => _MangaChaptersScreenState();
}

class _MangaChaptersScreenState extends State<MangaChaptersScreen> {
  final api = MangaApiService();
  late Future<List<MangaChapter>> future;

  @override
  void initState() { super.initState(); future = api.chapters(widget.manga.id); }
  @override
  void dispose() { api.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(AppLanguage.instance.text('الفصول العربية', 'Arabic chapters'))),
    body: FutureBuilder<List<MangaChapter>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(AppLanguage.instance.text('تعذر تحميل الفصول العربية حاليًا.', 'Arabic chapters are currently unavailable.'), textAlign: TextAlign.center)));
        final chapters = snapshot.data ?? [];
        if (chapters.isEmpty) return Center(child: Text(AppLanguage.instance.text('لا توجد فصول عربية متاحة.', 'No Arabic chapters are available.')));
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: chapters.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final c = chapters[i];
            final number = c.chapter?.isNotEmpty == true ? c.chapter! : '?';
            return Card(child: ListTile(
              leading: CircleAvatar(child: Text(number, maxLines: 1, overflow: TextOverflow.clip)),
              title: Text(c.title?.trim().isNotEmpty == true ? c.title! : AppLanguage.instance.text('الفصل $number', 'Chapter $number')),
              subtitle: Text([if (c.volume?.isNotEmpty == true) 'المجلد ${c.volume}', if (c.group?.isNotEmpty == true) c.group!, if (c.pages > 0) '${c.pages} صفحة'].join(' • ')),
              trailing: const Icon(Icons.menu_book_outlined),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MangaReaderScreen(chapter: c, api: api))),
            ));
          },
        );
      },
    ),
  );
}
