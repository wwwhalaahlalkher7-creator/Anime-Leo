export interface VideoSubtitle {
  language: string;
  url: string;
}

export interface VideoAsset {
  streamUrl: string;
  downloadUrl?: string | null;
  subtitles?: VideoSubtitle[];
  provider: string;
  licenseId?: string | null;
}

/**
 * V1.16 legal-video contract.
 * Implementations must represent a provider that has explicit permission to
 * distribute the referenced video. The app/backend never scrapes or proxies
 * unofficial streams through this interface.
 */
export interface LicensedVideoProvider {
  readonly name: string;
  readonly licenseId: string;
  readonly rightsScope: string;
  getEpisodeVideo(animeExternalId: string, episodeNumber: number): Promise<VideoAsset | null>;
  healthCheck(): Promise<boolean>;
}

export interface VideoProvider extends LicensedVideoProvider {}

/** Safe default until a reviewed licensed provider is configured. */
export class NoOpVideoProvider implements VideoProvider {
  readonly name = 'none';
  readonly licenseId = 'not-configured';
  readonly rightsScope = 'none';

  async getEpisodeVideo(_animeExternalId: string, _episodeNumber: number): Promise<VideoAsset | null> {
    return null;
  }

  async healthCheck(): Promise<boolean> {
    return false;
  }
}
