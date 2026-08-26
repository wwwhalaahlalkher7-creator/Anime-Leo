# Anime Leo — External Source Index Architecture

Anime Leo can index public episode-page links from an external provider/feed without hosting, proxying, downloading, or extracting video streams.

## Contract

Configure an authorized feed with:
- `EXTERNAL_SOURCE_BASE`
- `EXTERNAL_SOURCE_PROVIDER_NAME`
- optional `EXTERNAL_SOURCE_API_KEY`

For an anime `123` and episode `4`, the adapter requests:
`GET /anime/123/episodes/4/sources`

Accepted response:
```json
{
  "sources": [
    {"url":"https://example.com/watch/123/4","provider":"example","language":"ar","label":"Example"}
  ]
}
```

Only `http`/`https` URLs are accepted. Anime Leo stores/returns the page URL as metadata; it does not proxy or cache video bytes.

The mobile app shows available external source pages and opens them with Android's external browser/app handler.

This adapter deliberately does not scrape or bypass anti-bot/access controls on third-party sites.
