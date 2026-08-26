import 'package:flutter/material.dart';
import '../core/app_language.dart';

class DisclaimerScreen extends StatelessWidget {
  const DisclaimerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLanguage.instance.text('إخلاء المسؤولية', 'Disclaimer'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Point(
            AppLanguage.instance.text(
              'التطبيق أداة تعريفية لمتابعة الأنمي (عناوين، صور، تقييمات، إحصائيات) — وليس منصة استضافة أو بث فيديو.',
              'The app is an anime discovery/tracking app (titles, artwork, ratings, stats) — not a video hosting or streaming platform.',
            ),
          ),
          _Point(
            AppLanguage.instance.text(
              'بنية تشغيل الفيديو في التطبيق مصمَّمة لعرض مصادر مرخّصة فقط عند ربطها؛ التطبيق لا يجلب أو يبث أي مصدر فيديو غير مصرح به.',
              'The app\'s video-playback architecture is built to surface licensed sources only, once one is connected; the app does not fetch or stream any unauthorized video source.',
            ),
          ),
          _Point(
            AppLanguage.instance.text(
              'بيانات الأنمي (العناوين والصور والتقييمات) تُجلب من مزودي بيانات تعريفية عامة (Jikan وAniList) وتخضع لحقوقهم الخاصة.',
              'Anime metadata (titles, artwork, ratings) is fetched from public metadata providers (Jikan and AniList) and remains subject to their own rights.',
            ),
          ),
          _Point(
            AppLanguage.instance.text(
              'جميع أسماء وشعارات الأنمي المعروضة ملك لأصحابها الأصليين ولا تُشير إلى أي انتساب أو تأييد.',
              'All displayed anime names and artwork belong to their original rights holders; display here doesn\'t imply affiliation or endorsement.',
            ),
          ),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  final String text;
  const _Point(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.only(top: 6, left: 8, right: 8), child: Icon(Icons.circle, size: 6)),
          Expanded(child: Text(text, style: const TextStyle(height: 1.7))),
        ],
      ),
    );
  }
}
