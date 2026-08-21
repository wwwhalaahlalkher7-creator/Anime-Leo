import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/app_language.dart';
import '../core/config.dart';
import '../widgets/anime_leo_brand.dart';
import '../core/link_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLanguage.instance.text('عن التطبيق', 'About the app'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const AnimeLeoWordmark(width: 190, height: 48),
          const SizedBox(height: 4),
          Text(
            AppLanguage.instance.text('الإصدار $appVersion', 'Version $appVersion'),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Text(
            AppLanguage.instance.text(
              'التطبيق لاكتشاف الأنمي ومتابعته: تصفح كتالوجًا، احفظ المفضلة، وتابع سجل مشاهدتك. بيانات الأنمي (العناوين، الصور، التقييمات) تُجلب من مصادر تعريفية عامة (Jikan وAniList)، وليست مملوكة لهذا التطبيق.',
              'This app is an anime discovery and tracking app: browse a catalog, save favorites, and keep a watch history. Anime metadata (titles, images, ratings) comes from public metadata providers (Jikan and AniList) and isn\'t owned by this app.',
            ),
            style: const TextStyle(height: 1.7),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => LinkLauncher.open(context, 'https://www.themoviedb.org'),
                    child: SvgPicture.network(
                      'https://www.themoviedb.org/assets/2/v4/logos/v2/blue_short-8e7b30f73a4020692ccca9c88bafe5dcb6f8a62a4c6bc55cd9ba82bb2cd95f6c.svg',
                      height: 28,
                      placeholderBuilder: (_) => const Text('TMDB', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AppLanguage.instance.text(
                      'هذا المنتج يستخدم TMDB API لكنه غير معتمد أو موصى به من TMDB.',
                      'This product uses the TMDB API but is not endorsed or certified by TMDB.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(height: 1.6),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            AppLanguage.instance.text(
              'بيانات الرسوم المتحركة والعناوين والصور في هذا القسم تأتي من TMDB. خيارات المشاهدة تعتمد على مزودي المشاهدة المتاحين في بلد المستخدم، ولا يوفر TMDB ملفات حلقات للبث داخل التطبيق.',
              'Animation metadata, titles, and images in this section come from TMDB. Viewing options depend on providers available in the user’s country; TMDB does not provide episode video files for in-app streaming.',
            ),
            style: const TextStyle(height: 1.7),
          ),
          const SizedBox(height: 12),
          Text(
            AppLanguage.instance.text(
              'قسم المانجا يستخدم واجهة MangaDex الرسمية. يمكن قراءة الفصول العربية المتاحة داخل التطبيق دون أن يستضيف Anime Leo صور الفصول على خوادمه. توفر المحتوى وحقوقه تعتمد على MangaDex والجهة الناشرة/مجموعة الترجمة لكل عنوان.',
              'The manga section uses the official MangaDex API. Available Arabic chapters can be read in-app without Anime Leo hosting the chapter images on its servers. Content availability and rights depend on MangaDex and the publisher/translation group for each title.',
            ),
            style: const TextStyle(height: 1.7),
          ),
          const SizedBox(height: 14),
          Text(
            AppLanguage.instance.text(
              'مصدر المشاهدة الأساسي في V1.29 هو ani-cli-arabic. وتُستخدم بيانات MyDubList لبيان توفر الدبلجة العربية. Dub data © MyDubList - https://mydublist.com - (CC BY 4.0).',
              'The primary playback source in V1.29 is ani-cli-arabic. MyDubList data is used to indicate Arabic-dub availability. Dub data © MyDubList - https://mydublist.com - (CC BY 4.0).',
            ),
            style: const TextStyle(height: 1.7),
          ),
          const SizedBox(height: 12),
          Text(
            AppLanguage.instance.text(
              'المفضلة وسجل المشاهدة والإعدادات تُحفظ محليًا على جهازك فقط.',
              'Favorites, watch history, and settings are stored locally on your device only.',
            ),
            style: const TextStyle(height: 1.7),
          ),
        ],
      ),
    );
  }
}
