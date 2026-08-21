import type { EpisodeSource } from './types';

export interface ExternalSourceProvider {
  readonly name: string;
  listSources(animeExternalId: string, episodeNumber: number): Promise<EpisodeSource[]>;
  healthCheck(): Promise<boolean>;
}

interface SourceResponse {
  sources?: unknown;
  data?: unknown;
}

function asMap(value: unknown): Record<string, unknown> | null {
  return value && typeof value === 'object' && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function asString(value: unknown): string | null {
  return value == null ? null : String(value).trim() || null;
}

function normalizeSource(raw: unknown, providerName: string): EpisodeSource | null {
  const map = asMap(raw);
  if (!map) return null;
  const url = asString(map.url ?? map.source_url ?? map.page_url ?? map.link);
  if (!url) return null;
  let parsed: URL;
  try {
    parsed = new URL(url);
    if (!['http:', 'https:'].includes(parsed.protocol)) return null;
  } catch (_) {
    return null;
  }
  return {
    provider: asString(map.provider) ?? providerName,
    language: asString(map.language) ?? 'unknown',
    available: map.available !== false,
    externalId: asString(map.external_id ?? map.id),
    url: parsed.toString(),
    label: asString(map.label ?? map.name),
  };
}

export class ConfiguredExternalSourceProvider implements ExternalSourceProvider {
  readonly name: string;
  private readonly baseUrl: string;
  private readonly apiKey?: string;

  constructor(baseUrl: string, name = 'external', apiKey?: string) {
    this.name = name;
    this.baseUrl = baseUrl.replace(/\/$/, '');
    this.apiKey = apiKey?.trim() || undefined;
  }

  private async get(path: string): Promise<SourceResponse> {
    const response = await fetch(`${this.baseUrl}${path}`, {
      headers: {
        Accept: 'application/json',
        ...(this.apiKey ? { Authorization: `Bearer ${this.apiKey}` } : {}),
      },
    });
    if (!response.ok) throw new Error(`External source provider ${response.status}`);
    const body = asMap(await response.json());
    if (!body) throw new Error('Invalid external source provider response');
    return body as SourceResponse;
  }

  async listSources(animeExternalId: string, episodeNumber: number): Promise<EpisodeSource[]> {
    const response = await this.get(`/anime/${encodeURIComponent(animeExternalId)}/episodes/${episodeNumber}/sources`);
    const raw = Array.isArray(response.sources) ? response.sources : Array.isArray(response.data) ? response.data : [];
    return raw
      .map((item) => normalizeSource(item, this.name))
      .filter((item): item is EpisodeSource => item !== null)
      .filter((item) => item.available);
  }

  async healthCheck(): Promise<boolean> {
    try {
      const response = await fetch(`${this.baseUrl}/health`, { headers: { Accept: 'application/json' } });
      return response.ok;
    } catch (_) {
      return false;
    }
  }
}

export class NoOpExternalSourceProvider implements ExternalSourceProvider {
  readonly name = 'none';
  async listSources(_animeExternalId: string, _episodeNumber: number): Promise<EpisodeSource[]> {
    return [];
  }
  async healthCheck(): Promise<boolean> {
    return false;
  }
}
