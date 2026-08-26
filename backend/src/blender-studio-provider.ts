import type { ProviderPage } from './types';

/**
 * Blender Studio (video.blender.org) animation provider — Option 1 from
 * docs/VIDEO_SOURCE_RESEARCH.md.
 *
 * video.blender.org is the Blender Foundation's own PeerTube instance. Every
 * title returned here is an official open-movie short (Big Buck Bunny,
 * Sintel, Elephants Dream, Tears of Steel, etc.) published by the rights
 * holder itself under Creative Commons Attribution. This is animation, not
 * anime — it belongs behind the plan's separate "Animation List" content
 * type (Phase 8 of SETTINGS_SIDEBAR_PLAN.md), not the anime episode/video
 * pipeline in video-provider.ts.
 *
 * License note: CC BY still requires attribution, and the exact version
 * (2.5/3.0/4.0) and scope can differ per asset — e.g. Big Buck Bunny's film
 * is CC BY 3.0 but its musical score was released separately under
 * CC BY-NC-ND. This provider surfaces the `licence` label PeerTube reports
 * for each video rather than hardcoding one license string, and every
 * AnimationAsset carries a ready-to-render attribution line — the caller
 * (UI) must display it wherever the title plays or is listed, not just log
 * it. This does not replace spot-checking new titles before launch; it just
 * avoids the app silently dropping the credit PeerTube already gives us.
 *
 * Split mirrors the anime pattern (catalog.ts's metadata calls vs.
 * video-provider.ts's getEpisodeVideo): `list()` is cheap catalog data for
 * a grid, `getAsset()` is the heavier per-title call that resolves an
 * actual playable stream URL, fetched lazily when a title is opened.
 */

export interface AnimationSummary {
  externalId: string;
  title: string;
  description?: string | null;
  thumbnailUrl?: string | null;
  durationSeconds?: number | null;
  publishedAt?: string | null;
  provider: string;
}

export interface AnimationAsset extends AnimationSummary {
  streamUrl: string | null;
  downloadUrl?: string | null;
  licenseLabel?: string | null;
  attribution: string;
  sourceUrl: string;
}

export interface AnimationProvider {
  readonly name: string;
  readonly licenseId: string;
  list(page: number, limit: number): Promise<ProviderPage<AnimationSummary>>;
  getAsset(externalId: string): Promise<AnimationAsset | null>;
  healthCheck(): Promise<boolean>;
}

function asMap(value: unknown): Record<string, unknown> | null {
  return value && typeof value === 'object' && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;
}

function asString(value: unknown): string | null {
  return value == null ? null : String(value);
}

function asInt(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) return Math.trunc(value);
  if (typeof value === 'string' && /^\d+$/.test(value.trim())) return Number.parseInt(value.trim(), 10);
  return null;
}

function asArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

export class BlenderStudioAnimationProvider implements AnimationProvider {
  readonly name = 'blender-studio';
  readonly licenseId = 'cc-by-per-video';
  private readonly baseUrl: string;
  private readonly channelHandle: string;

  constructor(baseUrl = 'https://video.blender.org', channelHandle = 'blender_channel') {
    this.baseUrl = baseUrl.replace(/\/$/, '');
    this.channelHandle = channelHandle;
  }

  private async get(path: string, params: Record<string, string> = {}): Promise<Record<string, unknown>> {
    const url = new URL(`${this.baseUrl}${path}`);
    Object.entries(params).forEach(([key, value]) => url.searchParams.set(key, value));

    const response = await fetch(url.toString(), { headers: { Accept: 'application/json' } });
    if (!response.ok) throw new Error(`Blender Studio provider ${response.status}`);

    const body = asMap(await response.json());
    if (!body) throw new Error('Invalid Blender Studio provider response');
    return body;
  }

  private absoluteUrl(path: unknown): string | null {
    const value = asString(path);
    if (!value) return null;
    return value.startsWith('http') ? value : `${this.baseUrl}${value}`;
  }

  private attributionFor(title: string, licenseLabel: string | null): string {
    // Blender Foundation's own credit line, as required by their open-movie
    // license pages (e.g. peach.blender.org/about) — "Blender Foundation |
    // www.blender.org" — plus whatever specific license PeerTube reports for
    // this video, since it can vary per title/asset.
    const license = licenseLabel || 'Creative Commons Attribution';
    return `"${title}" — © Blender Foundation, blender.org (${license})`;
  }

  private summaryFromListItem(raw: unknown): AnimationSummary | null {
    const map = asMap(raw);
    if (!map) return null;
    const uuid = asString(map.uuid ?? map.shortUUID ?? map.id);
    const title = asString(map.name);
    if (!uuid || !title) return null;

    const thumbnails = asArray(map.thumbnails);
    const firstThumb = asMap(thumbnails[0]);
    const thumbnailPath = firstThumb?.path ?? map.thumbnailPath;

    return {
      externalId: `blender:${uuid}`,
      title,
      description: asString(map.description ?? map.truncatedDescription),
      thumbnailUrl: this.absoluteUrl(thumbnailPath),
      durationSeconds: asInt(map.duration),
      publishedAt: asString(map.publishedAt),
      provider: this.name,
    };
  }

  async list(page: number, limit: number): Promise<ProviderPage<AnimationSummary>> {
    const start = String(Math.max(0, (page - 1) * limit));
    const response = await this.get(`/api/v1/video-channels/${encodeURIComponent(this.channelHandle)}/videos`, {
      start,
      count: String(limit),
      sort: '-publishedAt',
    });

    const items = asArray(response.data)
      .map((item) => this.summaryFromListItem(item))
      .filter((item): item is AnimationSummary => item !== null);

    const total = asInt(response.total) ?? items.length;
    const hasNextPage = (page - 1) * limit + items.length < total;

    return { items, page, hasNextPage };
  }

  async getAsset(externalId: string): Promise<AnimationAsset | null> {
    const uuid = externalId.startsWith('blender:') ? externalId.slice('blender:'.length) : externalId;
    if (!uuid) return null;

    let raw: Record<string, unknown>;
    try {
      raw = await this.get(`/api/v1/videos/${encodeURIComponent(uuid)}`);
    } catch (_) {
      return null;
    }

    const title = asString(raw.name);
    if (!title) return null;

    const licence = asMap(raw.licence);
    const licenseLabel = licence ? asString(licence.label) : null;

    // Prefer the HLS master playlist (works with any standard HLS-capable
    // player); fall back to a progressive file if the instance exposes one.
    const playlists = asArray(raw.streamingPlaylists);
    const firstPlaylist = asMap(playlists[0]);
    const streamUrl = firstPlaylist ? asString(firstPlaylist.playlistUrl) : null;

    const files = asArray(raw.files);
    const firstFile = asMap(files[0]);
    const downloadUrl = firstFile ? asString(firstFile.fileUrl) : null;

    const thumbnails = asArray(raw.thumbnails);
    const firstThumb = asMap(thumbnails[0]);
    const thumbnailPath = firstThumb?.path ?? raw.thumbnailPath;

    return {
      externalId: `blender:${uuid}`,
      title,
      description: asString(raw.description),
      thumbnailUrl: this.absoluteUrl(thumbnailPath),
      durationSeconds: asInt(raw.duration),
      publishedAt: asString(raw.publishedAt),
      provider: this.name,
      streamUrl,
      downloadUrl,
      licenseLabel,
      attribution: this.attributionFor(title, licenseLabel),
      sourceUrl: `${this.baseUrl}/w/${uuid}`,
    };
  }

  async healthCheck(): Promise<boolean> {
    try {
      const response = await fetch(`${this.baseUrl}/api/v1/video-channels/${encodeURIComponent(this.channelHandle)}`, {
        headers: { Accept: 'application/json' },
      });
      return response.ok;
    } catch (_) {
      return false;
    }
  }
}

/** Safe default until this is actually wired into an Animation List route. */
export class NoOpAnimationProvider implements AnimationProvider {
  readonly name = 'none';
  readonly licenseId = 'not-configured';

  async list(page: number, _limit: number): Promise<ProviderPage<AnimationSummary>> {
    return { items: [], page, hasNextPage: false };
  }

  async getAsset(_externalId: string): Promise<AnimationAsset | null> {
    return null;
  }

  async healthCheck(): Promise<boolean> {
    return false;
  }
}
