# Anime Leo V1.28 — Playback Sources

## Primary playback

Anime Leo V1.28 uses **ani-cli-arabic** as the primary playback adapter. The
adapter follows the project's documented API flow: obtain credentials,
resolve the anime/episode server list, and expose the returned playable URLs
to the Android player. Anime Leo does not store video bytes.

Upstream project: https://github.com/np4abdou1/ani-cli-arabic
License: GPL-3.0

## Arabic dub metadata

**MyDubList** is used as the Arabic-dub availability dataset. This is metadata
only in V1.28; the player remains subtitle-first and does not expose an audio
track/dub selector.

Upstream project: https://github.com/Joelis57/MyDubList
Dataset license: CC BY 4.0
Required attribution: "Dub data © MyDubList - https://mydublist.com - (CC BY 4.0)"

## Source policy

For this Anime Leo release, the project owner has designated the configured
playback sources as authorized project sources. The adapter therefore treats
the source integration as an approved production dependency rather than a
placeholder/NoOp provider.
