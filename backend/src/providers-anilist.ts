import type { AnimeProvider, AnimeRecord, EpisodeRecord, ProviderPage } from './types';

type AniListMedia = {
  id: number;
  title?: { english?: string | null; romaji?: string | null; native?: string | null };
  description?: string | null;
  coverImage?: { extraLarge?: string | null; large?: string | null; medium?: string | null };
  genres?: string[];
  status?: string | null;
  episodes?: number | null;
  averageScore?: number | null;
  startDate?: { year?: number | null };
  format?: string | null;
};

type AniListResponse = {
  data?: {
    Page?: {
      pageInfo?: { currentPage?: number; hasNextPage?: boolean };
      media?: AniListMedia[];
    };
    Media?: AniListMedia | null;
  };
};

function cleanHtml(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const clean = value.replace(/<br\s*\/?>/gi, '\n').replace(/<[^>]+>/g, '').trim();
  return clean || null;
}

function externalId(id: number): string {
  // Negative IDs reserve AniList records and cannot collide with MAL/Jikan IDs.
  return `-${id}`;
}

function parseAniListId(externalIdValue: string): number | null {
  const value = Number.parseInt(externalIdValue, 10);
  return Number.isInteger(value) && value < 0 ? Math.abs(value) : null;
}

function normalizeAnime(raw: AniListMedia | null | undefined): AnimeRecord | null {
  if (!raw || !Number.isInteger(raw.id)) return null;
  const title = raw.title?.english?.trim() || raw.title?.romaji?.trim() || raw.title?.native?.trim();
  if (!title) return null;

  return {
    externalId: externalId(raw.id),
    title,
    titleAr: null,
    synopsis: cleanHtml(raw.description),
    imageUrl: raw.coverImage?.extraLarge || raw.coverImage?.large || raw.coverImage?.medium || null,
    genres: Array.isArray(raw.genres) ? raw.genres.map(String) : [],
    status: raw.status ?? null,
    episodes: raw.episodes ?? null,
    score: raw.averageScore == null ? null : raw.averageScore / 10,
    year: raw.startDate?.year ?? null,
    type: raw.format ?? null,
  };
}

export class AniListProvider implements AnimeProvider {
  readonly name = 'anilist';
  private readonly baseUrl: string;

  constructor(baseUrl = 'https://graphql.anilist.co') {
    this.baseUrl = baseUrl.replace(/\/$/, '');
  }

  private async query(
    query: string,
    variables: Record<string, unknown> = {},
  ): Promise<AniListResponse> {
    const response = await fetch(this.baseUrl, {
      method: 'POST',
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
        'User-Agent': 'AnimePlatformAPI/1.20',
      },
      body: JSON.stringify({ query, variables }),
    });

    if (!response.ok) throw new Error(`AniList provider ${response.status}`);
    const data = await response.json() as unknown;
    if (!data || typeof data !== 'object') throw new Error('Invalid AniList response');
    return data as AniListResponse;
  }

  async search(query: string, page: number, limit: number): Promise<ProviderPage<AnimeRecord>> {
    const response = await this.query(`
      query ($search: String, $page: Int, $perPage: Int) {
        Page(page: $page, perPage: $perPage) {
          pageInfo { currentPage hasNextPage }
          media(search: $search, type: ANIME, isAdult: false, sort: POPULARITY_DESC) {
            id
            title { english romaji native }
            description(asHtml: false)
            coverImage { extraLarge large medium }
            genres
            status
            episodes
            averageScore
            startDate { year }
            format
          }
        }
      }
    `, {'search': query, 'page': page, 'perPage': limit});

    const pageData = response.data?.Page;
    const items = (pageData?.media ?? [])
      .map(normalizeAnime)
      .filter((item): item is AnimeRecord => item !== null);

    return {
      items,
      page: pageData?.pageInfo?.currentPage ?? page,
      hasNextPage: pageData?.pageInfo?.hasNextPage === true,
    };
  }

  async top(page: number, limit: number): Promise<ProviderPage<AnimeRecord>> {
    const response = await this.query(`
      query ($page: Int, $perPage: Int) {
        Page(page: $page, perPage: $perPage) {
          pageInfo { currentPage hasNextPage }
          media(type: ANIME, isAdult: false, sort: SCORE_DESC) {
            id
            title { english romaji native }
            description(asHtml: false)
            coverImage { extraLarge large medium }
            genres
            status
            episodes
            averageScore
            startDate { year }
            format
          }
        }
      }
    `, {'page': page, 'perPage': limit});

    const pageData = response.data?.Page;
    const items = (pageData?.media ?? [])
      .map(normalizeAnime)
      .filter((item): item is AnimeRecord => item !== null);

    return {
      items,
      page: pageData?.pageInfo?.currentPage ?? page,
      hasNextPage: pageData?.pageInfo?.hasNextPage === true,
    };
  }

  async details(externalIdValue: string): Promise<AnimeRecord | null> {
    const id = parseAniListId(externalIdValue);
    if (id == null) throw new Error('Not an AniList external id');

    const response = await this.query(`
      query ($id: Int) {
        Media(id: $id, type: ANIME) {
          id
          title { english romaji native }
          description(asHtml: false)
          coverImage { extraLarge large medium }
          genres
          status
          episodes
          averageScore
          startDate { year }
          format
        }
      }
    `, {'id': id});

    return normalizeAnime(response.data?.Media);
  }

  async episodes(externalIdValue: string, page: number, limit: number): Promise<ProviderPage<EpisodeRecord>> {
    const id = parseAniListId(externalIdValue);
    if (id == null) throw new Error('Not an AniList external id');
    return { items: [], page, hasNextPage: false };
  }

  async healthCheck(): Promise<boolean> {
    try {
      const response = await this.query(`
        query { Media(id: 20, type: ANIME) { id } }
      `);
      return response.data?.Media?.id === 20;
    } catch (_) {
      return false;
    }
  }
}
