import { contentPage, type ContentItem, type ContentKind } from './content-providers';

export interface ContentCatalogResult {
  items: ContentItem[];
  page: number;
  hasNextPage: boolean;
  source: string;
  arabic: boolean;
}

function rowToItem(row: Record<string, unknown>): ContentItem {
  return {
    id: String(row.external_id || ''),
    title: String(row.title || 'Unknown'),
    titleAr: row.title_ar ? String(row.title_ar) : null,
    synopsis: row.synopsis ? String(row.synopsis) : null,
    imageUrl: row.image_url ? String(row.image_url) : null,
    score: row.score == null ? null : Number(row.score),
    year: row.year == null ? null : Number(row.year),
    type: row.type ? String(row.type) : null,
    source: String(row.source || 'external'),
    sourceUrl: row.source_url ? String(row.source_url) : null,
  };
}

export async function upsertContentBatch(db: D1Database, kind: ContentKind, items: ContentItem[]): Promise<void> {
  for (const item of items) {
    await db.prepare(`
      INSERT INTO content_catalog
        (kind, external_id, title, title_ar, synopsis, image_url, score, year, type, source, source_url, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
      ON CONFLICT(kind, external_id) DO UPDATE SET
        title = excluded.title,
        title_ar = excluded.title_ar,
        synopsis = excluded.synopsis,
        image_url = excluded.image_url,
        score = excluded.score,
        year = excluded.year,
        type = excluded.type,
        source = excluded.source,
        source_url = excluded.source_url,
        updated_at = CURRENT_TIMESTAMP
    `).bind(
      kind,
      item.id,
      item.title,
      item.titleAr || null,
      item.synopsis || null,
      item.imageUrl || null,
      item.score,
      item.year,
      item.type || null,
      item.source,
      item.sourceUrl || null,
    ).run();
  }
}

async function dbPage(db: D1Database, kind: ContentKind, page: number, limit: number): Promise<{ items: ContentItem[]; hasNext: boolean }> {
  const offset = (page - 1) * limit;
  const rows = await db.prepare(`
    SELECT external_id, title, title_ar, synopsis, image_url, score, year, type, source, source_url
    FROM content_catalog
    WHERE kind = ?
    ORDER BY COALESCE(score, 0) DESC, COALESCE(year, 0) DESC, title ASC
    LIMIT ? OFFSET ?
  `).bind(kind, limit + 1, offset).all<Record<string, unknown>>();
  const values = rows.results ?? [];
  return { items: values.slice(0, limit).map(rowToItem), hasNext: values.length > limit };
}

export async function contentCatalogPage(
  db: D1Database,
  kind: ContentKind,
  page: number,
  limit: number,
  env: { TMDB_API_TOKEN?: string },
  category = 'popular',
): Promise<ContentCatalogResult> {
  let cached: { items: ContentItem[]; hasNext: boolean } = { items: [], hasNext: false };
  try {
    cached = await dbPage(db, kind, page, limit);
  } catch (_) {
    // V1.24 is provider-first: the section still works if its D1 migration has not been applied yet.
  }
  // Animation categories are query-dependent, so never satisfy them from the
  // category-agnostic D1 cache. Manga can continue using its normal cache.
  if (kind === 'manga' && (cached.items.length >= limit || cached.hasNext)) {
    return { items: cached.items, page, hasNextPage: cached.hasNext, source: 'database', arabic: true };
  }

  const provider = await contentPage(kind, page, limit, env, category);
  if (provider.items.length) {
    try {
      await upsertContentBatch(db, kind, provider.items);
    } catch (_) {
      // Provider results remain usable even when D1 is temporarily unavailable.
    }
  }

  const merged = [...cached.items];
  const seen = new Set(merged.map((item) => item.id));
  for (const item of provider.items) {
    if (!seen.has(item.id)) {
      seen.add(item.id);
      merged.push(item);
    }
    if (merged.length >= limit) break;
  }

  return {
    items: merged.slice(0, limit),
    page,
    hasNextPage: provider.hasNextPage,
    source: provider.source,
    arabic: true,
  };
}
