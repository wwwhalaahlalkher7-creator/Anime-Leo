import anivexaWorker from './anivexa/index.js';

export async function handleAnivexa(request: Request): Promise<Response> {
  const incoming = new URL(request.url);
  const mounted = new URL(request.url);
  const prefix = '/api/anivexa';
  const stripped = incoming.pathname.startsWith(prefix)
    ? incoming.pathname.slice(prefix.length) || '/'
    : incoming.pathname;

  mounted.pathname = stripped;
  const forwarded = new Request(mounted.toString(), request);
  return anivexaWorker.fetch(forwarded, {});
}
