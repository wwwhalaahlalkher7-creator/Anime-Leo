/**
 * Anime Leo adapter for ani-cli-arabic's upstream API.
 *
 * The upstream project exposes its API credentials dynamically and provides
 * anime/episode/server endpoints. Anime Leo consumes the returned playable
 * URLs as metadata; it does not store video bytes or proxy the media stream.
 */

const DEFAULT_ENDPOINT = 'https://api.ani-cli-arabic.dev';
const DEFAULT_AUTH_KEY = '6rK9z0XyW8vQ3J7pL2mN4sB1tH5gD0fA';

function endpoint(env) {
  return String(env?.ANI_CLI_AR_ENDPOINT || DEFAULT_ENDPOINT).replace(/\/$/, '');
}

async function credentials(env) {
  const apiBase = env?.ANI_CLI_AR_API_BASE;
  const token = env?.ANI_CLI_AR_TOKEN;
  if (apiBase && token) return { apiBase: String(apiBase).replace(/\/$/, ''), token: String(token) };

  const response = await fetch(`${endpoint(env)}/credentials`, {
    headers: {
      'X-Auth-Key': String(env?.ANI_CLI_AR_AUTH_SECRET || DEFAULT_AUTH_KEY),
      'User-Agent': 'AnimeLeo/1.29 ani-cli-arabic-adapter',
    },
  });
  if (!response.ok) throw new Error(`ani-cli-arabic credentials failed: ${response.status}`);
  const data = await response.json();
  if (!data?.ANI_CLI_AR_API_BASE || !data?.ANI_CLI_AR_TOKEN) {
    throw new Error('ani-cli-arabic credentials response is incomplete');
  }
  return {
    apiBase: String(data.ANI_CLI_AR_API_BASE).replace(/\/$/, ''),
    token: String(data.ANI_CLI_AR_TOKEN),
  };
}

async function postForm(url, values) {
  const body = new URLSearchParams();
  for (const [key, value] of Object.entries(values)) body.set(key, String(value));
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      Accept: 'application/json',
      'User-Agent': 'AnimeLeo/1.29 ani-cli-arabic-adapter',
    },
    body,
  });
  if (!response.ok) throw new Error(`ani-cli-arabic upstream failed: ${response.status}`);
  return response.json();
}

function collectCandidateUrls(value, key = '', out = []) {
  const normalizedKey = String(key).toLowerCase();
  const urlLikeKey = /(?:url|link|source|stream|file|server|mediafire)/.test(normalizedKey);
  if (typeof value === 'string') {
    if (/^https?:\/\//i.test(value) && (urlLikeKey || /\.(?:m3u8|mp4|mkv)(?:\?|$)/i.test(value) || /mediafire\.com/i.test(value))) {
      out.push(value);
    }
    return out;
  }
  if (Array.isArray(value)) {
    for (const item of value) collectCandidateUrls(item, key, out);
    return out;
  }
  if (value && typeof value === 'object') {
    for (const [childKey, item] of Object.entries(value)) collectCandidateUrls(item, childKey, out);
  }
  return out;
}

async function resolveMediafire(url) {
  if (!/mediafire\.com/i.test(url)) return url;
  try {
    const response = await fetch(url, {
      headers: { 'User-Agent': 'Mozilla/5.0 (AnimeLeo/1.29)' },
    });
    if (!response.ok) return url;
    const html = await response.text();
    const match = html.match(/https:\/\/download[^"'\s<]+/i);
    return match ? match[0].replace(/\\u0026/g, '&') : url;
  } catch (_) {
    return url;
  }
}

function qualityFromUrl(url) {
  const match = String(url).match(/(?:^|[^0-9])(2160|1440|1080|720|480|360)p?(?:[^0-9]|$)/i);
  return match ? `${match[1]}p` : 'auto';
}

function unique(items) {
  const seen = new Set();
  return items.filter((item) => {
    const key = `${item.url}|${item.quality}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

/**
 * Resolve a MAL/catalog ID and episode using ani-cli-arabic.
 *
 * The adapter intentionally accepts a MAL id because the catalog already
 * uses MAL/Jikan ids. ani-cli-arabic's own API exposes MalId in its anime
 * records and AnimeId for its episode/server endpoints.
 */
export async function getAniCliArabicPlayback({ malId, episode, animeType = 'SERIES', env }) {
  const creds = await credentials(env);

  const animeList = await postForm(`${creds.apiBase}/anime/load_anime_list_v2.php`, {
    UserId: 0,
    Language: 'English',
    FilterType: 'SEARCH',
    FilterData: String(malId),
    Type: animeType,
    From: 0,
    Token: creds.token,
  }).catch(() => []);

  let animeId = null;
  if (Array.isArray(animeList)) {
    const exact = animeList.find((item) => Number(item?.MalId) === Number(malId));
    animeId = exact?.AnimeId ?? animeList[0]?.AnimeId ?? null;
  }

  if (!animeId) {
    throw new Error(`ani-cli-arabic anime mapping not found for MAL ${malId}`);
  }

  const raw = await postForm(`${creds.apiBase}/anime/load_servers.php`, {
    UserId: 0,
    AnimeId: animeId,
    Episode: episode,
    AnimeType: animeType,
    Token: creds.token,
  });

  const candidates = collectCandidateUrls(raw);
  const resolved = await Promise.all(candidates.map((url) => resolveMediafire(url)));
  const urls = unique(resolved.map((url) => ({
    url,
    quality: qualityFromUrl(url),
  }))).filter((item) => !/mediafire\.com\/file/i.test(item.url));

  if (!urls.length) throw new Error('ani-cli-arabic returned no playable URLs');

  return {
    provider: 'ani-cli-arabic',
    language: 'sub',
    animeId: String(animeId),
    malId: Number(malId),
    episode: Number(episode),
    streams: urls.map((item) => {
      const isHls = /\.m3u8(?:\?|$)/i.test(item.url);
      const downloadable = !isHls && /^https?:\/\//i.test(item.url);
      return {
        url: item.url,
        quality: item.quality,
        type: isHls ? 'hls' : 'http',
        downloadable,
        downloadUrl: downloadable ? item.url : null,
      };
    }),
    subtitles: [],
    sourcePage: null,
  };
}

export async function aniCliArabicHealth(env) {
  try {
    await credentials(env);
    return true;
  } catch (_) {
    return false;
  }
}
