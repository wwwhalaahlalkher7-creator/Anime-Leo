# V1.16.0 — Legal Video Architecture

Status: implemented architecture; playback remains disabled.

## Scope
- Introduce a reviewed licensed-video provider contract.
- Keep the default provider as a safe NoOp provider.
- Expose legal-video architecture capability separately from the playback feature flag.
- Keep `features.video = false` until an explicitly licensed provider is configured.
- Return structured policy information when an episode video is requested but no licensed source is configured.
- Prepare the Flutter player screen to consume a future licensed asset without adding unofficial sources or scraping logic.

## Explicitly unchanged
- D1 schema and catalog behavior.
- Existing catalog/provider manager architecture.
- Favorites and Watch History.
- Ads remain disabled.
- Analytics remain disabled.
- No video URLs or copyrighted streams were added.

## Provider requirements for a future implementation
A provider implementation must supply:
- Explicit distribution/playback rights.
- Stable provider identity.
- License/contract identifier.
- Rights scope appropriate to the requested content/territory.
- HTTPS stream URL supplied by the licensed provider.
- Optional subtitle URLs that are also authorized for distribution.

No provider should be enabled solely by adding a URL.
