export interface AnimeRecord {
  id?: number;
  externalId: string;
  title: string;
  titleAr?: string | null;
  synopsis?: string | null;
  imageUrl?: string | null;
  genres: string[];
  status?: string | null;
  episodes?: number | null;
  score?: number | null;
  year?: number | null;
  type?: string | null;
}

export interface EpisodeSource {
  provider: string;
  language: string;
  available: boolean;
  externalId?: string | null;
  /** Public episode/source page. The backend does not proxy or store video bytes. */
  url?: string | null;
  label?: string | null;
}

export interface EpisodeRecord {
  externalId: string;
  animeExternalId: string;
  episodeNumber: number;
  title?: string | null;
  thumbnail?: string | null;
  duration?: string | null;
  aired?: string | null;
  sources?: EpisodeSource[];
}

export interface AnimeProvider {
  readonly name: string;
  search(query: string, page: number, limit: number): Promise<ProviderPage<AnimeRecord>>;
  top(page: number, limit: number): Promise<ProviderPage<AnimeRecord>>;
  details(externalId: string): Promise<AnimeRecord | null>;
  episodes(externalId: string, page: number, limit: number): Promise<ProviderPage<EpisodeRecord>>;
  healthCheck(): Promise<boolean>;
}

export interface ProviderPage<T> {
  items: T[];
  page: number;
  hasNextPage: boolean;
}
