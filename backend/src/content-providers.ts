export type ContentKind = 'manga' | 'animation';

export interface ContentItem {
  id: string;
  title: string;
  titleAr?: string | null;
  synopsis?: string | null;
  imageUrl?: string | null;
  score?: number | null;
  year?: number | null;
  type?: string | null;
  source: string;
  sourceUrl?: string | null;
}

export interface ContentPage {
  items: ContentItem[];
  page: number;
  hasNextPage: boolean;
  source: string;
  arabic: boolean;
}

async function fetchJson(url: string, init?: RequestInit): Promise<any> {
  let lastError: unknown;

  for (let attempt = 0; attempt < 2; attempt += 1) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 12000);
    try {
      const response = await fetch(url, {
        ...init,
        signal: controller.signal,
        headers: {
          Accept: 'application/json',
          'User-Agent': 'AnimeLeo/2.0 (MangaDex API client)',
          ...(init?.headers || {}),
        },
      });

      if (response.ok) return await response.json();

      const retryable = response.status === 429 || response.status >= 500;
      lastError = new Error(`upstream_${response.status}`);
      if (!retryable || attempt === 1) throw lastError;

      const retryAfter = Number(response.headers.get('Retry-After') || '1');
      await new Promise((resolve) => setTimeout(resolve, Math.min(Math.max(retryAfter, 1), 3) * 1000));
    } catch (error) {
      lastError = error;
      if (attempt === 1) throw error;
    } finally {
      clearTimeout(timer);
    }
  }

  throw lastError instanceof Error ? lastError : new Error('upstream_unavailable');
}

function mangaItem(row: any): ContentItem | null {
  const id = typeof row?.id === 'string' ? row.id : '';
  const attributes = row?.attributes || {};
  if (!id || !attributes.title) return null;

  const titles = attributes.title || {};
  const title = titles.en || Object.values(titles)[0];
  const description = attributes.description || {};
  const titleAr = titles.ar || null;
  const synopsisAr = description.ar || null;
  const year = Number(attributes.year) || null;
  const score = Number(attributes.rating?.average) || null;

  const cover = Array.isArray(row?.relationships)
    ? row.relationships.find((r: any) => r?.type === 'cover_art')
    : null;
  const fileName = cover?.attributes?.fileName;
  const imageUrl = fileName
    ? `https://uploads.mangadex.org/covers/${id}/${fileName}.256.jpg`
    : null;

  return {
    id,
    title: String(title || 'Unknown Manga'),
    titleAr: titleAr ? String(titleAr) : null,
    synopsis: synopsisAr ? String(synopsisAr) : Object.values(description)[0]?.toString() || null,
    imageUrl,
    score,
    year,
    type: attributes.type ? String(attributes.type) : 'manga',
    source: 'mangadex',
    sourceUrl: `https://mangadex.org/title/${id}`,
  };
}

async function manga(page: number, limit: number): Promise<ContentPage> {
  const offset = (page - 1) * limit;

  // Prefer titles that have Arabic chapters, but do not hide the whole
  // Manga/Manhwa catalog when MangaDex has no Arabic chapter for a title.
  // The previous release applied `availableTranslatedLanguage[]=ar` and
  // `hasAvailableChapters=true` directly to the catalog query, which could
  // make the section return zero titles even though MangaDex had manga/manhwa.
  const base = new URLSearchParams({
    limit: String(Math.min(limit, 100)),
    offset: String(offset),
    'order[followedCount]': 'desc',
    'contentRating[]': 'safe',
    'includes[]': 'cover_art',
  });

  async function request(params: URLSearchParams) {
    return fetchJson(`https://api.mangadex.org/manga?${params.toString()}`);
  }

  const arabicParams = new URLSearchParams(base);
  arabicParams.set('availableTranslatedLanguage[]', 'ar');
  arabicParams.set('hasAvailableChapters', 'true');

  let json: any;
  let raw: any[] = [];

  try {
    json = await request(arabicParams);
    raw = Array.isArray(json?.data) ? json.data : [];
  } catch (_) {
    // MangaDex can reject optional query combinations temporarily. Do not
    // turn that into an empty Manga/Manhwa section; retry with the broad,
    // safe catalog query.
    json = null;
  }

  // Fallback to the complete safe MangaDex catalog. This includes both
  // Japanese manga and Korean/Chinese manhwa instead of hiding them merely
  // because an Arabic chapter is not currently indexed.
  if (!raw.length) {
    json = await request(base);
    raw = Array.isArray(json?.data) ? json.data : [];
  }

  const items = raw
    .map(mangaItem)
    .filter((item: ContentItem | null): item is ContentItem => item !== null);

  const total = Number(json?.total) || 0;
  return {
    items,
    page,
    hasNextPage: offset + items.length < total,
    source: 'mangadex',
    arabic: true,
  };
}

function tmdbItem(row: any): ContentItem | null {
  const id = Number(row?.id);
  if (!Number.isFinite(id) || id <= 0) return null;
  // Always request English metadata so external catalog titles remain English
  // in both Arabic and English app interfaces.
  const title = row?.name || row?.original_name || 'Unknown Animation';
  const firstAirDate = String(row?.first_air_date || '');
  const year = firstAirDate.length >= 4 ? Number(firstAirDate.slice(0, 4)) : null;
  const score = Number(row?.vote_average) || null;

  return {
    id: `tmdb:${id}`,
    title: String(title),
    titleAr: null,
    synopsis: row?.overview ? String(row.overview) : null,
    imageUrl: row?.poster_path ? `https://image.tmdb.org/t/p/w500${row.poster_path}` : null,
    score,
    year,
    type: 'animation',
    source: 'tmdb',
    sourceUrl: `https://www.themoviedb.org/tv/${id}`,
  };
}

async function animation(page: number, limit: number, token: string, category = 'popular'): Promise<ContentPage> {
  const params = new URLSearchParams({
    language: 'en-US',
    page: String(page),
    sort_by: 'popularity.desc',
    include_adult: 'false',
    with_genres: '16',
  });

  switch (category) {
    case 'anime':
      params.set('with_origin_country', 'JP');
      params.set('with_original_language', 'ja');
      break;
    case 'global':
      params.set('without_origin_country', 'JP');
      break;
    case 'top_rated':
      params.set('sort_by', 'vote_average.desc');
      params.set('vote_count.gte', '50');
      break;
    case 'latest':
      params.set('sort_by', 'first_air_date.desc');
      params.set('air_date.lte', new Date().toISOString().slice(0, 10));
      break;
    case 'popular':
    case 'all':
    default:
      break;
  }

  const json = await fetchJson(`https://api.themoviedb.org/3/discover/tv?${params.toString()}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  const items = (Array.isArray(json?.results) ? json.results : [])
    .map(tmdbItem)
    .filter((item: ContentItem | null): item is ContentItem => item !== null)
    .slice(0, limit);

  return {
    items,
    page,
    hasNextPage: Number(json?.page || page) < Number(json?.total_pages || page),
    source: 'tmdb',
    arabic: true,
  };
}

export async function contentPage(
  kind: ContentKind,
  page: number,
  limit: number,
  env: { TMDB_API_TOKEN?: string },
  category = 'popular',
): Promise<ContentPage> {
  if (kind === 'manga') return manga(page, limit);

  const token = env.TMDB_API_TOKEN?.trim();
  if (!token) throw new Error('animation_provider_not_configured');
  return animation(page, limit, token, category);
}
