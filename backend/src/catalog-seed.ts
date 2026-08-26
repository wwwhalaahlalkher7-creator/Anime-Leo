import type { AnimeProvider, AnimeRecord } from './types';
import { upsertAnime } from './catalog';

/**
 * Small, curated bootstrap set. We intentionally use stable MAL IDs and the
 * Jikan details endpoint rather than Jikan search/top, because search/top can
 * fail independently when MyAnimeList is unavailable.
 */
export const CATALOG_SEED_IDS = [
  20,     // Naruto
  21,     // One Piece
  1535,   // Death Note
  1575,   // Code Geass
  1735,   // Naruto: Shippuden
  269,    // Bleach
  223,    // Dragon Ball
  5114,   // Fullmetal Alchemist: Brotherhood
  9253,   // Steins;Gate
  11061,  // Hunter x Hunter (2011)
  16498,  // Attack on Titan
  20583,  // Haikyuu!!
  2904,   // Code Geass R2
  30276,  // One Punch Man
  31964,  // My Hero Academia
  32281,  // Your Name
  33352,  // Violet Evergarden
  34572,  // Black Clover
  37521,  // Vinland Saga
  38000,  // Demon Slayer
  38691,  // Dr. Stone
  40748,  // Jujutsu Kaisen
  44511,  // Chainsaw Man
  50265,  // Spy x Family
  52299,  // Solo Leveling
  52991,  // Frieren: Beyond Journey's End
  1,      // Cowboy Bebop
  6,      // Trigun
  19,     // Monster
  30,     // Neon Genesis Evangelion
  33,     // Berserk
  45,     // Rurouni Kenshin
  47,     // Akira
  48,     // Nana
  57,     // Beck
  64,     // Bokura ga Ita
  71,     // Full Metal Panic!
  101,    // Air
  199,    // Spirited Away
  226,    // Elfen Lied
  263,    // Hajime no Ippo
  392,    // Yu Yu Hakusho
  777,    // Hellsing
  934,    // Higurashi no Naku Koro ni
  10620,  // Mirai Nikki
  11757,  // Sword Art Online
  13601,  // Psycho-Pass
  20507,  // Noragami
  22535,  // Kiseijuu: Sei no Kakuritsu
  23755,  // Nanatsu no Taizai
  31043,  // Boku dake ga Inai Machi
  31646,  // 3-gatsu no Lion
  31933,  // New Game!
  34599,  // Made in Abyss
  37450,  // Seishun Buta Yarou
  38680,  // Fruits Basket (2019)
  39617,  // Yakusoku no Neverland 2nd Season
  40028,  // Shingeki no Kyojin: The Final Season
  42310,  // Cyberpunk: Edgerunners
  44042,  // Ijiranaide, Nagatoro-san
  44511,  // Chainsaw Man
  48569,  // 86 Part 2
  49596,  // Blue Lock
  51009,  // Jujutsu Kaisen Season 2
  54898,  // Dungeon Meshi
] as const;

export interface SeedItemResult {
  externalId: string;
  status: 'inserted_or_updated' | 'not_found' | 'failed';
  title?: string;
  error?: string;
}

export interface SeedResult {
  offset: number;
  requested: number;
  nextOffset: number | null;
  total: number;
  items: SeedItemResult[];
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export async function seedCatalog(
  db: D1Database,
  provider: AnimeProvider,
  offset: number,
  limit: number,
): Promise<SeedResult> {
  const ids = CATALOG_SEED_IDS.slice(offset, offset + limit);
  const items: SeedItemResult[] = [];

  // Keep requests deliberately conservative for Jikan's public service.
  for (let index = 0; index < ids.length; index += 1) {
    const externalId = String(ids[index]);
    try {
      const record: AnimeRecord | null = await provider.details(externalId);
      if (!record) {
        items.push({ externalId, status: 'not_found' });
      } else {
        await upsertAnime(db, record);
        items.push({
          externalId,
          status: 'inserted_or_updated',
          title: record.title,
        });
      }
    } catch (error) {
      items.push({
        externalId,
        status: 'failed',
        error: error instanceof Error ? error.message.slice(0, 120) : 'unknown_error',
      });
    }

    if (index < ids.length - 1) await sleep(400);
  }

  const nextOffset = offset + ids.length < CATALOG_SEED_IDS.length
    ? offset + ids.length
    : null;

  return {
    offset,
    requested: ids.length,
    nextOffset,
    total: CATALOG_SEED_IDS.length,
    items,
  };
}
