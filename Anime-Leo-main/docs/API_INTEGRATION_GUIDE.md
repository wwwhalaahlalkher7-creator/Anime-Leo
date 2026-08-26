# Anime Leo — API Integration Guide

## الهدف

كل تكاملات Anime Leo يجب أن تمر من نقطة موحدة:

```text
Flutter
  ↓
ApiConfig.baseUrl
  ↓
Anime Leo Backend / Worker
  ↓
Provider adapters
  ├─ Anime metadata
  ├─ Episodes
  ├─ Subtitles
  └─ Authorized video
```

## 1. أين أضع Base URL؟

في GitHub Actions:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://YOUR-WORKER.example.workers.dev/api
```

وفي Flutter يتم قراءته من:

```text
lib/config/api_config.dart
```

لا تكرر عنوان الـ API داخل الشاشات.

## 2. أين أضع مفاتيح APIs؟

**لا تضع أي secret داخل Flutter.**

ضعه في Backend/Cloudflare Secrets أو environment variables.

أمثلة:

```text
OPENSUBTITLES_API_KEY
TMDB_API_TOKEN
VIDEO_PROVIDER_API_KEY
```

## 3. إضافة API جديد

1. أنشئ Adapter داخل Backend.
2. اجعل الـ Adapter يتعامل مع المصدر الخارجي.
3. حوّل الاستجابة إلى نموذج Anime Leo الموحد.
4. أضف endpoint للـ Worker.
5. اختبر endpoint بـ curl.
6. أضف method إلى `AnimeApiService`.
7. أضف/حدّث model.
8. اربطه بالواجهة.
9. شغّل `flutter analyze` و`flutter test`.

## 4. الترجمة

الطبقة المستهدفة:

```text
Episode
 ↓
Subtitle Provider
 ├─ English
 ├─ Japanese
 └─ Arabic
```

يمكن استخدام OpenSubtitles كموفر ترجمة، بشرط الالتزام بشروطه ووضع credentials في الـ Backend فقط.

## 5. الفيديو

لا نضع روابط بث غير مصرح بها داخل التطبيق.

الـ Backend يجب أن يتعامل مع **مصدر فيديو مصرح به** ويعيد صيغة موحدة:

```json
{
  "streamUrl": "...",
  "type": "hls",
  "quality": "1080p",
  "subtitles": []
}
```

## 6. أوامر البناء

مثال:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release   --dart-define=API_BASE_URL=https://YOUR-WORKER.example.workers.dev/api
```

إذا احتجت إلى تفعيل Provider اختياري:

```bash
--dart-define=ENABLE_OPENSUBTITLES=true
--dart-define=ENABLE_VIDEO_PROVIDER=true
```

## 7. اختبار API

```bash
curl -i https://YOUR-WORKER.example.workers.dev/api/health
```

ثم اختبر endpoints الفعلية الموجودة في Worker قبل ربط شاشة جديدة.

## 8. قاعدة أمنية

- لا API keys في Dart.
- لا tokens في assets.
- لا secrets في Git.
- لا روابط مصادر غير مصرح بها.
- الـ Worker هو طبقة التكامل والتحكم.
