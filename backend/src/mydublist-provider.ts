/** MyDubList integration. Dataset is CC BY 4.0 per upstream README. */

const DEFAULT_BASE = 'https://raw.githubusercontent.com/Joelis57/MyDubList/main';
const cache = new Map();
const TTL_MS = 6 * 60 * 60 * 1000;

export async function getArabicDubStatus(malId, env) {
  const id = Number(malId);
  if (!Number.isInteger(id) || id <= 0) return { malId: id, language: 'arabic', available: false, count: 0 };

  const base = String(env?.MYDUBLIST_BASE_URL || DEFAULT_BASE).replace(/\/$/, '');
  const key = `${base}:${id}`;
  const cached = cache.get(key);
  if (cached && cached.expiresAt > Date.now()) return cached.value;

  const url = `${base}/dubs/counts/dubbed_arabic.json`;
  const response = await fetch(url, { headers: { Accept: 'application/json' } });
  if (!response.ok) throw new Error(`MyDubList request failed: ${response.status}`);
  const data = await response.json();
  const count = Number(data?.[String(id)] || 0);
  const partial = Array.isArray(data?.partial) && data.partial.map(Number).includes(id);
  const value = {
    malId: id,
    language: 'arabic',
    available: count > 0 || partial,
    count,
    partial,
    source: 'MyDubList',
    license: 'CC BY 4.0',
  };
  cache.set(key, { value, expiresAt: Date.now() + TTL_MS });
  return value;
}
