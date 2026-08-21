import '../config/api_config.dart';

const String apiBaseUrl = ApiConfig.baseUrl;

const String appName = 'Anime Leo';
const String appVersion = '1.29.0';

/// Links for the Settings > Other section.
const String officialWebsiteUrl = String.fromEnvironment(
  'OFFICIAL_WEBSITE_URL',
  defaultValue: '',
);

const String contactEmail = String.fromEnvironment(
  'CONTACT_EMAIL',
  defaultValue: 'www.halaahlalkher10@gmail.com',
);

const String telegramUrl = String.fromEnvironment(
  'TELEGRAM_URL',
  defaultValue: 'https://t.me/animeleo_support',
);

const bool enableAds = bool.fromEnvironment(
  'ENABLE_ADS',
  defaultValue: false,
);

/// Client/API compatibility identifier sent to the backend.
const String apiVersion = '1.29';
