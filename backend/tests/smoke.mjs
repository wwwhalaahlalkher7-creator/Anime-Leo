const base = (process.env.API_BASE_URL || '').replace(/\/$/, '');

if (!base) {
  console.error('API_BASE_URL is required.');
  process.exit(1);
}

const checks = [
  ['/health', [200]],
  ['/config', [200]],
  ['/providers', [200]],
  ['/health?deep=true', [200, 503]],
  ['/top/anime?page=1&limit=3', [200]],
  ['/anime?q=naruto&page=1&limit=3', [200]],
  ['/anime/20/full', [200]],
  ['/anime/20/episodes?page=1&limit=3', [200, 503]],
  ['/manga?page=1&limit=3', [200, 502, 503]],
  ['/animation?page=1&limit=3', [200, 502, 503]],
  ['/diagnostics/catalog', [200]],
  ['/anivexa/map-mal/1', [200, 404, 429, 500, 502, 503]],
  ['/anivexa/episodes/1', [200, 404, 429, 500, 502, 503]],
  ['/playback/1/1', [200, 400, 404, 429, 502, 503]],
  ['/dubs/mydublist/1', [200, 400, 404, 429, 502, 503]],
];

let failed = false;

for (const [path, expected] of checks) {
  const url = `${base}${path}`;
  try {
    const response = await fetch(url, {
      headers: { 'Accept': 'application/json', 'X-Request-ID': 'smoke-test' },
    });
    const text = await response.text();
    console.log(`${response.status} ${url}`);
    if (!expected.includes(response.status)) {
      failed = true;
      console.error(`Expected one of: ${expected.join(', ')}`);
      console.error(text.slice(0, 500));
      continue;
    }
    if (path.startsWith('/top/anime') || path.startsWith('/anime?q=') || path.startsWith('/manga') || path.startsWith('/animation')) {
      try {
        const body = JSON.parse(text);
        if (!Array.isArray(body.data) || !body.pagination) {
          failed = true;
          console.error('Invalid catalog response shape.');
        }
        if (body.degraded === true) console.log('  degraded=true (provider fallback active)');
      } catch (_) {
        failed = true;
        console.error('Response is not valid JSON.');
      }
    }
    if (path === '/health?deep=true' && response.status === 503) {
      try {
        const body = JSON.parse(text);
        if (body.provider !== 'degraded' && body.provider !== 'unavailable') {
          failed = true;
          console.error('Deep health did not report provider degradation.');
        }
        console.log('  provider degraded is accepted by V1.10 resilience mode');
      } catch (_) {
        failed = true;
        console.error('Deep health response is not valid JSON.');
      }
    }
  } catch (error) {
    failed = true;
    console.error(`Request failed: ${url}`, error);
  }
}

process.exit(failed ? 1 : 0);
