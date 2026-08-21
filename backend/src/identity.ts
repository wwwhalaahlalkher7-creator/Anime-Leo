/**
 * Canonical content identity helpers.
 *
 * IDs are provider-specific and must never be overloaded:
 * - mal:<id>     = MyAnimeList/Jikan identity (playback key)
 * - anilist:<id> = AniList identity (Anivexa key)
 * - <provider>:<id> = provider-native fallback identity
 */
export type ContentIdentity = {
  canonicalId: string;
  malId: number | null;
  anilistId: number | null;
  providerId: string;
  providerName: string;
};

export function positiveInt(value: unknown): number | null {
  const n = typeof value === 'number' ? value : Number(value);
  return Number.isInteger(n) && n > 0 ? n : null;
}

export function identityFromProvider(
  providerName: string,
  providerId: string,
  ids: { malId?: unknown; anilistId?: unknown } = {},
): ContentIdentity {
  const malId = positiveInt(ids.malId);
  const anilistId = positiveInt(ids.anilistId);
  const normalizedProvider = providerName.trim().toLowerCase() || 'provider';
  const normalizedProviderId = providerId.trim();

  return {
    canonicalId: malId != null
      ? `mal:${malId}`
      : anilistId != null
        ? `anilist:${anilistId}`
        : `${normalizedProvider}:${normalizedProviderId}`,
    malId,
    anilistId,
    providerId: normalizedProviderId,
    providerName: normalizedProvider,
  };
}

export function identityFromExternalId(externalId: string): ContentIdentity {
  const value = externalId.trim();
  const numeric = Number(value);
  if (/^\d+$/.test(value) && positiveInt(numeric) != null) {
    return identityFromProvider('jikan', value, { malId: numeric });
  }
  if (/^-\d+$/.test(value) && positiveInt(Math.abs(numeric)) != null) {
    return identityFromProvider('anilist', String(Math.abs(numeric)), { anilistId: Math.abs(numeric) });
  }
  const separator = value.indexOf(':');
  if (separator > 0) {
    const provider = value.slice(0, separator);
    const providerId = value.slice(separator + 1);
    const ids = provider === 'mal' ? { malId: providerId } : provider === 'anilist' ? { anilistId: providerId } : {};
    return identityFromProvider(provider, providerId, ids);
  }
  return identityFromProvider('provider', value);
}

export function playbackMalId(identity: Pick<ContentIdentity, 'malId'>): number | null {
  return positiveInt(identity.malId);
}
