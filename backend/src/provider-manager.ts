import type { AnimeProvider, AnimeRecord, EpisodeRecord, ProviderPage } from './types';

export interface ProviderAttempt<T> {
  provider: AnimeProvider;
  operation: string;
  run: (provider: AnimeProvider) => Promise<T>;
}

/**
 * Coordinates metadata providers in priority order.
 *
 * V1.12 registers Jikan as the only currently implemented provider. The
 * manager is intentionally provider-agnostic so an authorized second
 * metadata provider can be added without changing catalog.ts or Flutter.
 */
export class ProviderManager implements AnimeProvider {
  readonly name: string;
  private readonly providers: AnimeProvider[];

  constructor(providers: AnimeProvider[]) {
    this.providers = providers.filter(Boolean);
    this.name = this.providers.map((provider) => provider.name).join(',') || 'none';
  }

  listProviders(): string[] {
    return this.providers.map((provider) => provider.name);
  }

  private async fallback<T>(attempt: ProviderAttempt<T>): Promise<T> {
    let lastError: unknown;
    for (const provider of this.providers) {
      try {
        return await attempt.run(provider);
      } catch (error) {
        lastError = error;
      }
    }
    throw lastError instanceof Error ? lastError : new Error(`All providers failed during ${attempt.operation}`);
  }

  search(query: string, page: number, limit: number): Promise<ProviderPage<AnimeRecord>> {
    return this.fallback({
      operation: 'search',
      provider: this.providers[0],
      run: (provider) => provider.search(query, page, limit),
    });
  }

  top(page: number, limit: number): Promise<ProviderPage<AnimeRecord>> {
    return this.fallback({
      operation: 'top',
      provider: this.providers[0],
      run: (provider) => provider.top(page, limit),
    });
  }

  details(externalId: string): Promise<AnimeRecord | null> {
    return this.fallback({
      operation: 'details',
      provider: this.providers[0],
      run: (provider) => provider.details(externalId),
    });
  }

  episodes(externalId: string, page: number, limit: number): Promise<ProviderPage<EpisodeRecord>> {
    return this.fallback({
      operation: 'episodes',
      provider: this.providers[0],
      run: (provider) => provider.episodes(externalId, page, limit),
    });
  }

  async healthCheck(): Promise<boolean> {
    if (!this.providers.length) return false;
    for (const provider of this.providers) {
      try {
        if (await provider.healthCheck()) return true;
      } catch (_) {
        // Continue to the next provider.
      }
    }
    return false;
  }
}
