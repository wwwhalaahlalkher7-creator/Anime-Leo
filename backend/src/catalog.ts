import type { AnimeProvider, AnimeRecord, EpisodeRecord, ProviderPage } from './types';
import type { ArabicEpisodeProvider } from './arabic-episode-provider';
import { identityFromExternalId } from './identity';
import type { ExternalSourceProvider } from './external-source-provider';

export class CatalogDatabaseError extends Error {
  readonly code = 'catalog_database_unavailable';

  constructor(operation: string, cause?: unknown) {
    super(`Catalog database unavailable during ${operation}`);
    this.name = 'CatalogDatabaseError';
  }
}

export interface CatalogResult<T> {
  items: T[];
  page: number;
  hasNextPage: boolean;
  source: 'database' | 'provider' | 'database+provider' | 'database+external-sources';
  degraded?: boolean;
  parentMissing?: boolean;
}

/** D1 is an archive for completed anime only. Live/ongoing titles must never
 * be treated as authoritative D1 records. */
export function isCompletedStatus(status: string | null | undefined): boolean {
  const value = (status || '').trim().toLowerCase();
  return value === 'finished airing'
    || value === 'finished'
    || value === 'completed'
    || value === 'complete';
}

function isArchiveRecord(record: AnimeRecord): boolean {
  return isCompletedStatus(record.status);
}

function placeholders(record: AnimeRecord) {
  return {
    titleAr: record.titleAr ?? null,
    synopsis: record.synopsis ?? null,
    imageUrl: record.imageUrl ?? null,
    genresJson: JSON.stringify(record.genres ?? []),
    status: record.status ?? null,
    episodes: record.episodes ?? null,
    score: record.score ?? null,
    year: record.year ?? null,
    type: record.type ?? null,
  };
}

export async function upsertAnime(db: D1Database, record: AnimeRecord): Promise<void> {
  if (!isArchiveRecord(record)) return;
  const p = placeholders(record);
  await db.prepare(`
    INSERT INTO anime (
      external_id, title, title_ar, synopsis, image_url, genres_json,
      status, episodes, score, year, type, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
    ON CONFLICT(external_id) DO UPDATE SET
      title = excluded.title,
      title_ar = COALESCE(excluded.title_ar, anime.title_ar),
      synopsis = COALESCE(excluded.synopsis, anime.synopsis),
      image_url = COALESCE(excluded.image_url, anime.image_url),
      genres_json = excluded.genres_json,
      status = COALESCE(excluded.status, anime.status),
      episodes = COALESCE(excluded.episodes, anime.episodes),
      score = COALESCE(excluded.score, anime.score),
      year = COALESCE(excluded.year, anime.year),
      type = COALESCE(excluded.type, anime.type),
      updated_at = CURRENT_TIMESTAMP
  `).bind(
    record.externalId,
    record.title,
    p.titleAr,
    p.synopsis,
    p.imageUrl,
    p.genresJson,
    p.status,
    p.episodes,
    p.score,
    p.year,
    p.type,
  ).run();
}

export async function upsertEpisodes(db: D1Database, items: EpisodeRecord[]): Promise<void> {
  if (!items.length) return;
  const statements = items.map((episode) => db.prepare(`
    INSERT INTO episodes (
      external_id, anime_external_id, episode_number, title,
      thumbnail, duration, aired, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
    ON CONFLICT(external_id) DO UPDATE SET
      title = excluded.title,
      thumbnail = excluded.thumbnail,
      duration = excluded.duration,
      aired = excluded.aired,
      updated_at = CURRENT_TIMESTAMP
  `).bind(
    episode.externalId,
    episode.animeExternalId,
    episode.episodeNumber,
    episode.title ?? null,
    episode.thumbnail ?? null,
    episode.duration ?? null,
    episode.aired ?? null,
  ));
  await db.batch(statements);
}

function parseGenres(value: unknown): string[] {
  if (typeof value !== 'string') return [];
  try {
    const parsed = JSON.parse(value);
    return Array.isArray(parsed) ? parsed.map(String) : [];
  } catch (_) {
    return [];
  }
}

function rowToAnime(row: Record<string, unknown>): AnimeRecord {
  const externalId = String(row.external_id);
  const identity = identityFromExternalId(externalId);
  return {
    id: Number(row.id),
    externalId,
    ...identity,
    title: String(row.title ?? 'Unknown Anime'),
    titleAr: row.title_ar == null ? null : String(row.title_ar),
    synopsis: row.synopsis == null ? null : String(row.synopsis),
    imageUrl: row.image_url == null ? null : String(row.image_url),
    genres: parseGenres(row.genres_json),
    status: row.status == null ? null : String(row.status),
    episodes: row.episodes == null ? null : Number(row.episodes),
    score: row.score == null ? null : Number(row.score),
    year: row.year == null ? null : Number(row.year),
    type: row.type == null ? null : String(row.type),
    studioNames: [],
    characters: [],
    relations: [],
    recommendations: [],
  };
}

function rowToEpisode(row: Record<string, unknown>): EpisodeRecord {
  return {
    externalId: String(row.external_id),
    animeExternalId: String(row.anime_external_id),
    episodeNumber: Number(row.episode_number),
    title: row.title == null ? null : String(row.title),
    thumbnail: row.thumbnail == null ? null : String(row.thumbnail),
    duration: row.duration == null ? null : String(row.duration),
    aired: row.aired == null ? null : String(row.aired),
  };
}

export async function upsertAnimeBatch(db: D1Database, items: AnimeRecord[]): Promise<void> {
  const archived = items.filter(isArchiveRecord);
  if (!archived.length) return;
  await db.batch(archived.map((item) => {
    const p = placeholders(item);
    return db.prepare(`
      INSERT INTO anime (
        external_id, title, title_ar, synopsis, image_url, genres_json,
        status, episodes, score, year, type, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
      ON CONFLICT(external_id) DO UPDATE SET
        title = excluded.title,
        title_ar = COALESCE(excluded.title_ar, anime.title_ar),
        synopsis = COALESCE(excluded.synopsis, anime.synopsis),
        image_url = COALESCE(excluded.image_url, anime.image_url),
        genres_json = excluded.genres_json,
        status = COALESCE(excluded.status, anime.status),
        episodes = COALESCE(excluded.episodes, anime.episodes),
        score = COALESCE(excluded.score, anime.score),
        year = COALESCE(excluded.year, anime.year),
        type = COALESCE(excluded.type, anime.type),
        updated_at = CURRENT_TIMESTAMP
    `).bind(
      item.externalId, item.title, p.titleAr, p.synopsis, p.imageUrl,
      p.genresJson, p.status, p.episodes, p.score, p.year, p.type,
    );
  }));
}

async function searchDatabase(
  db: D1Database,
  query: string,
  page: number,
  limit: number,
): Promise<{ items: AnimeRecord[]; hasNext: boolean }> {
  const offset = (page - 1) * limit;
  let rows: { results?: Record<string, unknown>[] };
  try {
    rows = await db.prepare(`
      SELECT * FROM anime
      WHERE (title LIKE ? OR title_ar LIKE ?)
        AND (LOWER(TRIM(status)) IN ('finished airing', 'finished', 'completed', 'complete'))
      ORDER BY COALESCE(score, 0) DESC, title ASC
      LIMIT ? OFFSET ?
    `).bind(`%${query}%`, `%${query}%`, limit + 1, offset).all<Record<string, unknown>>();
  } catch (error) {
    throw new CatalogDatabaseError('search', error);
  }

  const resultRows = rows.results ?? [];
  return {
    items: resultRows.slice(0, limit).map(rowToAnime),
    hasNext: resultRows.length > limit,
  };
}

async function topDatabase(
  db: D1Database,
  page: number,
  limit: number,
): Promise<{ items: AnimeRecord[]; hasNext: boolean }> {
  const offset = (page - 1) * limit;
  let rows: { results?: Record<string, unknown>[] };
  try {
    rows = await db.prepare(`
      SELECT * FROM anime
      WHERE score IS NOT NULL
        AND LOWER(TRIM(status)) IN ('finished airing', 'finished', 'completed', 'complete')
      ORDER BY score DESC, year DESC, title ASC
      LIMIT ? OFFSET ?
    `).bind(limit + 1, offset).all<Record<string, unknown>>();
  } catch (error) {
    throw new CatalogDatabaseError('top', error);
  }

  const resultRows = rows.results ?? [];
  return {
    items: resultRows.slice(0, limit).map(rowToAnime),
    hasNext: resultRows.length > limit,
  };
}

async function comingSoonDatabase(
  db: D1Database,
  page: number,
  limit: number,
): Promise<{ items: AnimeRecord[]; hasNext: boolean }> {
  const offset = (page - 1) * limit;
  let rows: { results?: Record<string, unknown>[] };
  try {
    rows = await db.prepare(`
      SELECT * FROM anime
      WHERE LOWER(TRIM(status)) = 'not yet aired'
      ORDER BY year DESC, COALESCE(score, 0) DESC, title ASC
      LIMIT ? OFFSET ?
    `).bind(limit + 1, offset).all<Record<string, unknown>>();
  } catch (error) {
    throw new CatalogDatabaseError('coming_soon', error);
  }

  const resultRows = rows.results ?? [];
  return {
    items: resultRows.slice(0, limit).map(rowToAnime),
    hasNext: resultRows.length > limit,
  };
}

/// Upcoming/unaired titles for the sidebar's "Coming Soon" item (see
/// docs/SETTINGS_SIDEBAR_PLAN.md, Phase 8). Database-only: this is a filtered
/// view of the catalog the background sync already fills in, not a new
/// content type, so there's no provider fallback to wire here.
export async function comingSoonCatalog(
  db: D1Database,
  page: number,
  limit: number,
): Promise<CatalogResult<AnimeRecord>> {
  const result = await comingSoonDatabase(db, page, limit);
  return {
    items: result.items,
    page,
    hasNextPage: result.hasNext,
    source: 'database',
    degraded: false,
  };
}

/// Distinct broadcast years present in the catalog, most recent first, for
/// the sidebar's "Seasons" item (see docs/SETTINGS_SIDEBAR_PLAN.md, Phase 8).
/// The catalog only stores a `year`, not a quarter/season string, so
/// "season" here means "year" — grouping by true broadcast season (winter/
/// spring/...) would need a schema change and a provider that supplies it,
/// which is out of scope for this slice.
export interface SeasonYear {
  year: number;
  count: number;
}

export async function seasonYears(db: D1Database): Promise<SeasonYear[]> {
  let rows: { results?: Record<string, unknown>[] };
  try {
    rows = await db.prepare(`
      SELECT year, COUNT(*) as count FROM anime
      WHERE year IS NOT NULL
      GROUP BY year
      ORDER BY year DESC
    `).all<Record<string, unknown>>();
  } catch (error) {
    throw new CatalogDatabaseError('season_years', error);
  }
  return (rows.results ?? []).map((row) => ({
    year: Number(row.year),
    count: Number(row.count) || 0,
  }));
}

async function seasonDatabase(
  db: D1Database,
  year: number,
  page: number,
  limit: number,
): Promise<{ items: AnimeRecord[]; hasNext: boolean }> {
  const offset = (page - 1) * limit;
  let rows: { results?: Record<string, unknown>[] };
  try {
    rows = await db.prepare(`
      SELECT * FROM anime
      WHERE year = ?
      ORDER BY COALESCE(score, 0) DESC, title ASC
      LIMIT ? OFFSET ?
    `).bind(year, limit + 1, offset).all<Record<string, unknown>>();
  } catch (error) {
    throw new CatalogDatabaseError('season', error);
  }

  const resultRows = rows.results ?? [];
  return {
    items: resultRows.slice(0, limit).map(rowToAnime),
    hasNext: resultRows.length > limit,
  };
}

/// Catalog titles for one broadcast year (see [seasonYears]). Database-only,
/// same reasoning as [comingSoonCatalog] — a filtered/grouped view of
/// existing data, not a new content type.
export async function seasonCatalog(
  db: D1Database,
  year: number,
  page: number,
  limit: number,
): Promise<CatalogResult<AnimeRecord>> {
  const result = await seasonDatabase(db, year, page, limit);
  return {
    items: result.items,
    page,
    hasNextPage: result.hasNext,
    source: 'database',
    degraded: false,
  };
}

function mergeAnimePages(
  dbItems: AnimeRecord[],
  providerItems: AnimeRecord[],
  limit: number,
): AnimeRecord[] {
  const merged = [...dbItems];
  const seen = new Set(dbItems.map((item) => item.externalId));
  for (const item of providerItems) {
    if (!seen.has(item.externalId)) {
      seen.add(item.externalId);
      merged.push(item);
    }
    if (merged.length >= limit) break;
  }
  return merged.slice(0, limit);
}

export async function searchCatalog(
  db: D1Database,
  provider: AnimeProvider,
  query: string,
  page: number,
  limit: number,
): Promise<CatalogResult<AnimeRecord>> {
  const cached = await searchDatabase(db, query, page, limit);

  try {
    const providerPage = await provider.search(query, page, limit);
    const liveItems = providerPage.items;
    await upsertAnimeBatch(db, liveItems);
    const items = mergeAnimePages(cached.items, liveItems, limit);

    return {
      items,
      page,
      hasNextPage: providerPage.hasNextPage || cached.hasNext,
      source: cached.items.length ? 'database+provider' : 'provider',
      degraded: false,
    };
  } catch (_) {
    return {
      items: cached.items,
      page,
      hasNextPage: cached.hasNext,
      source: 'database',
      degraded: true,
    };
  }
}

export async function topCatalog(
  db: D1Database,
  provider: AnimeProvider,
  page: number,
  limit: number,
): Promise<CatalogResult<AnimeRecord>> {
  const cached = await topDatabase(db, page, limit);

  try {
    const providerPage = await provider.top(page, limit);
    await upsertAnimeBatch(db, providerPage.items);
    const items = mergeAnimePages(cached.items, providerPage.items, limit);

    return {
      items,
      page,
      hasNextPage: providerPage.hasNextPage || cached.hasNext,
      source: cached.items.length ? 'database+provider' : 'provider',
      degraded: false,
    };
  } catch (_) {
    return {
      items: cached.items,
      page,
      hasNextPage: cached.hasNext,
      source: 'database',
      degraded: true,
    };
  }
}

export async function getAnime(
  db: D1Database,
  provider: AnimeProvider,
  externalId: string,
): Promise<{ item: AnimeRecord | null; source: 'database' | 'provider'; degraded?: boolean }> {
  let row: Record<string, unknown> | null;
  try {
    row = await db.prepare(`
      SELECT * FROM anime
      WHERE external_id = ?
        AND LOWER(TRIM(status)) IN ('finished airing', 'finished', 'completed', 'complete')
      LIMIT 1
    `).bind(externalId).first<Record<string, unknown>>();
  } catch (error) {
    throw new CatalogDatabaseError('details', error);
  }

  if (row) return { item: rowToAnime(row), source: 'database', degraded: false };

  try {
    const item = await provider.details(externalId);
    if (item && isArchiveRecord(item)) await upsertAnime(db, item);
    return { item, source: 'provider', degraded: false };
  } catch (_) {
    return { item: null, source: 'provider', degraded: true };
  }
}

export async function getEpisodes(
  db: D1Database,
  provider: AnimeProvider,
  externalId: string,
  page: number,
  limit: number,
  arabicProvider?: ArabicEpisodeProvider,
  externalSourceProvider?: ExternalSourceProvider,
): Promise<CatalogResult<EpisodeRecord>> {
  // Ensure the parent anime exists before inserting episodes because D1 enforces the FK.
  const parent = await getAnime(db, provider, externalId);
  if (!parent.item) {
    return {
      items: [],
      page,
      hasNextPage: false,
      source: 'database',
      degraded: parent.degraded === true,
      parentMissing: true,
    };
  }

  const isArchived = isArchiveRecord(parent.item);
  const offset = (page - 1) * limit;
  let dbItems: EpisodeRecord[] = [];
  let dbHasNext = false;

  if (isArchived) {
    let rows: { results?: Record<string, unknown>[] };
    try {
      rows = await db.prepare(`
        SELECT * FROM episodes
        WHERE anime_external_id = ?
        ORDER BY episode_number ASC
        LIMIT ? OFFSET ?
      `).bind(externalId, limit + 1, offset).all<Record<string, unknown>>();
    } catch (error) {
      throw new CatalogDatabaseError('episodes', error);
    }
    const resultRows = rows.results ?? [];
    dbItems = resultRows.slice(0, limit).map(rowToEpisode);
    dbHasNext = resultRows.length > limit;
  }

  async function enrichExternalSources(items: EpisodeRecord[]): Promise<EpisodeRecord[]> {
    if (!externalSourceProvider || externalSourceProvider.name === 'none' || !items.length) return items;
    const enriched = await Promise.all(items.map(async (item) => {
      try {
        const sources = await externalSourceProvider.listSources(externalId, item.episodeNumber);
        return sources.length ? { ...item, sources: [...(item.sources ?? []), ...sources] } : item;
      } catch (_) {
        return item;
      }
    }));
    return enriched;
  }

  // Cached Jikan episodes can still be enriched with Arabic availability.
  // Do not persist Arabic source metadata in the generic episodes table; it is
  // provider-owned and may change independently of Jikan.
  if (arabicProvider && arabicProvider.name !== 'none') {
    try {
      const arabicPage = await arabicProvider.listEpisodes(externalId, page, limit);
      if (arabicPage.items.length) {
        const mergedByNumber = new Map<number, EpisodeRecord>(
          dbItems.map((item) => [item.episodeNumber, item]),
        );
        for (const arabic of arabicPage.items) {
          const current = mergedByNumber.get(arabic.episodeNumber);
          mergedByNumber.set(arabic.episodeNumber, current
            ? { ...current, sources: [...(current.sources ?? []), ...(arabic.sources ?? [])] }
            : arabic);
        }
        const enriched = await enrichExternalSources(Array.from(mergedByNumber.values())
          .sort((a, b) => a.episodeNumber - b.episodeNumber)
          .slice(0, limit));
        if (enriched.length > 0) {
          return {
            items: enriched,
            page,
            hasNextPage: dbHasNext || arabicPage.hasNextPage,
            source: 'database+provider',
            degraded: false,
          };
        }
      }
    } catch (_) {
      // Arabic availability is optional; keep the cached Jikan catalog usable.
    }
  }

  if (isArchived && (dbItems.length >= limit || dbHasNext)) {
    return {
      items: await enrichExternalSources(dbItems),
      page,
      hasNextPage: dbHasNext,
      source: externalSourceProvider?.name !== 'none' ? 'database+external-sources' : 'database',
      degraded: false,
    };
  }

  try {
    const [providerResult, arabicResult] = await Promise.allSettled([
      provider.episodes(externalId, page, limit),
      arabicProvider && arabicProvider.name !== 'none'
        ? arabicProvider.listEpisodes(externalId, page, limit)
        : Promise.resolve({ items: [], page, hasNextPage: false } as ProviderPage<EpisodeRecord>),
    ]);

    const providerPage = providerResult.status === 'fulfilled'
      ? providerResult.value
      : { items: [], page, hasNextPage: false };
    const arabicPage = arabicResult.status === 'fulfilled'
      ? arabicResult.value
      : { items: [], page, hasNextPage: false };

    if (isArchived) await upsertEpisodes(db, providerPage.items);

    // Merge by episode number. Jikan remains the canonical metadata record,
    // while an Arabic source is attached to the same episode when available.
    const mergedByNumber = new Map<number, EpisodeRecord>();
    for (const item of dbItems) mergedByNumber.set(item.episodeNumber, item);
    for (const item of providerPage.items) {
      const current = mergedByNumber.get(item.episodeNumber);
      mergedByNumber.set(item.episodeNumber, current
        ? { ...current, title: current.title ?? item.title, thumbnail: current.thumbnail ?? item.thumbnail, duration: current.duration ?? item.duration, aired: current.aired ?? item.aired }
        : item);
    }
    for (const item of arabicPage.items) {
      const current = mergedByNumber.get(item.episodeNumber);
      const arabicSources = item.sources ?? [];
      mergedByNumber.set(item.episodeNumber, current
        ? { ...current, sources: [...(current.sources ?? []), ...arabicSources] }
        : item);
    }

    const merged = await enrichExternalSources(Array.from(mergedByNumber.values())
      .sort((a, b) => a.episodeNumber - b.episodeNumber)
      .slice(0, limit));

    const jikanFailed = providerResult.status === 'rejected';
    const arabicFailed = arabicResult.status === 'rejected' && arabicProvider?.name !== 'none';

    return {
      items: merged,
      page,
      hasNextPage: providerPage.hasNextPage || arabicPage.hasNextPage,
      source: dbItems.length ? 'database+provider' : (arabicPage.items.length && !providerPage.items.length ? 'provider' : 'provider'),
      degraded: jikanFailed && arabicFailed,
    };
  } catch (_) {
    return {
      items: await enrichExternalSources(dbItems),
      page,
      hasNextPage: dbHasNext,
      source: externalSourceProvider?.name !== 'none' ? 'database+external-sources' : 'database',
      degraded: true,
    };
  }
}

export function animeToApi(item: AnimeRecord) {
  const fallbackAnilistId = item.anilistId ?? (item.externalId.startsWith('-') ? Math.abs(Number(item.externalId)) : null);
  const fallbackMalId = item.malId ?? (!item.externalId.startsWith('-') && /^\d+$/.test(item.externalId) ? Number(item.externalId) : null);
  const canonicalId = item.canonicalId
    ?? (fallbackMalId != null ? `mal:${fallbackMalId}` : fallbackAnilistId != null ? `anilist:${fallbackAnilistId}` : `${item.providerName ?? 'provider'}:${item.externalId}`);
  return {
    id: item.externalId,
    canonicalId,
    mal_id: fallbackMalId,
    malId: fallbackMalId,
    anilistId: fallbackAnilistId,
    providerId: item.providerId ?? item.externalId,
    provider: item.providerName ?? null,
    title: item.title,
    title_ar: item.titleAr,
    synopsis: item.synopsis,
    image: item.imageUrl,
    genres: item.genres,
    status: item.status,
    episodes: item.episodes,
    score: item.score,
    year: item.year,
    type: item.type,
    source: item.source,
    duration: item.duration,
    airedFrom: item.airedFrom,
    airedTo: item.airedTo,
    rating: item.rating,
    rank: item.rank,
    members: item.members,
    popularity: item.popularity,
    season: item.season,
    seasonYear: item.seasonYear,
    broadcastDay: item.broadcastDay,
    broadcastTime: item.broadcastTime,
    studioNames: item.studioNames ?? [],
    trailerUrl: item.trailerUrl,
    trailerImageUrl: item.trailerImageUrl,
    backgroundImageUrl: item.backgroundImageUrl,
    characters: item.characters ?? [],
    relations: item.relations ?? [],
    recommendations: item.recommendations ?? [],
  };
}

export function episodeToApi(item: EpisodeRecord) {
  return {
    id: item.externalId,
    mal_id: item.episodeNumber,
    title: item.title,
    thumbnail: item.thumbnail,
    duration: item.duration,
    aired: item.aired,
    sources: item.sources ?? [],
  };
}
