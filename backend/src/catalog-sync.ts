import { upsertAnimeBatch } from './catalog';
import { JikanProvider } from './providers-jikan';
import { contentPage } from './content-providers';
import { upsertContentBatch } from './content-catalog';

export type CatalogSyncStream = 'popularity' | 'latest' | 'manga' | 'animation';

export interface CatalogSyncEnv {
  CATALOG_SYNC_ENABLED?: string;
  CATALOG_SYNC_PAGES?: string;
  CATALOG_SYNC_LIMIT?: string;
  TMDB_API_TOKEN?: string;
}

interface SyncStateRow {
  stream: string;
  page: number;
  last_run_at: string | null;
  last_success_at: string | null;
  total_upserted: number;
  last_error: string | null;
}

function numberEnv(value: string | undefined, fallback: number, min: number, max: number): number {
  const parsed = Number.parseInt(value || '', 10);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(min, Math.min(max, parsed));
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function state(db: D1Database, stream: CatalogSyncStream): Promise<SyncStateRow> {
  const row = await db.prepare(`
    SELECT stream, page, last_run_at, last_success_at, total_upserted, last_error
    FROM catalog_sync_state
    WHERE stream = ?
  `).bind(stream).first<SyncStateRow>();

  if (row) return row;

  await db.prepare(`
    INSERT OR IGNORE INTO catalog_sync_state
      (stream, page, total_upserted)
    VALUES (?, 1, 0)
  `).bind(stream).run();

  return {
    stream,
    page: 1,
    last_run_at: null,
    last_success_at: null,
    total_upserted: 0,
    last_error: null,
  };
}

async function markRun(db: D1Database, stream: CatalogSyncStream, page: number): Promise<void> {
  await db.prepare(`
    UPDATE catalog_sync_state
    SET page = ?, last_run_at = CURRENT_TIMESTAMP, last_error = NULL
    WHERE stream = ?
  `).bind(page, stream).run();
}

async function markSuccess(
  db: D1Database,
  stream: CatalogSyncStream,
  page: number,
  upserted: number,
): Promise<void> {
  await db.prepare(`
    UPDATE catalog_sync_state
    SET page = ?,
        last_success_at = CURRENT_TIMESTAMP,
        total_upserted = total_upserted + ?,
        last_error = NULL
    WHERE stream = ?
  `).bind(page, upserted, stream).run();
}

async function markError(db: D1Database, stream: CatalogSyncStream, message: string): Promise<void> {
  await db.prepare(`
    UPDATE catalog_sync_state
    SET last_run_at = CURRENT_TIMESTAMP,
        last_error = ?
    WHERE stream = ?
  `).bind(message.slice(0, 300), stream).run();
}

/**
 * Walks Jikan independently of client traffic.
 *
 * Two streams are maintained:
 *  - popularity: broad catalogue coverage
 *  - latest: recently aired/newer titles
 *
 * The cursor is persisted in D1, so each scheduled invocation continues from
 * the previous page instead of starting over.
 */
export async function runCatalogSync(
  db: D1Database,
  env: CatalogSyncEnv & { UPSTREAM_BASE: string },
): Promise<{
  status: 'disabled' | 'ok' | 'partial';
  streams: Array<{
    stream: CatalogSyncStream;
    startPage: number;
    nextPage: number;
    pagesProcessed: number;
    upserted: number;
    hasNextPage: boolean;
    error?: string;
  }>;
}> {
  if (env.CATALOG_SYNC_ENABLED === 'false') {
    return { status: 'disabled', streams: [] };
  }

  const pagesPerStream = numberEnv(env.CATALOG_SYNC_PAGES, 5, 1, 8);
  const limit = numberEnv(env.CATALOG_SYNC_LIMIT, 24, 12, 24);
  const jikan = new JikanProvider(env.UPSTREAM_BASE);
  const streams: CatalogSyncStream[] = ['popularity', 'latest', 'manga'];
  if (env.TMDB_API_TOKEN?.trim()) streams.push('animation');
  const results: Array<{
    stream: CatalogSyncStream;
    startPage: number;
    nextPage: number;
    pagesProcessed: number;
    upserted: number;
    hasNextPage: boolean;
    error?: string;
  }> = [];

  for (const stream of streams) {
    const current = await state(db, stream);
    let page = Math.max(1, Number(current.page) || 1);
    const startPage = page;
    let pagesProcessed = 0;
    let upserted = 0;
    let hasNextPage = true;
    let error: string | undefined;

    for (let i = 0; i < pagesPerStream; i += 1) {
      try {
        await markRun(db, stream, page);

        if (stream === 'manga' || stream === 'animation') {
          const result = await contentPage(stream, page, limit, env);
          if (result.items.length) {
            await upsertContentBatch(db, stream, result.items);
            upserted += result.items.length;
          }
          pagesProcessed += 1;
          hasNextPage = result.hasNextPage;
          const nextPage = result.hasNextPage ? page + 1 : 1;
          await markSuccess(db, stream, nextPage, result.items.length);
          page = nextPage;
          if (i < pagesPerStream - 1) await sleep(450);
          continue;
        }

        const result = await jikan.browse(
          page,
          limit,
          stream === 'popularity' ? 'popularity' : 'start_date',
          stream === 'popularity' ? 'asc' : 'desc',
        );

        if (result.items.length) {
          await upsertAnimeBatch(db, result.items);
          upserted += result.items.length;
        }

        pagesProcessed += 1;
        hasNextPage = result.hasNextPage;
        const nextPage = result.hasNextPage ? page + 1 : 1;
        await markSuccess(db, stream, nextPage, result.items.length);
        page = nextPage;

        // Stay comfortably below public-provider request-rate limits.
        if (i < pagesPerStream - 1) await sleep(450);
      } catch (cause) {
        error = cause instanceof Error ? cause.message.slice(0, 300) : 'unknown_error';
        await markError(db, stream, error);
        break;
      }
    }

    results.push({
      stream,
      startPage,
      nextPage: page,
      pagesProcessed,
      upserted,
      hasNextPage,
      ...(error ? { error } : {}),
    });
  }

  return {
    status: results.some((item) => item.error)
      ? (results.some((item) => item.pagesProcessed > 0) ? 'partial' : 'partial')
      : 'ok',
    streams: results,
  };
}
