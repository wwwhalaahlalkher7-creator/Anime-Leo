import { CatalogDatabaseError, getAnime, getEpisodes, searchCatalog, topCatalog, comingSoonCatalog, seasonYears, seasonCatalog, animeToApi, episodeToApi } from './catalog';
import { JikanProvider } from './providers-jikan';
import { AniListProvider } from './providers-anilist';
import { ProviderAggregator } from './provider-aggregator';
import { getAniCliArabicPlayback, aniCliArabicHealth } from './ani-cli-arabic-provider';
import { getArabicDubStatus } from './mydublist-provider';
import { handleAnivexa } from './anivexa-adapter';
import type { AnimeProvider, AnimeRecord } from './types';
import { ConfiguredArabicEpisodeProvider, NoOpArabicEpisodeProvider } from './arabic-episode-provider';
import { CATALOG_SEED_IDS, seedCatalog } from './catalog-seed';
import { runCatalogSync } from './catalog-sync';
import { contentCatalogPage } from './content-catalog';
import { ConfiguredExternalSourceProvider, NoOpExternalSourceProvider } from './external-source-provider';
import { mangaChapterPages, mangaChapters } from './manga-reader-provider';
import { NoOpVideoProvider } from './video-provider';

interface Env {
  DB: D1Database;
  UPSTREAM_BASE: string;
  ANILIST_BASE?: string;
  CACHE_SECONDS: string;
  APP_VERSION: string;
  MINIMUM_APP_VERSION: string;
  PROVIDER_RESILIENCE_ENABLED: string;
  PROVIDER_ORDER?: string;
  ANALYTICS_ENABLED: string;
  MAINTENANCE_MODE: string;
  CATALOG_SEED_TOKEN?: string;
  CATALOG_SYNC_ENABLED?: string;
  CATALOG_SYNC_PAGES?: string;
  CATALOG_SYNC_LIMIT?: string;
  ARABIC_EPISODE_BASE?: string;
  ARABIC_EPISODE_PROVIDER_NAME?: string;
  ARABIC_EPISODE_API_KEY?: string;
  EXTERNAL_SOURCE_BASE?: string;
  EXTERNAL_SOURCE_PROVIDER_NAME?: string;
  EXTERNAL_SOURCE_API_KEY?: string;
  TMDB_API_TOKEN?: string;
  ANI_CLI_AR_ENDPOINT?: string;
  ANI_CLI_AR_AUTH_SECRET?: string;
  ANI_CLI_AR_API_BASE?: string;
  ANI_CLI_AR_TOKEN?: string;
  MYDUBLIST_BASE_URL?: string;
}

const ALLOWED_METHODS = 'GET, POST, OPTIONS';
const MAX_PAGE = 1000;
const MAX_LIMIT = 24;
const MAX_QUERY_LENGTH = 80;

function requestId(request: Request): string {
  const supplied = request.headers.get('X-Request-ID')?.trim();
  if (supplied && /^[A-Za-z0-9._:-]{1,80}$/.test(supplied)) return supplied;
  return crypto.randomUUID();
}

function headers(extra: HeadersInit = {}, id?: string) {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': ALLOWED_METHODS,
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Client-Version, X-Request-ID',
    'Access-Control-Max-Age': '86400',
    ...(id ? { 'X-Request-ID': id } : {}),
    ...extra,
  };
}

function json(data: unknown, status = 200, extra: HeadersInit = {}, id?: string) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      ...headers(extra, id),
    },
  });
}

function normalizePath(pathname: string) {
  const value = pathname.replace(/^\/api/, '');
  return value || '/';
}

function cacheKeyFor(request: Request) {
  return new Request(request.url, { method: 'GET' });
}

function numberParam(url: URL, key: string, fallback: number, max: number) {
  const value = Number.parseInt(url.searchParams.get(key) || '', 10);
  if (!Number.isFinite(value) || value < 1) return fallback;
  return Math.min(value, max);
}

function limitParam(url: URL, fallback = 12) {
  return numberParam(url, 'limit', fallback, MAX_LIMIT);
}


function arabicEpisodeProvider(env: Env) {
  const base = env.ARABIC_EPISODE_BASE?.trim();
  if (!base) return new NoOpArabicEpisodeProvider();
  return new ConfiguredArabicEpisodeProvider(
    base,
    env.ARABIC_EPISODE_PROVIDER_NAME?.trim() || 'arabic',
    env.ARABIC_EPISODE_API_KEY,
  );
}

function externalSourceProvider(env: Env) {
  const base = env.EXTERNAL_SOURCE_BASE?.trim();
  if (!base) return new NoOpExternalSourceProvider();
  return new ConfiguredExternalSourceProvider(
    base,
    env.EXTERNAL_SOURCE_PROVIDER_NAME?.trim() || 'external',
    env.EXTERNAL_SOURCE_API_KEY,
  );
}

// V1.29 legal-video contract: keep the legacy endpoint safe until a reviewed
// licensed provider is configured. Active playback uses the ani-cli-arabic
// adapter through /api/playback/{malId}/{episode}.
const videoProvider = new NoOpVideoProvider();

function provider(env: Env) {
  // Provider order is configurable. Jikan remains the primary source while
  // AniList provides a real fallback when Jikan/MAL is unavailable.
  const configured = (env.PROVIDER_ORDER || 'jikan,anilist')
    .split(',')
    .map((name) => name.trim().toLowerCase())
    .filter(Boolean);

  const providers: AnimeProvider[] = [];
  for (const name of configured) {
    if (name === 'jikan') {
      providers.push(new JikanProvider(env.UPSTREAM_BASE));
    } else if (name === 'anilist') {
      providers.push(new AniListProvider(env.ANILIST_BASE));
    }
  }

  return new ProviderAggregator(providers);
}

async function hashKey(value: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, '0')).join('');
}

async function enforceRateLimit(db: D1Database, request: Request): Promise<boolean> {
  const ip = request.headers.get('CF-Connecting-IP') || 'unknown';
  const key = `ip:${await hashKey(ip)}`;
  const now = new Date();
  const current = await db.prepare(
    'SELECT window_started, request_count FROM rate_limits WHERE key = ?'
  ).bind(key).first<{window_started: string; request_count: number}>();
  const windowMs = 60_000;

  if (!current || now.getTime() - new Date(current.window_started).getTime() >= windowMs) {
    await db.prepare(`
      INSERT INTO rate_limits (key, window_started, request_count)
      VALUES (?, ?, 1)
      ON CONFLICT(key) DO UPDATE SET
        window_started = excluded.window_started,
        request_count = 1
    `).bind(key, now.toISOString()).run();
    return true;
  }

  if (Number(current.request_count) >= 60) return false;

  await db.prepare(
    'UPDATE rate_limits SET request_count = request_count + 1 WHERE key = ?'
  ).bind(key).run();
  return true;
}

function validateEvent(event: unknown) {
  if (!event || typeof event !== 'object') return null;
  const input = event as Record<string, unknown>;
  const name = typeof input.event === 'string' ? input.event.trim() : '';
  if (!/^[a-z][a-z0-9_]{1,49}$/.test(name)) return null;

  const parameters = input.parameters && typeof input.parameters === 'object' && !Array.isArray(input.parameters)
    ? input.parameters
    : {};

  const safeParameters: Record<string, string | number | boolean> = {};
  for (const [key, value] of Object.entries(parameters as Record<string, unknown>)) {
    if (!/^[a-zA-Z][a-zA-Z0-9_]{0,31}$/.test(key)) continue;
    if (typeof value === 'string' && value.length <= 200) safeParameters[key] = value;
    else if (typeof value === 'number' && Number.isFinite(value)) safeParameters[key] = value;
    else if (typeof value === 'boolean') safeParameters[key] = value;
  }

  return {
    event: name,
    parameters: safeParameters,
    platform: typeof input.platform === 'string' ? input.platform.slice(0, 20) : null,
    appVersion: typeof input.appVersion === 'string' ? input.appVersion.slice(0, 30) : null,
    anonymousId: typeof input.anonymousId === 'string' ? input.anonymousId.slice(0, 64) : null,
  };
}

export default {
  async scheduled(_controller: ScheduledController, env: Env, ctx: ExecutionContext) {
    if (env.CATALOG_SYNC_ENABLED === 'false') return;

    ctx.waitUntil((async () => {
      try {
        const result = await runCatalogSync(env.DB, {
          UPSTREAM_BASE: env.UPSTREAM_BASE,
          CATALOG_SYNC_ENABLED: env.CATALOG_SYNC_ENABLED,
          CATALOG_SYNC_PAGES: env.CATALOG_SYNC_PAGES,
          CATALOG_SYNC_LIMIT: env.CATALOG_SYNC_LIMIT,
          TMDB_API_TOKEN: env.TMDB_API_TOKEN,
        });
        console.log('catalog_sync', JSON.stringify(result));
      } catch (error) {
        console.error(
          'catalog_sync_failed',
          error instanceof Error ? error.message : String(error),
        );
      }
    })());
  },

  async fetch(request: Request, env: Env, ctx: ExecutionContext) {
    const id = requestId(request);

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: headers({}, id) });
    }

    const url = new URL(request.url);

    if (url.pathname === '/api/health') {
  
    // Embedded Anivexa API. This keeps Anime Leo's catalog API intact while
    // exposing Anivexa's AniList-based episode/source service from the same
    // deployment.
    if (url.pathname.startsWith('/api/anivexa/')) {
      return handleAnivexa(request);
    }

    if (request.method !== 'GET') return json({ error: 'method_not_allowed' }, 405, {}, id);

      let dbOk = false;
      try {
        await env.DB.prepare('SELECT 1').first();
        dbOk = true;
      } catch (_) {}

      const deep = url.searchParams.get('deep') === 'true';
      let providerOk: boolean | null = null;
      let arabicEpisodesOk: boolean | null = null;
      let externalSourcesOk: boolean | null = null;
      let aniCliArabicOk: boolean | null = null;
      if (deep) {
        [providerOk, aniCliArabicOk, arabicEpisodesOk, externalSourcesOk] = await Promise.all([
          provider(env).healthCheck(),
          aniCliArabicHealth(env),
          arabicEpisodeProvider(env).healthCheck(),
          externalSourceProvider(env).healthCheck(),
        ]);
      }

      const healthy = dbOk && (!deep || providerOk === true);

      return json({
        status: healthy ? 'ok' : 'degraded',
        service: 'anime-platform-api',
        version: env.APP_VERSION || '1.30.0.18',
        database: dbOk ? 'ok' : 'unavailable',
        provider: deep ? (providerOk ? 'ok' : 'degraded') : 'not_checked',
        aniCliArabic: deep ? (aniCliArabicOk ? 'ok' : 'degraded') : 'not_checked',
        myDubList: 'enabled',
        arabicEpisodes: deep
          ? (env.ARABIC_EPISODE_BASE ? (arabicEpisodesOk ? 'ok' : 'degraded') : 'not_configured')
          : 'not_checked',
        externalSources: deep
          ? (env.EXTERNAL_SOURCE_BASE ? (externalSourcesOk ? 'ok' : 'degraded') : 'not_configured')
          : 'not_checked',
        timestamp: new Date().toISOString(),
      }, healthy ? 200 : 503, { 'Cache-Control': 'no-store' }, id);
    }

    const animeDiagnosticsMatch = url.pathname.match(/^\/api\/diagnostics\/anime\/(\-?\d+)$/);
    if (animeDiagnosticsMatch) {
      if (request.method !== 'GET') return json({ error: 'method_not_allowed' }, 405, {}, id);
      const externalId = animeDiagnosticsMatch[1];
      const metadataProvider = provider(env);
      const configured = (metadataProvider as ProviderAggregator).listProviders();
      const checks = await Promise.all(configured.map(async (name) => {
        const started = Date.now();
        try {
          const p = name === 'jikan' ? new JikanProvider(env.UPSTREAM_BASE) : new AniListProvider(env.ANILIST_BASE);
          const item = await p.details(externalId);
          return {
            provider: name,
            ok: Boolean(item),
            latencyMs: Date.now() - started,
            identity: item ? { canonicalId: item.canonicalId ?? null, malId: item.malId ?? null, anilistId: item.anilistId ?? null, providerId: item.providerId ?? null } : null,
          };
        } catch (error) {
          return { provider: name, ok: false, latencyMs: Date.now() - started, error: error instanceof Error ? error.message : String(error) };
        }
      }));
      return json({ externalId, providers: checks, resolved: checks.find((x) => x.ok)?.identity ?? null }, 200, { 'Cache-Control': 'no-store' }, id);
    }

    if (url.pathname === '/api/providers') {
      if (request.method !== 'GET') return json({ error: 'method_not_allowed' }, 405, {}, id);
      const metadataProvider = provider(env);
      const statuses = typeof (metadataProvider as ProviderAggregator).statuses === 'function'
        ? await (metadataProvider as ProviderAggregator).statuses()
        : [];
      return json({
        status: statuses.some((item) => item.healthy) ? 'ok' : 'degraded',
        aggregation: {
          enabled: true,
          mode: 'metadata-and-episode-aggregation',
          mergeKey: 'canonicalId',
          idPolicy: 'malId-for-playback; anilistId-for-Anivexa',
        },
        providers: statuses,
        playback: {
          mode: 'licensed-provider-only',
          configured: false,
          note: 'No licensed video provider is configured by default.',
        },
      }, 200, { 'Cache-Control': 'no-store' }, id);
    }

    if (url.pathname === '/api/config') {
      if (request.method !== 'GET') return json({ error: 'method_not_allowed' }, 405, {}, id);
      return json({
        apiVersion: 'v1',
        appVersion: env.APP_VERSION || '1.30.0.18',
        maintenanceMode: env.MAINTENANCE_MODE === 'true',
        minimumAppVersion: env.MINIMUM_APP_VERSION || env.APP_VERSION || '1.9.0',
        features: {
          ads: false,
          analytics: false,
          video: true,
          legalVideoArchitecture: true,
          providerAggregator: true,
          aniCliArabicPlayback: true,
          myDubList: true,
        },
        monetization: {
          enabled: false,
          provider: 'none',
          consentRequired: true,
          placements: [],
        },
        searchLimits: {
          maxPageSize: MAX_LIMIT,
          maxQueryLength: MAX_QUERY_LENGTH,
        },
        cacheSeconds: Number(env.CACHE_SECONDS || 900),
        catalog: {
          database: true,
          providerFallback: true,
          providerAggregation: true,
          providerResilience: env.PROVIDER_RESILIENCE_ENABLED !== 'false',
          provider: (env.PROVIDER_ORDER || 'jikan,anilist').split(',').map((name) => name.trim()).filter(Boolean),
          automaticSync: env.CATALOG_SYNC_ENABLED !== 'false',
          syncPagesPerRun: Number(env.CATALOG_SYNC_PAGES || 5),
          syncPageSize: Number(env.CATALOG_SYNC_LIMIT || 24),
          contentSections: {
            manga: { enabled: true, provider: 'mangadex', arabic: true },
            animation: { enabled: Boolean(env.TMDB_API_TOKEN), provider: 'tmdb', arabic: true },
          },
          playback: {
            primary: 'ani-cli-arabic',
            subtitles: ['ar', 'en'],
            audio: 'sub',
          },
          myDubList: {
            enabled: true,
            language: 'arabic',
            license: 'CC BY 4.0',
          },
          externalSources: {
            enabled: Boolean(env.EXTERNAL_SOURCE_BASE),
            provider: env.EXTERNAL_SOURCE_PROVIDER_NAME || 'external',
            mode: 'external-page-links',
          },
        },
      }, 200, { 'Cache-Control': 'public, max-age=60' }, id);
    }

    // Primary playback adapter: ani-cli-arabic. MyDubList is used as
    // availability metadata only; V1.28 remains subtitle-first and does not
    // expose an audio/dub selector.
    const playbackMatch = url.pathname.match(/^\/api\/playback\/([^/]+)\/(\d+)\/?$/);
    if (playbackMatch) {
      if (request.method !== 'GET') return json({ error: 'method_not_allowed' }, 405, {}, id);
      const malId = Number(decodeURIComponent(playbackMatch[1]));
      const episode = Number(playbackMatch[2]);
      if (!Number.isInteger(malId) || malId <= 0 || !Number.isInteger(episode) || episode <= 0) {
        return json({ error: 'invalid_playback_request' }, 400, {}, id);
      }
      try {
        const playback = await getAniCliArabicPlayback({ malId, episode, env });
        let dub = null;
        try { dub = await getArabicDubStatus(malId, env); } catch (_) {}
        return json({
          provider: 'ani-cli-arabic',
          language: 'sub',
          malId,
          episode,
          streams: playback.streams,
          subtitles: playback.subtitles,
          downloads: playback.streams.filter((item) => item?.downloadable && item?.downloadUrl).map((item) => ({
            quality: item.quality,
            url: item.downloadUrl,
          })),
          arabicDub: dub,
        }, 200, { 'Cache-Control': 'private, max-age=120' }, id);
      } catch (error) {
        return json({
          error: 'playback_unavailable',
          message: 'تعذر الحصول على مصدر المشاهدة من ani-cli-arabic حاليًا.',
          provider: 'ani-cli-arabic',
          degraded: true,
        }, 502, { 'Cache-Control': 'no-store' }, id);
      }
    }

    const dubMatch = url.pathname.match(/^\/api\/dubs\/mydublist\/(\d+)\/?$/);
    if (dubMatch) {
      if (request.method !== 'GET') return json({ error: 'method_not_allowed' }, 405, {}, id);
      const malId = Number(dubMatch[1]);
      if (!Number.isInteger(malId) || malId <= 0) return json({ error: 'invalid_mal_id' }, 400, {}, id);
      try {
        return json(await getArabicDubStatus(malId, env), 200, { 'Cache-Control': 'public, max-age=21600' }, id);
      } catch (_) {
        return json({ error: 'mydublist_unavailable', message: 'تعذر تحميل بيانات MyDubList حاليًا.', degraded: true }, 502, { 'Cache-Control': 'no-store' }, id);
      }
    }

    if (url.pathname.startsWith('/api/manga/') && url.pathname.endsWith('/chapters')) {
      if (request.method !== 'GET') return json({ error: 'method_not_allowed' }, 405, {}, id);
      const mangaId = decodeURIComponent(url.pathname.slice('/api/manga/'.length, -'/chapters'.length)).trim();
      if (!mangaId || mangaId.length > 80) return json({ error: 'invalid_manga_id' }, 400, {}, id);
      const page = numberParam(url, 'page', 1, MAX_PAGE);
      const limit = limitParam(url, 50);
      const language = (url.searchParams.get('language') || 'ar').trim().slice(0, 5);
      try {
        const result = await mangaChapters(mangaId, page, limit, language);
        return json({
          data: result.items,
          pagination: { current_page: page, has_next_page: result.hasNextPage },
          source: 'mangadex',
          language,
        }, 200, { 'Cache-Control': 'public, max-age=300' }, id);
      } catch (_) {
        return json({ error: 'mangadex_chapters_unavailable', message: 'تعذر تحميل الفصول العربية حاليًا.' }, 502, { 'Cache-Control': 'no-store' }, id);
      }
    }

    if (url.pathname.startsWith('/api/manga/chapter/')) {
      if (request.method !== 'GET') return json({ error: 'method_not_allowed' }, 405, {}, id);
      const chapterId = decodeURIComponent(url.pathname.slice('/api/manga/chapter/'.length)).trim();
      if (!chapterId || chapterId.length > 80) return json({ error: 'invalid_chapter_id' }, 400, {}, id);
      try {
        const result = await mangaChapterPages(chapterId);
        return json({
          source: 'mangadex',
          base_url: result.baseUrl,
          hash: result.hash,
          pages: result.pages.map((fileName) => `${result.baseUrl}/data/${result.hash}/${encodeURIComponent(fileName)}`),
        }, 200, { 'Cache-Control': 'public, max-age=300' }, id);
      } catch (_) {
        return json({ error: 'mangadex_pages_unavailable', message: 'تعذر تحميل صفحات الفصل حاليًا.' }, 502, { 'Cache-Control': 'no-store' }, id);
      }
    }

    if (url.pathname === '/api/manga' || url.pathname === '/api/animation') {
      if (request.method !== 'GET') return json({ error: 'method_not_allowed' }, 405, {}, id);

      const kind = url.pathname.endsWith('/manga') ? 'manga' : 'animation';
      const page = numberParam(url, 'page', 1, MAX_PAGE);
      const limit = limitParam(url, 24);
      const category = kind === 'animation'
        ? (url.searchParams.get('category') || 'popular').trim().toLowerCase()
        : 'default';

      try {
        const result = await contentCatalogPage(env.DB, kind, page, limit, env, category);
        return json({
          data: result.items.map((item) => ({
            id: item.id,
            title: item.title,
            title_ar: item.titleAr,
            synopsis: item.synopsis,
            image: item.imageUrl,
            score: item.score,
            year: item.year,
            type: item.type,
            source: item.source,
            source_url: item.sourceUrl,
          })),
          pagination: {
            current_page: result.page,
            has_next_page: result.hasNextPage,
          },
          catalog: {
            source: result.source,
            arabic: result.arabic,
            external_index: true,
          },
        }, 200, { 'Cache-Control': 'public, max-age=900' }, id);
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        const status = message === 'animation_provider_not_configured' ? 503 : 502;
        return json({
          error: 'content_provider_unavailable',
          message: kind === 'animation'
            ? 'مصدر الرسوم المتحركة غير مهيأ حاليًا.'
            : 'مصدر المانجا غير متاح مؤقتًا.',
          degraded: true,
        }, status, { 'Cache-Control': 'no-store' }, id);
      }
    }

    if (url.pathname === '/api/diagnostics/catalog') {
      if (request.method !== 'GET') return json({ error: 'method_not_allowed' }, 405, {}, id);

      try {
        const allowed = await enforceRateLimit(env.DB, request);
        if (!allowed) {
          return json({
            error: 'rate_limited',
            message: 'تم تجاوز الحد المؤقت للطلبات. حاول بعد دقيقة.',
          }, 429, { 'Retry-After': '60', 'Cache-Control': 'no-store' }, id);
        }

        const [animeCount, episodeCount, scoredCount, searchProbe, topProbe, latest] = await Promise.all([
          env.DB.prepare('SELECT COUNT(*) AS count FROM anime').first<{ count: number }>(),
          env.DB.prepare('SELECT COUNT(*) AS count FROM episodes').first<{ count: number }>(),
          env.DB.prepare('SELECT COUNT(*) AS count FROM anime WHERE score IS NOT NULL').first<{ count: number }>(),
          env.DB.prepare(`
            SELECT COUNT(*) AS count
            FROM anime
            WHERE title LIKE ? OR title_ar LIKE ?
          `).bind('%Naruto%', '%Naruto%').first<{ count: number }>(),
          env.DB.prepare(`
            SELECT COUNT(*) AS count
            FROM anime
            WHERE score IS NOT NULL
          `).first<{ count: number }>(),
          env.DB.prepare(`
            SELECT
              MIN(updated_at) AS oldest_updated_at,
              MAX(updated_at) AS newest_updated_at
            FROM anime
          `).first<{ oldest_updated_at: string | null; newest_updated_at: string | null }>(),
        ]);

        const anime = Number(animeCount?.count ?? 0);
        const episodes = Number(episodeCount?.count ?? 0);
        const scoredAnime = Number(scoredCount?.count ?? 0);
        const narutoMatches = Number(searchProbe?.count ?? 0);

        return json({
          status: 'ok',
          service: 'anime-platform-api',
          version: env.APP_VERSION || '1.30.0.18',
          database: {
            connected: true,
            anime_count: anime,
            episodes_count: episodes,
            scored_anime_count: scoredAnime,
            oldest_anime_updated_at: latest?.oldest_updated_at ?? null,
            newest_anime_updated_at: latest?.newest_updated_at ?? null,
          },
          catalog: {
            has_anime: anime > 0,
            has_scored_anime: scoredAnime > 0,
            search_probe_naruto_matches: narutoMatches,
            top_probe_scored_rows: Number(topProbe?.count ?? 0),
          },
          provider: {
            configured: Boolean(env.UPSTREAM_BASE),
            name: 'jikan',
          },
          note: 'Diagnostic only. This endpoint reports D1/catalog state and does not call the provider.',
        }, 200, { 'Cache-Control': 'no-store' }, id);
      } catch (_) {
        return json({
          status: 'error',
          service: 'anime-platform-api',
          version: env.APP_VERSION || '1.30.0.18',
          database: {
            connected: false,
          },
          error: 'diagnostic_query_failed',
        }, 503, { 'Cache-Control': 'no-store' }, id);
      }
    }

    if (url.pathname === '/api/diagnostics/catalog-sync') {
      if (request.method !== 'GET') return json({ error: 'method_not_allowed' }, 405, {}, id);
      try {
        const rows = await env.DB.prepare(`
          SELECT stream, page, last_run_at, last_success_at, total_upserted, last_error
          FROM catalog_sync_state
          ORDER BY stream ASC
        `).all<Record<string, unknown>>();

        return json({
          status: 'ok',
          enabled: env.CATALOG_SYNC_ENABLED !== 'false',
          pagesPerRun: Number(env.CATALOG_SYNC_PAGES || 5),
          pageSize: Number(env.CATALOG_SYNC_LIMIT || 24),
          streams: rows.results ?? [],
        }, 200, { 'Cache-Control': 'no-store' }, id);
      } catch (_) {
        return json({
          status: 'error',
          error: 'catalog_sync_state_unavailable',
        }, 503, { 'Cache-Control': 'no-store' }, id);
      }
    }

    if (url.pathname === '/api/admin/catalog/sync') {
      if (request.method !== 'POST') {
        return json({ error: 'method_not_allowed' }, 405, { Allow: 'POST, OPTIONS' }, id);
      }

      const configuredToken = env.CATALOG_SEED_TOKEN?.trim();
      const authorization = request.headers.get('Authorization') || '';
      const suppliedToken = authorization.startsWith('Bearer ')
        ? authorization.slice(7).trim()
        : '';

      if (!configuredToken || !suppliedToken || suppliedToken !== configuredToken) {
        return json({ error: 'unauthorized' }, 401, { 'Cache-Control': 'no-store' }, id);
      }

      try {
        const result = await runCatalogSync(env.DB, {
          UPSTREAM_BASE: env.UPSTREAM_BASE,
          CATALOG_SYNC_ENABLED: env.CATALOG_SYNC_ENABLED,
          CATALOG_SYNC_PAGES: env.CATALOG_SYNC_PAGES,
          CATALOG_SYNC_LIMIT: env.CATALOG_SYNC_LIMIT,
          TMDB_API_TOKEN: env.TMDB_API_TOKEN,
        });
        return json({
          status: result.status,
          operation: 'catalog_sync',
          ...result,
        }, result.status === 'partial' ? 207 : 200, { 'Cache-Control': 'no-store' }, id);
      } catch (_) {
        return json({
          error: 'catalog_sync_failed',
          message: 'تعذر تنفيذ مزامنة الكتالوج مؤقتًا.',
        }, 502, { 'Cache-Control': 'no-store' }, id);
      }
    }

    if (url.pathname === '/api/admin/catalog/seed') {
      if (request.method !== 'POST') {
        return json({ error: 'method_not_allowed' }, 405, { Allow: 'POST, OPTIONS' }, id);
      }

      const configuredToken = env.CATALOG_SEED_TOKEN?.trim();
      const authorization = request.headers.get('Authorization') || '';
      const suppliedToken = authorization.startsWith('Bearer ')
        ? authorization.slice(7).trim()
        : '';

      if (!configuredToken || !suppliedToken || suppliedToken !== configuredToken) {
        return json({ error: 'unauthorized' }, 401, { 'Cache-Control': 'no-store' }, id);
      }

      const rawOffset = Number.parseInt(url.searchParams.get('offset') || '0', 10);
      const rawLimit = Number.parseInt(url.searchParams.get('limit') || '6', 10);
      const offset = Number.isFinite(rawOffset) ? Math.max(0, Math.min(rawOffset, CATALOG_SEED_IDS.length)) : 0;
      const limit = Number.isFinite(rawLimit) ? Math.max(1, Math.min(rawLimit, 6)) : 6;

      try {
        const result = await seedCatalog(env.DB, provider(env), offset, limit);
        const succeeded = result.items.filter((item) => item.status === 'inserted_or_updated').length;
        const failed = result.items.filter((item) => item.status === 'failed').length;
        const notFound = result.items.filter((item) => item.status === 'not_found').length;

        return json({
          status: failed > 0 && succeeded === 0 ? 'failed' : 'ok',
          operation: 'catalog_seed',
          ...result,
          summary: { succeeded, failed, not_found: notFound },
        }, failed > 0 && succeeded === 0 ? 502 : 200, { 'Cache-Control': 'no-store' }, id);
      } catch (_) {
        return json({
          error: 'catalog_seed_failed',
          message: 'تعذر تنفيذ تهيئة الكتالوج مؤقتًا.',
        }, 502, { 'Cache-Control': 'no-store' }, id);
      }
    }

    if (url.pathname === '/api/events') {
      if (request.method !== 'POST') return json({ error: 'method_not_allowed' }, 405, {}, id);
      if (env.ANALYTICS_ENABLED !== 'true') {
        return json({ accepted: false, message: 'Analytics is disabled.' }, 403, { 'Cache-Control': 'no-store' }, id);
      }
      try {
        const allowed = await enforceRateLimit(env.DB, request);
        if (!allowed) return json({ error: 'rate_limited' }, 429, { 'Retry-After': '60' }, id);
        const body = await request.json();
        const event = validateEvent(body);
        if (!event) return json({ error: 'invalid_event' }, 400, {}, id);

        await env.DB.prepare(`
          INSERT INTO analytics_events
            (event, app_version, platform, anonymous_id, parameters_json)
          VALUES (?, ?, ?, ?, ?)
        `).bind(
          event.event,
          event.appVersion,
          event.platform,
          event.anonymousId,
          JSON.stringify(event.parameters),
        ).run();

        return json({ accepted: true }, 202, { 'Cache-Control': 'no-store' }, id);
      } catch (_) {
        return json({ error: 'invalid_request' }, 400, {}, id);
      }
    }

    if (request.method !== 'GET') return json({ error: 'method_not_allowed' }, 405, {}, id);
    if (!url.pathname.startsWith('/api/')) return json({ error: 'not_found' }, 404, {}, id);

    const maintenance = env.MAINTENANCE_MODE === 'true';
    const path = normalizePath(url.pathname);
    const isCatalogRead =
      path === '/top/anime' ||
      path === '/anime' ||
      path === '/anime/coming-soon' ||
      path === '/anime/schedule' ||
      path === '/characters/popular' ||
      /^\/characters\/-?\d+\/full$/.test(path) ||
      path === '/anime/seasons' ||
      /^\/anime\/-?\d+(?:\/full)?$/.test(path) ||
      /^\/anime\/-?\d+\/episodes$/.test(path);

    if (maintenance && isCatalogRead) {
      return json({
        error: 'maintenance',
        message: 'الخدمة في وضع الصيانة المؤقتة. حاول لاحقًا.',
      }, 503, { 'Retry-After': '300', 'Cache-Control': 'no-store' }, id);
    }

    try {
      const allowed = await enforceRateLimit(env.DB, request);
      if (!allowed) {
        return json({
          error: 'rate_limited',
          message: 'تم تجاوز الحد المؤقت للطلبات. حاول بعد دقيقة.',
        }, 429, { 'Retry-After': '60' }, id);
      }
    } catch (_) {
      // Fail-open for the limiter only; catalog availability should not depend on it.
    }

    const page = numberParam(url, 'page', 1, MAX_PAGE);
    const limit = limitParam(url);
    const cache = caches.default;
    const cacheKey = cacheKeyFor(request);

    if (Math.random() < 0.01) {
      ctx.waitUntil(
        env.DB.prepare(
          "DELETE FROM rate_limits WHERE window_started < datetime('now', '-10 minutes')"
        ).run()
      );
    }

    const cached = await cache.match(cacheKey);
    if (cached) {
      const outHeaders = new Headers(cached.headers);
      outHeaders.set('X-Cache', 'HIT');
      outHeaders.set('X-Request-ID', id);
      return new Response(cached.body, { status: cached.status, headers: outHeaders });
    }

    try {
      const currentProvider = provider(env);
      let payload: unknown;

      if (path === '/top/anime') {
        const result = await topCatalog(env.DB, currentProvider, page, limit);
        payload = {
          data: result.items.map(animeToApi),
          pagination: { current_page: result.page, has_next_page: result.hasNextPage },
          source: result.source,
          degraded: result.degraded === true,
          provider_failed: result.providerFailed === true,
        };
      } else if (path === '/anime') {
        const query = (url.searchParams.get('q') || '').trim().slice(0, MAX_QUERY_LENGTH);
        if (!query) return json({ error: 'missing_query' }, 400, {}, id);
        const result = await searchCatalog(env.DB, currentProvider, query, page, limit);
        payload = {
          data: result.items.map(animeToApi),
          pagination: { current_page: result.page, has_next_page: result.hasNextPage },
          source: result.source,
          degraded: result.degraded === true,
          provider_failed: result.providerFailed === true,
        };
      } else if (path === '/anime/schedule') {
        const allowedDays = new Set(['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']);
        const day = (url.searchParams.get('day') || '').trim().toLowerCase();
        if (!allowedDays.has(day)) return json({ error: 'invalid_day', message: 'day must be monday..sunday' }, 400, {}, id);

        const scheduleProvider = new JikanProvider(env.UPSTREAM_BASE);
        const items = await scheduleProvider.schedule(day);
        payload = {
          data: items.map(animeToApi).map((item) => ({
            ...item,
            scheduleDay: day,
            airing: true,
            scheduleStatus: 'scheduled',
          })),
          day,
          source: 'provider',
          degraded: false,
        };
      } else if (path === '/characters/popular') {
        const characterPage = numberParam(url, 'page', 1, MAX_PAGE);
        const characterLimit = limitParam(url);
        const characterProvider = new JikanProvider(env.UPSTREAM_BASE);
        const raw = await characterProvider.popularCharacters(characterPage, characterLimit);
        payload = {
          data: raw.map((item, index) => {
            const images = item.images as Record<string, unknown> | undefined;
            const jpg = images?.jpg as Record<string, unknown> | undefined;
            return {
              id: Number(item.mal_id) || 0,
              name: String(item.name ?? 'Unknown'),
              imageUrl: String(jpg?.large_image_url ?? jpg?.image_url ?? ''),
              favorites: Number(item.favorites) || 0,
              rank: (characterPage - 1) * characterLimit + index + 1,
            };
          }).filter((item) => item.id > 0),
          pagination: { current_page: characterPage, has_next_page: raw.length >= characterLimit },
          source: 'provider',
          degraded: false,
        };
      } else if (/^\/characters\/-?\d+\/full$/.test(path)) {
        const characterId = Number(path.split('/')[2]);
        if (!Number.isFinite(characterId) || characterId <= 0) return json({ error: 'invalid_character_id' }, 400, {}, id);
        const characterProvider = new JikanProvider(env.UPSTREAM_BASE);
        const raw = await characterProvider.characterDetails(String(characterId));
        if (!raw) return json({ error: 'not_found', message: 'بيانات الشخصية غير موجودة.' }, 404, {}, id);
        const images = raw.images as Record<string, unknown> | undefined;
        const jpg = images?.jpg as Record<string, unknown> | undefined;
        const animeography = Array.isArray(raw.anime) ? raw.anime : [];
        payload = {
          data: {
            id: characterId,
            name: String(raw.name ?? 'Unknown'),
            imageUrl: String(jpg?.large_image_url ?? jpg?.image_url ?? ''),
            favorites: Number(raw.favorites) || 0,
            about: raw.about == null ? null : String(raw.about),
            anime: animeography.map((row) => {
              const entry = row as Record<string, unknown>;
              const anime = entry.anime as Record<string, unknown> | undefined;
              const animeImages = anime?.images as Record<string, unknown> | undefined;
              const animeJpg = animeImages?.jpg as Record<string, unknown> | undefined;
              return {
                id: Number(anime?.mal_id) || 0,
                title: String(anime?.title ?? 'Unknown Anime'),
                imageUrl: String(animeJpg?.large_image_url ?? animeJpg?.image_url ?? ''),
                role: entry.role == null ? null : String(entry.role),
              };
            }).filter((item) => item.id > 0).slice(0, 30),
          },
          source: 'provider',
          degraded: false,
        };
      } else if (path === '/anime/coming-soon') {
        const result = await comingSoonCatalog(env.DB, page, limit);
        if (result.items.length > 0 || page > 1) {
          payload = {
            data: result.items.map(animeToApi),
            pagination: { current_page: result.page, has_next_page: result.hasNextPage },
            source: result.source,
            degraded: result.degraded === true,
          };
        } else {
          try {
            const upcomingProvider = new JikanProvider(env.UPSTREAM_BASE);
            const upcoming = await upcomingProvider.browse(page, limit, 'start_date', 'desc');
            const unaired = upcoming.items.filter((item) => {
              const aired = item.airedFrom ? Date.parse(item.airedFrom) : NaN;
              const status = (item.status ?? '').toLowerCase();
              return (Number.isNaN(aired) || aired > Date.now()) && (status.includes('not yet') || status.includes('upcoming'));
            });
            payload = {
              data: unaired.map(animeToApi),
              pagination: { current_page: page, has_next_page: upcoming.hasNextPage },
              source: 'provider',
              degraded: false,
            };
          } catch (_) {
            payload = {
              data: [],
              pagination: { current_page: page, has_next_page: false },
              source: 'database',
              degraded: true,
            };
          }
        }
      } else if (path === '/anime/seasons') {
        const yearParam = url.searchParams.get('year');
        if (!yearParam) {
          const years = await seasonYears(env.DB);
          payload = { data: years, source: 'database', degraded: false };
        } else {
          const year = Number.parseInt(yearParam, 10);
          if (!Number.isFinite(year) || year < 1900 || year > 2200) {
            return json({ error: 'invalid_year' }, 400, {}, id);
          }
          const result = await seasonCatalog(env.DB, year, page, limit);
          payload = {
            data: result.items.map(animeToApi),
            pagination: { current_page: result.page, has_next_page: result.hasNextPage },
            source: result.source,
            degraded: result.degraded === true,
          };
        }
      } else {
        const detailsMatch = path.match(/^\/anime\/(\-?\d+)(?:\/full)?$/);
        const episodesMatch = path.match(/^\/anime\/(\-?\d+)\/episodes$/);
        const videoMatch = path.match(/^\/anime\/(\-?\d+)\/episodes\/(\d+)\/video$/);

        if (videoMatch) {
          const asset = await videoProvider.getEpisodeVideo(videoMatch[1], Number(videoMatch[2]));
          if (!asset) {
            return json({
              error: 'video_not_available',
              message: 'مصدر فيديو مرخص غير مفعّل حاليًا.',
              policy: {
                architecture: 'legal-only',
                providerConfigured: false,
                playbackEnabled: false,
              },
            }, 404, {}, id);
          }
          payload = { data: asset };
        } else if (detailsMatch) {
          const result = await getAnime(env.DB, currentProvider, detailsMatch[1]);
          if (!result.item && result.degraded) {
            return json({
              error: 'provider_unavailable',
              message: 'بيانات هذا الأنمي غير موجودة في قاعدة البيانات ومزود البيانات غير متاح حاليًا.',
            }, 503, { 'Retry-After': '30', 'Cache-Control': 'no-store' }, id);
          }
          if (!result.item) return json({ error: 'anime_not_found' }, 404, {}, id);
          payload = { data: animeToApi(result.item), source: result.source, degraded: result.degraded === true };
        } else if (episodesMatch) {
          const result = await getEpisodes(
            env.DB,
            currentProvider,
            episodesMatch[1],
            page,
            limit,
            arabicEpisodeProvider(env),
            externalSourceProvider(env),
          );
          if (!result.items.length && result.degraded && result.parentMissing) {
            return json({
              error: 'provider_unavailable',
              message: 'بيانات الأنمي غير موجودة محليًا ومزود البيانات غير متاح حاليًا.',
            }, 503, { 'Retry-After': '30', 'Cache-Control': 'no-store' }, id);
          }
          payload = {
            data: result.items.map(episodeToApi),
            pagination: { current_page: result.page, has_next_page: result.hasNextPage },
            source: result.source,
            degraded: result.degraded === true,
          };
        } else {
          return json({ error: 'not_found' }, 404, {}, id);
        }
      }

      const degraded = !!(payload && typeof payload === 'object' && (payload as Record<string, unknown>).degraded === true);
      const response = json(payload, 200, {
        'Cache-Control': degraded ? 'no-store' : `public, max-age=${env.CACHE_SECONDS || 900}`,
        'X-Provider-Status': degraded ? 'degraded' : 'ok',
        'X-Cache': 'MISS',
      }, id);
      if (!degraded) ctx.waitUntil(cache.put(cacheKey, response.clone()));
      return response;
    } catch (error) {
      if (error instanceof CatalogDatabaseError) {
        return json({
          error: 'catalog_database_unavailable',
          message: 'قاعدة بيانات الكتالوج غير متاحة حاليًا.',
          degraded: true,
        }, 503, { 'Retry-After': '15', 'Cache-Control': 'no-store' }, id);
      }
      const message = error instanceof Error ? error.message : 'unknown_error';
      if (message.startsWith('Provider 429')) {
        return json({
          error: 'upstream_rate_limited',
          message: 'المصدر مشغول مؤقتًا. حاول بعد قليل.',
        }, 429, { 'Retry-After': '30' }, id);
      }
      if (message.startsWith('Provider ')) {
        return json({
          error: 'upstream_error',
          message: 'تعذر جلب بيانات جديدة من مزود البيانات.',
        }, 502, {}, id);
      }
      return json({
        error: 'server_error',
        message: 'حدث خطأ داخلي مؤقت.',
      }, 500, {}, id);
    }
  },
};
