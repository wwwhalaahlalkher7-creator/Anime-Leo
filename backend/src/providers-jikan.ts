import type { AnimeProvider, AnimeRecord, EpisodeRecord, ProviderPage } from './types';

interface JikanResponse {
  data?: unknown;
  pagination?: {
    has_next_page?: boolean;
  };
}

function asMap(value: unknown): Record<string, unknown> | null {
  return value && typeof value === 'object' && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function asString(value: unknown): string | null {
  return value == null ? null : String(value);
}

function asNumber(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

function asInt(value: unknown): number | null {
  const n = asNumber(value);
  return n == null ? null : Math.trunc(n);
}

function imageFrom(raw: Record<string, unknown>): string | null {
  const images = asMap(raw.images);
  const jpg = images ? asMap(images.jpg) : null;
  return asString(jpg?.large_image_url ?? jpg?.image_url);
}

function genresFrom(raw: Record<string, unknown>): string[] {
  const genres = Array.isArray(raw.genres) ? raw.genres : [];
  return genres
    .map(asMap)
    .filter((x): x is Record<string, unknown> => x !== null)
    .map((x) => asString(x.name))
    .filter((x): x is string => Boolean(x));
}

function normalizeAnime(raw: unknown): AnimeRecord | null {
  const map = asMap(raw);
  const externalId = asInt(map?.mal_id);
  if (externalId == null || !map) return null;

  return {
    externalId: String(externalId),
    title: asString(map.title_english) || asString(map.title) || 'Unknown Anime',
    titleAr: null,
    synopsis: asString(map.synopsis),
    imageUrl: imageFrom(map),
    genres: genresFrom(map),
    status: asString(map.status),
    episodes: asInt(map.episodes),
    score: asNumber(map.score),
    year: asInt(map.year),
    type: asString(map.type),
  };
}

function normalizeEpisode(raw: unknown, animeExternalId: string): EpisodeRecord | null {
  const map = asMap(raw);
  const number = asInt(map?.mal_id);
  if (number == null || !map) return null;

  return {
    externalId: `${animeExternalId}:${number}`,
    animeExternalId,
    episodeNumber: number,
    title: asString(map.title),
    thumbnail: asString(map.images && asMap(map.images)?.jpg && asMap(asMap(map.images)?.jpg)?.image_url),
    duration: asString(map.duration),
    aired: asString(map.aired),
  };
}

export class JikanProvider implements AnimeProvider {
  readonly name = 'jikan';
  private readonly baseUrl: string;

  constructor(baseUrl: string) {
    this.baseUrl = baseUrl.replace(/\/$/, '');
  }

  private async get(path: string, params: Record<string, string> = {}): Promise<JikanResponse> {
    const url = new URL(`${this.baseUrl}${path}`);
    Object.entries(params).forEach(([key, value]) => url.searchParams.set(key, value));

    const response = await fetch(url.toString(), {
      headers: {
        Accept: 'application/json',
        'User-Agent': 'AnimePlatformAPI/1.12',
      },
    });

    if (!response.ok) {
      throw new Error(`Provider ${response.status}`);
    }

    const data = await response.json() as unknown;
    const map = asMap(data);
    if (!map) throw new Error('Invalid provider response');
    return map as JikanResponse;
  }

  async search(query: string, page: number, limit: number): Promise<ProviderPage<AnimeRecord>> {
    const response = await this.get('/anime', {
      q: query,
      page: String(page),
      limit: String(limit),
      sfw: 'true',
      order_by: 'popularity',
      sort: 'asc',
    });
    const items = Array.isArray(response.data)
      ? response.data.map(normalizeAnime).filter((x): x is AnimeRecord => x !== null)
      : [];
    return { items, page, hasNextPage: response.pagination?.has_next_page === true };
  }

  /**
   * Background catalog scanner. Unlike `top()`, this can walk the provider
   * catalogue using a stable sort key and therefore does not depend on what
   * the mobile client happens to request.
   */
  async browse(
    page: number,
    limit: number,
    orderBy: 'popularity' | 'start_date' = 'popularity',
    sort: 'asc' | 'desc' = 'asc',
  ): Promise<ProviderPage<AnimeRecord>> {
    const response = await this.get('/anime', {
      page: String(page),
      limit: String(limit),
      sfw: 'true',
      order_by: orderBy,
      sort,
    });
    const items = Array.isArray(response.data)
      ? response.data.map(normalizeAnime).filter((x): x is AnimeRecord => x !== null)
      : [];
    return { items, page, hasNextPage: response.pagination?.has_next_page === true };
  }

  async top(page: number, limit: number): Promise<ProviderPage<AnimeRecord>> {
    const response = await this.get('/top/anime', {
      page: String(page),
      limit: String(limit),
      sfw: 'true',
    });
    const items = Array.isArray(response.data)
      ? response.data.map(normalizeAnime).filter((x): x is AnimeRecord => x !== null)
      : [];
    return { items, page, hasNextPage: response.pagination?.has_next_page === true };
  }

  async details(externalId: string): Promise<AnimeRecord | null> {
    const response = await this.get(`/anime/${encodeURIComponent(externalId)}`);
    return normalizeAnime(response.data);
  }

  async episodes(externalId: string, page: number, limit: number): Promise<ProviderPage<EpisodeRecord>> {
    const response = await this.get(`/anime/${encodeURIComponent(externalId)}/episodes`, {
      page: String(page),
    });
    const items = Array.isArray(response.data)
      ? response.data.map((item) => normalizeEpisode(item, externalId)).filter((x): x is EpisodeRecord => x !== null)
      : [];
    return { items: items.slice(0, limit), page, hasNextPage: response.pagination?.has_next_page === true };
  }

  async healthCheck(): Promise<boolean> {
    try {
      // Jikan search/top can fail when MyAnimeList is unavailable even while
      // individual details remain reachable. Health should test the endpoint
      // the catalog bootstrap actually relies on.
      await this.get('/anime/20');
      return true;
    } catch (_) {
      return false;
    }
  }
}
