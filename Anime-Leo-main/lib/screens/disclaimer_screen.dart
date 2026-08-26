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
              'بيانات الأنمي (العناوين والصور والتقييمات) تُجلب من مزودي بيانات تعريفية عامة (Jikan وAniList) وتخضع لحقوقهم الخاصة.',
              'Anime metadata (titles, artwork, and ratings) is fetched directly from Jikan in the Beta build and remains subject to the provider\'s rights.',
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
