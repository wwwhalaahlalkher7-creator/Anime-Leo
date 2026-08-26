import type { EpisodeRecord, ProviderPage } from './types';

/**
 * Arabic episode catalog contract.
 *
 * This adapter intentionally does not scrape or bypass third-party sites.
 * Configure it only with an API/feed that the project is authorized to use.
 * The expected response is:
 * {
 *   "data": [{
 *     "episode_number": 1,
 *     "title": "...",
 *     "thumbnail": "https://...",
 *     "duration": "24:10",
 *     "aired": "2026-08-01",
 *     "external_id": "provider-episode-id"
 *   }],
 *   "pagination": { "has_next_page": false }
 * }
 */
export interface ArabicEpisodeProvider {
  readonly name: string;
  readonly language: 'ar';
  listEpisodes(animeExternalId: string, page: number, limit: number): Promise<ProviderPage<EpisodeRecord>>;
  healthCheck(): Promise<boolean>;
}

interface ArabicEpisodeResponse {
  data?: unknown;
  pagination?: { has_next_page?: boolean };
}

function asMap(value: unknown): Record<string, unknown> | null {
  return value && typeof value === 'object' && !Array.isArray(value)
    ? value as Record<string, unknown>
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

function normalizeEpisode(raw: unknown, animeExternalId: string, providerName: string): EpisodeRecord | null {
  const map = asMap(raw);
  if (!map) return null;
  const number = asInt(map.episode_number ?? map.number ?? map.episode);
  if (number == null || number < 1) return null;

  const externalId = asString(map.external_id ?? map.id) ?? `${animeExternalId}:${number}`;
  return {
    externalId: `ar:${providerName}:${externalId}`,
    animeExternalId,
    episodeNumber: number,
    title: asString(map.title),
    thumbnail: asString(map.thumbnail ?? map.image),
    duration: asString(map.duration),
    aired: asString(map.aired ?? map.air_date),
    sources: [{
      provider: providerName,
      language: 'ar',
      available: true,
      externalId,
    }],
  };
}

export class ConfiguredArabicEpisodeProvider implements ArabicEpisodeProvider {
  readonly language = 'ar' as const;
  readonly name: string;
  private readonly baseUrl: string;
  private readonly apiKey?: string;

  constructor(baseUrl: string, name = 'arabic', apiKey?: string) {
    this.name = name;
    this.baseUrl = baseUrl.replace(/\/$/, '');
    this.apiKey = apiKey?.trim() || undefined;
  }

  private async get(path: string, params: Record<string, string> = {}): Promise<ArabicEpisodeResponse> {
    const url = new URL(`${this.baseUrl}${path}`);
    Object.entries(params).forEach(([key, value]) => url.searchParams.set(key, value));

    const headers: Record<string, string> = { Accept: 'application/json' };
    if (this.apiKey) headers.Authorization = `Bearer ${this.apiKey}`;

    const response = await fetch(url.toString(), { headers });
    if (!response.ok) throw new Error(`Arabic episode provider ${response.status}`);

    const body = asMap(await response.json());
    if (!body) throw new Error('Invalid Arabic episode provider response');
    return body as ArabicEpisodeResponse;
  }

  async listEpisodes(animeExternalId: string, page: number, limit: number): Promise<ProviderPage<EpisodeRecord>> {
    const response = await this.get(`/anime/${encodeURIComponent(animeExternalId)}/episodes`, {
      page: String(page),
      limit: String(limit),
    });
    const items = Array.isArray(response.data)
      ? response.data
          .map((item) => normalizeEpisode(item, animeExternalId, this.name))
          .filter((item): item is EpisodeRecord => item !== null)
      : [];

    return {
      items,
      page,
      hasNextPage: response.pagination?.has_next_page === true,
    };
  }

  async healthCheck(): Promise<boolean> {
    try {
      await this.get('/health');
      return true;
    } catch (_) {
      return false;
    }
  }
}

export class NoOpArabicEpisodeProvider implements ArabicEpisodeProvider {
  readonly name = 'none';
  readonly language = 'ar' as const;

  async listEpisodes(_animeExternalId: string, page: number, _limit: number): Promise<ProviderPage<EpisodeRecord>> {
    return { items: [], page, hasNextPage: false };
  }

  async healthCheck(): Promise<boolean> {
    return false;
  }
}
