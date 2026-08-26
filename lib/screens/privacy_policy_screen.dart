import 'package:flutter/material.dart';
import '../core/app_language.dart';
import '../widgets/ui_states.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLanguage.instance.text('سياسة الخصوصية', 'Privacy Policy'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          InlineNotice(
            warning: true,
            icon: Icons.gavel_outlined,
            text: AppLanguage.instance.text(
              'هذا وصف تقني لما يخزّنه التطبيق فعليًا في هذا الإصدار. راجعه قانونيًا قبل النشر إن احتجت صياغة رسمية.',
              'This is a technical description of what the app actually stores in this version. Have it reviewed for a formal legal wording before publishing if needed.',
            ),
          ),
          const SizedBox(height: 8),
          _Section(
            titleAr: 'ما يُخزَّن على جهازك',
            titleEn: 'What\'s stored on your device',
            bodyAr: 'المفضلة، سجل المشاهدة، وتفضيلات الإعدادات (اللغة، المظهر، الإشعارات، المشغّل) تُحفظ محليًا فقط عبر SharedPreferences. لا تُرسَل هذه البيانات إلى أي خادم.',
            bodyEn: 'Favorites, watch history, and settings preferences (language, appearance, notifications, player) are stored locally only, via SharedPreferences. This data is not sent to any server.',
          ),
          _Section(
            titleAr: 'الإعلانات والتحليلات',
            titleEn: 'Ads and analytics',
            bodyAr: 'هذا الإصدار يعمل بدون إعلانات أو تحليلات أو تشغيل فيديو.',
            bodyEn: 'This version runs without ads, analytics, or video playback.',
          ),
          _Section(
            titleAr: 'التشخيص المحلي',
            titleEn: 'Local diagnostics',
            bodyAr: 'يحتفظ التطبيق بتشخيص محلي فقط (عدد الطلبات، النجاح/الفشل، زمن الاستجابة) لمساعدتك على استكشاف مشاكل الاتصال. لا تُرسَل هذه البيانات لأي خادم، ويمكنك مسحها من الإعدادات.',
            bodyEn: 'The app keeps local-only diagnostics (request counts, success/failure, latency) to help you troubleshoot connectivity. This data isn\'t sent to any server, and you can clear it from Settings.',
          ),
          _Section(
            titleAr: 'بيانات الأنمي',
            titleEn: 'Anime data',
            bodyAr: 'عناوين الأنمي وصورها وتقييماتها تُجلب من خادم التطبيق، الذي بدوره يجلبها من مزودي بيانات تعريفية عامة (Jikan وAniList).',
            bodyEn: 'Anime titles, artwork, and ratings are fetched from the app\'s backend, which in turn sources them from public metadata providers (Jikan and AniList).',
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String titleAr;
  final String titleEn;
  final String bodyAr;
  final String bodyEn;

  const _Section({
    required this.titleAr,
    required this.titleEn,
    required this.bodyAr,
    required this.bodyEn,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLanguage.instance.text(titleAr, titleEn), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          Text(AppLanguage.instance.text(bodyAr, bodyEn), style: const TextStyle(height: 1.7)),
        ],
      ),
    );
  }
}
