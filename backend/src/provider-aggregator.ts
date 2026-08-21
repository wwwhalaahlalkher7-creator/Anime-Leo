import type { AnimeProvider, AnimeRecord, EpisodeRecord, ProviderPage } from './types';
import { identityFromExternalId } from './identity';

export type ProviderStatus = {
  name: string;
  healthy: boolean;
};

/**
 * Aggregates metadata providers without treating provider-native IDs as a
 * shared namespace. Results are merged by canonical identity, with the
 * first configured provider winning conflicting scalar fields while missing
 * fields are filled from later providers.
 *
 * This class intentionally aggregates metadata/episode availability only.
 * Video playback remains behind the LicensedVideoProvider contract.
 */
export class ProviderAggregator implements AnimeProvider {
  readonly name: string;
  private readonly providers: AnimeProvider[];

  constructor(providers: AnimeProvider[]) {
    this.providers = providers.filter(Boolean);
    this.name = this.providers.map((provider) => provider.name).join(',') || 'none';
  }

  listProviders(): string[] {
    return this.providers.map((provider) => provider.name);
  }

  async statuses(): Promise<ProviderStatus[]> {
    return Promise.all(this.providers.map(async (provider) => {
      try {
        return { name: provider.name, healthy: await provider.healthCheck() };
      } catch (_) {
        return { name: provider.name, healthy: false };
      }
    }));
  }

  private async collect<T>(operation: string, run: (provider: AnimeProvider) => Promise<T>): Promise<T[]> {
    const settled = await Promise.allSettled(this.providers.map((provider) => run(provider)));
    const values: T[] = [];
    let lastError: unknown;
    for (const result of settled) {
      if (result.status === 'fulfilled') values.push(result.value);
      else lastError = result.reason;
    }
    if (!values.length) {
      throw lastError instanceof Error
        ? lastError
        : new Error(`All providers failed during ${operation}`);
    }
    return values;
  }

  private mergeAnime(records: AnimeRecord[], limit: number): AnimeRecord[] {
    const merged = new Map<string, AnimeRecord>();

    for (const record of records) {
      const key = record.canonicalId || identityFromExternalId(record.externalId).canonicalId;
      const current = merged.get(key);
      if (!current) {
        merged.set(key, { ...record });
        continue;
      }

      merged.set(key, {
        ...current,
        malId: current.malId ?? record.malId ?? null,
        anilistId: current.anilistId ?? record.anilistId ?? null,
        providerId: current.providerId ?? record.providerId ?? null,
        providerName: current.providerName ?? record.providerName ?? null,
        titleAr: current.titleAr ?? record.titleAr ?? null,
        synopsis: current.synopsis ?? record.synopsis ?? null,
        imageUrl: current.imageUrl ?? record.imageUrl ?? null,
        genres: current.genres.length ? current.genres : record.genres,
        status: current.status ?? record.status ?? null,
        episodes: current.episodes ?? record.episodes ?? null,
        score: current.score ?? record.score ?? null,
        year: current.year ?? record.year ?? null,
        type: current.type ?? record.type ?? null,
      });

      // If a later provider resolves a real MAL ID, promote the canonical
      // playback identity and never leak an AniList-negative external ID.
      const result = merged.get(key)!;
      if (result.malId != null) {
        result.canonicalId = `mal:${result.malId}`;
        result.externalId = String(result.malId);
      }
    }

    return Array.from(merged.values()).slice(0, limit);
  }

  private mergeEpisodes(pages: ProviderPage<EpisodeRecord>[], limit: number): ProviderPage<EpisodeRecord> {
    const byNumber = new Map<number, EpisodeRecord>();
    let hasNextPage = false;
    let page = pages[0]?.page ?? 1;

    for (const result of pages) {
      page = result.page || page;
      hasNextPage ||= result.hasNextPage;
      for (const episode of result.items) {
        const current = byNumber.get(episode.episodeNumber);
        if (!current) {
          byNumber.set(episode.episodeNumber, { ...episode, sources: [...(episode.sources ?? [])] });
          continue;
        }
        const sourceKeys = new Set((current.sources ?? []).map((source) => `${source.provider}:${source.externalId ?? source.url ?? ''}`));
        const sources = [...(current.sources ?? [])];
        for (const source of episode.sources ?? []) {
          const key = `${source.provider}:${source.externalId ?? source.url ?? ''}`;
          if (!sourceKeys.has(key)) sources.push(source);
        }
        byNumber.set(episode.episodeNumber, {
          ...current,
          title: current.title ?? episode.title,
          thumbnail: current.thumbnail ?? episode.thumbnail,
          duration: current.duration ?? episode.duration,
          aired: current.aired ?? episode.aired,
          sources,
        });
      }
    }

    return {
      items: Array.from(byNumber.values()).sort((a, b) => a.episodeNumber - b.episodeNumber).slice(0, limit),
      page,
      hasNextPage,
    };
  }

  async search(query: string, page: number, limit: number): Promise<ProviderPage<AnimeRecord>> {
    const pages = await this.collect('search', (provider) => provider.search(query, page, limit));
    return {
      items: this.mergeAnime(pages.flatMap((result) => result.items), limit),
      page,
      hasNextPage: pages.some((result) => result.hasNextPage),
    };
  }

  async top(page: number, limit: number): Promise<ProviderPage<AnimeRecord>> {
    const pages = await this.collect('top', (provider) => provider.top(page, limit));
    return {
      items: this.mergeAnime(pages.flatMap((result) => result.items), limit),
      page,
      hasNextPage: pages.some((result) => result.hasNextPage),
    };
  }

  async details(externalId: string): Promise<AnimeRecord | null> {
    // The catalog exposes a canonical MAL ID whenever one exists, but each
    // provider has its own native namespace. Do not blindly pass a MAL ID to
    // a provider that expects an AniList ID. AniListProvider intentionally
    // accepts a positive value as `idMal`, while negative values represent
    // legacy AniList-only IDs. Jikan only accepts positive MAL IDs.
    const numeric = Number.parseInt(externalId, 10);
    const isPositiveNumeric = /^\d+$/.test(externalId.trim()) && Number.isInteger(numeric) && numeric > 0;
    const isNegativeAniList = /^-\d+$/.test(externalId.trim()) && Math.abs(numeric) > 0;

    const results = await this.collect('details', async (provider) => {
      if (provider.name === 'jikan' && !isPositiveNumeric) return null;
      if (provider.name === 'anilist' && !isPositiveNumeric && !isNegativeAniList) return null;
      return provider.details(externalId);
    });
    const records = results.filter((item): item is AnimeRecord => item != null);
    return this.mergeAnime(records, 1)[0] ?? null;
  }

  async episodes(externalId: string, page: number, limit: number): Promise<ProviderPage<EpisodeRecord>> {
    const pages = await this.collect('episodes', (provider) => provider.episodes(externalId, page, limit));
    return this.mergeEpisodes(pages, limit);
  }

  async healthCheck(): Promise<boolean> {
    const statuses = await this.statuses();
    return statuses.some((status) => status.healthy);
  }
}
