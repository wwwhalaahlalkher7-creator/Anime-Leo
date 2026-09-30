import type { AnimeProvider, AnimeRecord, EpisodeRecord, ProviderPage } from './types';

export interface ProviderAttempt<T> {
  operation: string;
  run: (provider: AnimeProvider) => Promise<T>;
}

/**
 * Coordinates metadata providers in priority order.
 *
 * Providers are intentionally isolated behind a common contract. Each
 * operation has a bounded timeout so a slow provider cannot block the
 * fallback chain indefinitely.
 */
export class ProviderManager implements AnimeProvider {
  readonly name: string;
  private readonly providers: AnimeProvider[];
  private readonly timeoutMs: number;

  constructor(providers: AnimeProvider[], timeoutMs = 8_000) {
    this.providers = providers.filter(Boolean);
    this.timeoutMs = Math.max(1_000, timeoutMs);
    this.name = this.providers.map((provider) => provider.name).join(',') || 'none';
  }

  listProviders(): string[] {
    return this.providers.map((provider) => provider.name);
  }

  private async fallback<T>(attempt: ProviderAttempt<T>): Promise<T> {
    let lastError: unknown;
    for (const provider of this.providers) {
      try {
        return await Promise.race([
          attempt.run(provider),
          new Promise<never>((_, reject) =>
            setTimeout(() => reject(new Error(`Provider timeout during ${attempt.operation}`)), this.timeoutMs),
          ),
        ]);
      } catch (error) {
        lastError = error;
      }
    }
    throw lastError instanceof Error ? lastError : new Error(`All providers failed during ${attempt.operation}`);
  }

  search(query: string, page: number, limit: number): Promise<ProviderPage<AnimeRecord>> {
    return this.fallback({
      operation: 'search',
      run: (provider) => provider.search(query, page, limit),
    });
  }

  top(page: number, limit: number): Promise<ProviderPage<AnimeRecord>> {
    return this.fallback({
      operation: 'top',
      run: (provider) => provider.top(page, limit),
    });
  }

  details(externalId: string): Promise<AnimeRecord | null> {
    return this.fallback({
      operation: 'details',
      run: (provider) => provider.details(externalId),
    });
  }

  episodes(externalId: string, page: number, limit: number): Promise<ProviderPage<EpisodeRecord>> {
    return this.fallback({
      operation: 'episodes',
      run: (provider) => provider.episodes(externalId, page, limit),
    });
  }

  async healthCheck(): Promise<boolean> {
    if (!this.providers.length) return false;
    for (const provider of this.providers) {
      try {
        const healthy = await Promise.race([
          provider.healthCheck(),
          new Promise<boolean>((resolve) => setTimeout(() => resolve(false), this.timeoutMs)),
        ]);
        if (healthy) return true;
      } catch (_) {
        // Continue to the next provider.
      }
    }
    return false;
  }
}
