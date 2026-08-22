export interface AnimeCharacter {
  id: number;
  name: string;
  imageUrl?: string | null;
  role?: string | null;
}

export interface AnimeRelation {
  relation: string;
  entries: Array<{ id: number; title: string; type?: string | null }>;
}

export interface AnimeRecommendation {
  id: number;
  title: string;
  imageUrl?: string | null;
}

export interface AnimeRecord {
  id?: number;
  /** Stable app identity. Provider IDs remain separate and are never overloaded. */
  canonicalId?: string;
  /** MyAnimeList ID. This is the only ID accepted by the primary playback API. */
  malId?: number | null;
  /** AniList ID used by Anivexa and AniList APIs. */
  anilistId?: number | null;
  /** Provider-native identifier when the record is not represented by MAL. */
  providerId?: string | null;
  providerName?: string | null;
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
  source?: string | null;
  duration?: string | null;
  airedFrom?: string | null;
  airedTo?: string | null;
  rating?: string | null;
  rank?: number | null;
  members?: number | null;
  popularity?: number | null;
  season?: string | null;
  seasonYear?: number | null;
  broadcastDay?: string | null;
  broadcastTime?: string | null;
  studioNames?: string[];
  trailerUrl?: string | null;
  trailerImageUrl?: string | null;
  backgroundImageUrl?: string | null;
  characters?: AnimeCharacter[];
  relations?: AnimeRelation[];
  recommendations?: AnimeRecommendation[];
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
