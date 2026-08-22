import type { AnimeCharacter, AnimeProvider, AnimeRecord, AnimeRelation, AnimeRecommendation, EpisodeRecord, ProviderPage } from './types';
import { identityFromProvider } from './identity';

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

function studiosFrom(raw: Record<string, unknown>): string[] {
  const studios = Array.isArray(raw.studios) ? raw.studios : [];
  return studios
    .map(asMap)
    .filter((x): x is Record<string, unknown> => x !== null)
    .map((x) => asString(x.name))
    .filter((x): x is string => Boolean(x));
}

function trailerFrom(raw: Record<string, unknown>): { url: string | null; image: string | null } {
  const trailer = asMap(raw.trailer);
  if (!trailer) return { url: null, image: null };
  const images = asMap(trailer.images);
  return {
    url: asString(trailer.url) || asString(trailer.embed_url),
    image: asString(images?.maximum_image_url) || asString(images?.large_image_url) || asString(images?.image_url),
  };
}

function charactersFrom(raw: Record<string, unknown>): AnimeCharacter[] {
  const characters = Array.isArray(raw.characters) ? raw.characters : [];
  return characters.slice(0, 24).map(asMap).filter((x): x is Record<string, unknown> => x !== null).map((x) => {
    const character = asMap(x.character);
    const images = character ? asMap(character.images) : null;
    const jpg = images ? asMap(images.jpg) : null;
    return {
      id: asInt(character?.mal_id) ?? 0,
      name: asString(character?.name) || 'Unknown',
      imageUrl: asString(jpg?.image_url) || asString(jpg?.large_image_url),
      role: asString(x.role),
    };
  }).filter((x) => x.id > 0);
}

function relationsFrom(raw: Record<string, unknown>): AnimeRelation[] {
  const relations = Array.isArray(raw.relations) ? raw.relations : [];
  return relations.map(asMap).filter((x): x is Record<string, unknown> => x !== null).map((x) => ({
    relation: asString(x.relation) || 'Related',
    entries: (Array.isArray(x.entry) ? x.entry : []).map(asMap).filter((e): e is Record<string, unknown> => e !== null).map((e) => ({
      id: asInt(e.mal_id) ?? 0,
      title: asString(e.name) || 'Unknown',
      type: asString(e.type),
    })).filter((e) => e.id > 0),
  })).filter((x) => x.entries.length > 0);
}

function recommendationsFrom(raw: Record<string, unknown>): AnimeRecommendation[] {
  const rows = Array.isArray(raw.recommendations) ? raw.recommendations : [];
  return rows.slice(0, 12).map(asMap).filter((x): x is Record<string, unknown> => x !== null).map((x) => {
    const entry = asMap(x.entry);
    const images = asMap(entry?.images);
    const jpg = images ? asMap(images.jpg) : null;
    return {
      id: asInt(entry?.mal_id) ?? 0,
      title: asString(entry?.title) || 'Unknown',
      imageUrl: asString(jpg?.large_image_url) || asString(jpg?.image_url),
    };
  }).filter((x) => x.id > 0);
}

export function normalizeAnime(raw: unknown): AnimeRecord | null {
  const map = asMap(raw);
  const externalId = asInt(map?.mal_id);
  if (externalId == null || !map) return null;

  const identity = identityFromProvider('jikan', String(externalId), { malId: externalId });
  return {
    externalId: String(externalId),
    ...identity,
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
    source: asString(map.source),
    duration: asString(map.duration),
    airedFrom: asString(asMap(map.aired)?.from),
    airedTo: asString(asMap(map.aired)?.to),
    rating: asString(map.rating),
    rank: asInt(map.rank),
    members: asInt(map.members),
    popularity: asInt(map.popularity),
    season: asString(map.season),
    seasonYear: asInt(map.year),
    broadcastDay: asString(asMap(map.broadcast)?.day),
    broadcastTime: asString(asMap(map.broadcast)?.time),
    studioNames: studiosFrom(map),
    trailerUrl: trailerFrom(map).url,
    trailerImageUrl: trailerFrom(map).image,
    backgroundImageUrl: asString(map.background_image),
    characters: charactersFrom(map),
    relations: relationsFrom(map),
    recommendations: recommendationsFrom(map),
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

    let lastError: unknown;
    for (let attempt = 0; attempt < 2; attempt += 1) {
      let response: Response;
      try {
        response = await fetch(url.toString(), {
          headers: {
            Accept: 'application/json',
            'User-Agent': 'AnimePlatformAPI/2.0',
          },
        });
      } catch (error) {
        lastError = error;
        if (attempt === 1) throw error;
        await new Promise((resolve) => setTimeout(resolve, 750));
        continue;
      }

      if (response.ok) {
        const data = await response.json() as unknown;
        const map = asMap(data);
        if (!map) throw new Error('Invalid provider response');
        return map as JikanResponse;
      }

      const retryable = response.status === 429 || response.status >= 500;
      lastError = new Error(`Provider ${response.status}`);
      if (!retryable || attempt === 1) throw lastError;

      const retryAfter = Number(response.headers.get('Retry-After') || '1');
      const delaySeconds = Number.isFinite(retryAfter)
        ? Math.min(Math.max(retryAfter, 1), 3)
        : 1;
      await new Promise((resolve) => setTimeout(resolve, delaySeconds * 1000));
    }

    throw lastError instanceof Error ? lastError : new Error('Provider unavailable');
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
    const response = await this.get(`/anime/${encodeURIComponent(externalId)}/full`);
    return normalizeAnime(response.data);
  }

  async popularCharacters(page: number, limit: number): Promise<Array<Record<string, unknown>>> {
    const response = await this.get('/top/characters', {
      page: String(page),
      limit: String(Math.min(limit, 25)),
    });
    return Array.isArray(response.data)
      ? response.data.map(asMap).filter((x): x is Record<string, unknown> => x !== null)
      : [];
  }

  async characterDetails(id: string): Promise<Record<string, unknown> | null> {
    const response = await this.get(`/characters/${encodeURIComponent(id)}/full`);
    return asMap(response.data);
  }

  async schedule(day: string): Promise<AnimeRecord[]> {
    const safeDay = day.trim().toLowerCase();
    const response = await this.get(`/schedules/${encodeURIComponent(safeDay)}`, {
      sfw: 'true',
      filter: 'airing',
    });
    return Array.isArray(response.data)
      ? response.data.map(normalizeAnime).filter((x): x is AnimeRecord => x !== null)
      : [];
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
