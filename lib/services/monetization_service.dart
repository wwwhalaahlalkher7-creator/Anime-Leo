enum MonetizationConsent { unknown, granted, denied }

enum AdPlacement { homeFeed, details, player, search, settings }

class MonetizationPolicy {
  final bool enabled;
  final String provider;
  final bool consentRequired;
  final Set<AdPlacement> allowedPlacements;

  const MonetizationPolicy({
    required this.enabled,
    required this.provider,
    required this.consentRequired,
    required this.allowedPlacements,
  });

  static const disabled = MonetizationPolicy(
    enabled: false,
    provider: 'none',
    consentRequired: true,
    allowedPlacements: <AdPlacement>{},
  );

  bool canShow(AdPlacement placement, MonetizationConsent consent) {
    if (!enabled || provider == 'none') return false;
    if (consentRequired && consent != MonetizationConsent.granted) return false;
    return allowedPlacements.contains(placement);
  }
}

abstract class MonetizationService {
  MonetizationPolicy get policy;
  MonetizationConsent get consent;

  Future<void> initialize();
  Future<void> setConsent(MonetizationConsent value);
  bool canShow(AdPlacement placement);
  Future<void> dispose();
}

/// V1.17 preparation layer. No ad SDK is bundled and no ad network is active.
/// A future provider must be explicitly reviewed and injected behind this API.
class NoOpMonetizationService implements MonetizationService {
  @override
  MonetizationPolicy get policy => MonetizationPolicy.disabled;

  @override
  MonetizationConsent get consent => MonetizationConsent.unknown;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> setConsent(MonetizationConsent value) async {}

  @override
  bool canShow(AdPlacement placement) => false;

  @override
  Future<void> dispose() async {}
}
