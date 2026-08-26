import 'package:flutter/material.dart';
import '../core/app_language.dart';
import '../services/manga_api_service.dart';

class MangaReaderScreen extends StatefulWidget {
  final MangaChapter chapter;
  final MangaApiService api;
  const MangaReaderScreen({super.key, required this.chapter, required this.api});
  @override
  State<MangaReaderScreen> createState() => _MangaReaderScreenState();
}

class _MangaReaderScreenState extends State<MangaReaderScreen> {
  late Future<List<String>> future;
  @override
  void initState() { super.initState(); future = widget.api.pages(widget.chapter.id); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(title: Text(AppLanguage.instance.text('الفصل ${widget.chapter.chapter ?? '?'}', 'Chapter ${widget.chapter.chapter ?? '?'}'))),
    body: FutureBuilder<List<String>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text(AppLanguage.instance.text('تعذر تحميل صفحات الفصل.', 'Couldn\'t load chapter pages.'), style: const TextStyle(color: Colors.white)));
        final pages = snapshot.data ?? [];
        if (pages.isEmpty) return Center(child: Text(AppLanguage.instance.text('لا توجد صفحات متاحة.', 'No pages are available.'), style: const TextStyle(color: Colors.white)));
        return ListView.builder(
          itemCount: pages.length,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Image.network(
              pages[i],
              width: double.infinity,
              fit: BoxFit.fitWidth,
              loadingBuilder: (context, child, progress) => progress == null ? child : const AspectRatio(aspectRatio: 0.68, child: Center(child: CircularProgressIndicator())),
              errorBuilder: (_, __, ___) => const Padding(padding: EdgeInsets.all(32), child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48)),
            ),
          ),
        );
      },
    ),
  );
}
