# V1.17.0 — Monetization Preparation

Status: implemented preparation layer; monetization remains disabled.

## Scope
- Add a provider-neutral monetization policy and consent contract.
- Keep the default monetization provider as `none`.
- Keep all ad placements disabled until an explicitly reviewed provider is configured.
- Require explicit consent before any future consent-gated placement can display.
- Expose monetization readiness in Remote Config without enabling monetization.
- Keep analytics disabled and do not introduce ad/monetization event collection.

## Explicitly unchanged
- D1 schema and catalog behavior.
- Provider Manager and Jikan provider.
- Legal Video Architecture from V1.16.0.
- Favorites and Watch History.
- Ads remain disabled.
- Analytics remain disabled.
- No ad SDK or ad network was added.
- No payment/billing integration was added.

## Future provider requirements
A monetization provider must be reviewed before activation and must define:
- Provider identity and SDK version.
- Supported regions and legal basis.
- Consent requirements and privacy disclosures.
- Allowed placement IDs.
- Frequency/capping rules.
- A kill switch and safe disabled fallback.

No provider should be enabled solely by changing a URL or build flag.
