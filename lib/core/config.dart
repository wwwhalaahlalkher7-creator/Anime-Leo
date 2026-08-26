const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://anime-leo.www-halaahlalkher7.workers.dev/api',
);

const String appName = 'Anime Leo';
const String appVersion = '1.25.4';

/// Links for the Settings > Other section (Phase 7, see
/// docs/SETTINGS_SIDEBAR_PLAN.md). Left blank until the project has real
/// destinations; each is overridable at build time without a code change,
/// same as [apiBaseUrl]. UI that uses these treats an empty value as
/// "not configured yet" rather than attempting a broken link.
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

const String apiVersion = 'v1';
