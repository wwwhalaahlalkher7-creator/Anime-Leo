const MANGADEX_API = 'https://api.mangadex.org';

async function fetchJson(url: string): Promise<any> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 15000);
  try {
    const response = await fetch(url, {
      signal: controller.signal,
      headers: {
        Accept: 'application/json',
        'User-Agent': 'AnimeLeo/1.25.1 (MangaDex API client)',
      },
    });
    if (!response.ok) throw new Error(`mangadex_${response.status}`);
    return await response.json();
  } finally {
    clearTimeout(timer);
  }
}

export interface MangaChapterSummary {
  id: string;
  chapter: string | null;
  title: string | null;
  volume: string | null;
  translatedLanguage: string | null;
  publishAt: string | null;
  pages: number;
  group: string | null;
}

export interface MangaPageResult {
  baseUrl: string;
  hash: string;
  pages: string[];
}

export async function mangaChapters(
  mangaId: string,
  page: number,
  limit: number,
  language = 'ar',
): Promise<{ items: MangaChapterSummary[]; hasNextPage: boolean }> {
  const offset = (page - 1) * limit;
  const params = new URLSearchParams({
    limit: String(Math.min(limit, 100)),
    offset: String(offset),
    'translatedLanguage[]': language,
    'contentRating[]': 'safe',
    'order[volume]': 'asc',
    'order[chapter]': 'asc',
    'includes[]': 'scanlation_group',
  });

  const json = await fetchJson(`${MANGADEX_API}/manga/${encodeURIComponent(mangaId)}/feed?${params}`);
  const data = Array.isArray(json?.data) ? json.data : [];
  const items = data.map((row: any): MangaChapterSummary | null => {
    const attributes = row?.attributes || {};
    const id = typeof row?.id === 'string' ? row.id : '';
    if (!id) return null;
    const group = Array.isArray(row?.relationships)
      ? row.relationships.find((r: any) => r?.type === 'scanlation_group')?.attributes?.name
      : null;
    return {
      id,
      chapter: attributes.chapter == null ? null : String(attributes.chapter),
      title: attributes.title ? String(attributes.title) : null,
      volume: attributes.volume == null ? null : String(attributes.volume),
      translatedLanguage: attributes.translatedLanguage ? String(attributes.translatedLanguage) : null,
      publishAt: attributes.publishAt ? String(attributes.publishAt) : null,
      pages: Number(attributes.pages) || 0,
      group: group ? String(group) : null,
    };
  }).filter((item: MangaChapterSummary | null): item is MangaChapterSummary => item !== null);

  const total = Number(json?.total) || 0;
  return { items, hasNextPage: offset + items.length < total };
}

export async function mangaChapterPages(chapterId: string): Promise<MangaPageResult> {
  const json = await fetchJson(`${MANGADEX_API}/at-home/server/${encodeURIComponent(chapterId)}`);
  const baseUrl = String(json?.baseUrl || '').trim();
  const hash = String(json?.chapter?.hash || '').trim();
  const pages = Array.isArray(json?.chapter?.data) ? json.chapter.data.map(String) : [];
  if (!baseUrl || !hash || !pages.length) throw new Error('mangadex_pages_unavailable');
  return { baseUrl, hash, pages };
}
