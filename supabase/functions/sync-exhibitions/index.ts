import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

const geocode = async (address: string): Promise<{ lat: number, lng: number } | null> => {
  try {
    const res = await fetch(
      `https://api-adresse.data.gouv.fr/search/?q=${encodeURIComponent(address)}&limit=1`
    )
    const data = await res.json()
    if (data.features?.[0]) {
      const [lng, lat] = data.features[0].geometry.coordinates
      return { lat, lng }
    }
    return null
  } catch {
    return null
  }
}

// Collapses runs of whitespace (including non-breaking / narrow no-break
// spaces that Paris Open Data intermittently inserts before punctuation)
// into a single regular space, and trims. Without this, the same exhibition
// synced on different days can carry a byte-different title/venue and slip
// past the upsert(onConflict: 'title,venue') dedup, creating a duplicate row.
const normalizeText = (s: string): string => s.replace(/\s+/gu, ' ').trim()

// MARK: - Type / Venue-Type Classification
//
// Paris Open Data never provides an art-medium or venue-category field, so
// every event used to be synced with hardcoded generic defaults
// ('Contemporary Art' / 'Museums' — the latter later renamed singular,
// see the note below). This keyword-matches title+description
// (primary) then venue+address (secondary, "si besoin") against ordered
// tables — first matching entry wins (priority = table order) — and falls
// back to '' (not SQL null: the Swift client's `Exhibition.type`/
// `venueType` are non-optional Strings, and this column is nullable, so a
// real NULL would throw a DecodingError on every fetch and blank the whole
// feed for every user; '' is treated client-side as "no tag" and always
// passes type/venue filters instead).
//
// 'Contemporary Art' (type) still has no keyword entry (matches the spec:
// no match => unclassified) so it can never be produced going forward.
// 'Museum'/'Gallery' (venue_type) DO have entries now — added after venues
// like "Musée de la Chasse" kept showing up unclassified — and are renamed
// singular to match every other type/venue_type value, which were already
// singular English nouns ('Painting', 'Library', ...); the old 'Museums'/
// 'Galleries' plurals were the odd ones out.
//
// "Public Space"'s keyword list dropped "rue" (present in the original
// spec): ~62% of all synced addresses contain "rue" as part of the street
// name, which would have made "Public Space" a false-positive dump for
// most venue-only-matched exhibitions.

const TYPE_KEYWORDS: [string, string[]][] = [
  ["Painting", ["peinture", "tableau", "toile", "peintre", "huile", "acrylique", "tempera", "figuratif", "portrait", "paysage", "nature morte"]],
  ["Photography", ["photographie", "photo", "photographe", "cliche", "negatif", "tirage", "polaroid"]],
  ["Sculpture", ["sculpture", "sculpteur", "bronze", "marbre", "pierre", "statue", "bas-relief", "relief"]],
  ["Drawing", ["dessin", "crayon", "encre", "graphite", "charbon", "fusain", "mine"]],
  ["Video Art", ["video", "film", "cinema", "projection", "ecran", "multimedia video"]],
  ["Street Art", ["street art", "graffiti", "murale", "urbain", "pochoir", "tag"]],
  ["Design", ["design", "mobilier", "objet", "produit", "industriel", "graphique"]],
  ["Architecture", ["architecture", "architectural", "batiment", "structure", "urbanisme", "facade", "amenagement"]],
  ["Digital Art", ["digital", "numerique", "code", "pixels", "synthese", "infographie"]],
  ["Illustration", ["illustration", "illustrateur", "bande dessinee", "bd", "comics", "planches"]],
  ["Printmaking", ["gravure", "estampe", "lithographie", "serigraphie", "eau-forte"]],
  ["Abstract Art", ["abstrait", "abstraction", "non-figuratif", "geometrique", "composition"]],
  ["Modern Art", ["moderne", "modernisme", "art moderne", "cubisme", "dadaisme", "surrealisme"]],
  ["Asian Art", ["asiatique", "chinois", "japonais", "indien", "thai", "bouddhiste", "oriental"]],
  ["Installation", ["installation", "immersif", "environnement", "site-specific", "participatif"]],
  ["Mixed Media", ["technique mixte", "collage", "assemblage", "multimedia", "hybride"]],
  ["Textile Art", ["textile", "tissu", "broderie", "tapisserie", "laine", "fil"]],
  ["Ceramics", ["ceramique", "poterie", "porcelaine", "gres", "email"]],
  ["Performance", ["performance", "live", "action", "spectacle", "danse", "theatre", "happening"]],
]

const VENUE_KEYWORDS: [string, string[]][] = [
  ["Museum", ["musee", "museum"]],
  ["Gallery", ["galerie", "galerie marchande", "galerie privee"]],
  ["Art Center", ["centre d'art", "centre", "pole"]],
  ["Foundation", ["fondation", "mecene"]],
  ["Cultural Center", ["centre culturel", "espace culturel", "maison"]],
  ["Auction House", ["hotel des ventes", "encheres", "drouot"]],
  ["Art Fair", ["foire", "salon", "fiac", "art expo"]],
  ["Public Space", ["espace public", "place", "parc", "metro", "jardin"]],
  ["Historic Site", ["site historique", "chateau", "palais", "patrimoine", "monument"]],
  ["Library", ["bibliotheque", "mediatheque", "bpi"]],
  ["Church & Heritage", ["eglise", "chapelle", "cathedrale", "abbaye", "temple"]],
  ["Cultural Institute", ["institut", "academie", "athenee", "consulat"]],
  ["Artist Studio", ["atelier", "studio artiste", "maison d'artiste"]],
]

// Duration is never provided by Paris Open Data — derived from the final
// venue_type instead of a flat constant. Values reflect a typical visit
// length for that kind of place, not this specific exhibition.
const DURATION_SHORT_VENUES = new Set(['Gallery', '', 'Public Space', 'Artist Studio', 'Church & Heritage'])
const DURATION_LONG_VENUES = new Set(['Museum', 'Art Center', 'Foundation', 'Cultural Center', 'Art Fair'])
const durationForVenueType = (venueType: string): string => {
  if (DURATION_SHORT_VENUES.has(venueType)) return '30min'
  if (DURATION_LONG_VENUES.has(venueType)) return '1h30'
  return '1h'
}

// Lowercases and strips accents (NFD decompose + drop combining marks) so
// matching is case- and accent-insensitive without a per-keyword regex.
const fold = (s: string): string =>
  s.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase()

const classifyField = (primary: string, secondary: string, table: [string, string[]][]): string => {
  for (const [value, keywords] of table) {
    if (keywords.some((k) => primary.includes(k))) return value
  }
  for (const [value, keywords] of table) {
    if (keywords.some((k) => secondary.includes(k))) return value
  }
  return ''
}

const classifyExhibition = (
  title: string | null | undefined,
  description: string | null | undefined,
  venueName: string | null | undefined,
  address: string | null | undefined
): { type: string; venueType: string } => {
  const titleDesc = fold(`${title || ''} ${description || ''}`)
  const venueAddr = fold(`${venueName || ''} ${address || ''}`)
  return {
    // type describes the exhibition's own content — title/description is
    // the right primary signal, venue/address a weak fallback.
    type: classifyField(titleDesc, venueAddr, TYPE_KEYWORDS),
    // venueType describes the VENUE, not this one exhibition — venue/address
    // must be checked first. Getting this backwards (title/description
    // first) let an exhibition's own blurb ("balades urbaines...") outrank
    // an unambiguous venue name ("Musée d'art contemporain..."), producing
    // a different venueType for exhibitions at the exact same address.
    venueType: classifyField(venueAddr, titleDesc, VENUE_KEYWORDS),
  }
}

const normalizeParisEvent = async (event: any) => {
  let lat = event.lat_lon?.lat || null
  let lng = event.lat_lon?.lon || null

  if (!lat || !lng) {
    const address = `${event.address_street || ''} ${event.address_zipcode || ''} ${event.address_city || 'Paris'}`.trim()
    if (address.length > 5) {
      const coords = await geocode(address)
      if (coords) {
        lat = coords.lat
        lng = coords.lng
      }
    }
  }

  const title = normalizeText(event.title_event || event.title || '')
  const venue = normalizeText(event.address_name || '')
  const address = `${event.address_street || ''}, ${event.address_zipcode || ''} ${event.address_city || ''}`.trim()
  const description = event.lead_text || ''
  const { type, venueType } = classifyExhibition(title, description, venue, address)

  return {
    title,
    artist: '',
    venue,
    venue_type: venueType,
    type,
    address,
    schedule: event.date_description?.replace(/<[^>]*>/g, '').trim() || '',
    description,
    ticket_link: event.access_link || event.contact_url || '',
    image: event.cover_url || '',
    lat,
    lng,
    price: event.price_detail?.replace(/<[^>]*>/g, '').trim() || (event.price_type === 'gratuit' ? 'Free' : ''),
    is_free: event.price_type === 'gratuit',
    duration: '1h', // placeholder — overwritten below once venue_type is finalized (see venueTypeByLocation)
    accessibility: event.pmr === 1 ? 'Wheelchair accessible' : 'See venue website',
    phone: event.contact_phone || '',
    end_date: event.date_end ? new Date(event.date_end).toISOString().split('T')[0] : null,
    ending_soon: false,
  }
}

const fetchParisOpenData = async (): Promise<any[]> => {
  try {
    const allResults: any[] = []
    let offset = 0
    const limit = 100

    while (true) {
      const res = await fetch(
        `https://opendata.paris.fr/api/explore/v2.1/catalog/datasets/que-faire-a-paris-/records?limit=${limit}&offset=${offset}&where=qfap_tags%20like%20%22%25Expo%25%22&order_by=date_start%20desc`
      )
      const data = await res.json()
      const results = data.results || []
      allResults.push(...results)
      if (results.length < limit) break
      offset += limit
    }

    const normalized = await Promise.all(allResults.map(normalizeParisEvent))
    return normalized.filter((e: any) => e.lat && e.lng)
  } catch (err) {
    console.error('Paris Open Data error:', err)
    return []
  }
}

const fetchIleDeFrance = async (): Promise<any[]> => {
  try {
    const res = await fetch(
      `https://data.iledefrance.fr/api/explore/v2.1/catalog/datasets/evenements-en-ile-de-france/records?limit=100&where=tags%20like%20%22%25Expo%25%22&order_by=date_start%20desc`
    )
    const data = await res.json()
    const normalized = await Promise.all((data.results || []).map(normalizeParisEvent))
    return normalized.filter((e: any) => e.lat && e.lng)
  } catch (err) {
    console.error('Ile-de-France error:', err)
    return []
  }
}

// MARK: - Cross-Run Duplicate Cleanup
//
// Same-batch duplicates (two records within ONE sync run) are already
// prevented by the bestByKey dedup above. This closes the remaining gap:
// a future sync spelling an already-existing venue differently again would
// still insert a new row, since the upsert's onConflict key is (title,
// venue) — an exact string match. Runs after every sync, over the WHOLE
// table (not just this run's batch), using the same signal validated
// manually for the one-off cleanup in 20260929000008_remove_exhibition_duplicates.sql:
// same title, same rounded coordinates (~11m), same end_date.
const REFERENCE_TABLES = [
  'user_interactions', 'groups', 'user_exhibition_edits',
  'exhibition_likes', 'exhibition_comments', 'exhibition_reminders',
  'ending_soon_notifications_sent',
]

const dedupeExhibitions = async (supabase: any) => {
  const { data: rows, error: fetchError } = await supabase
    .from('exhibitions')
    .select('id, title, venue, lat, lng, end_date')
  if (fetchError || !rows) {
    console.error('[Dedupe] Failed to fetch exhibitions:', fetchError)
    return
  }

  const groups = new Map<string, any[]>()
  for (const r of rows) {
    if (r.lat == null || r.lng == null) continue
    const key = `${r.title}__${Math.round(r.lat * 10000)}_${Math.round(r.lng * 10000)}__${r.end_date}`
    const group = groups.get(key) ?? []
    group.push(r)
    groups.set(key, group)
  }

  const duplicateGroups = [...groups.values()].filter((g) => g.length > 1)
  if (duplicateGroups.length === 0) return

  const allCandidateIds = duplicateGroups.flatMap((g) => g.map((r) => r.id))

  // A candidate is "referenced" if any real user data points at it — never
  // auto-delete a row someone favorited, visited, commented on, etc.
  const referencedIds = new Set<number>()
  for (const table of REFERENCE_TABLES) {
    const { data } = await supabase.from(table).select('exhibition_id').in('exhibition_id', allCandidateIds)
    for (const row of data ?? []) referencedIds.add(row.exhibition_id)
  }

  // notifications.exhibition_ids is an array column, checked separately —
  // also builds the id->notification-ids map needed to remap survivors.
  const { data: notifRows } = await supabase.from('notifications').select('id, exhibition_ids')
  const notificationsByExhibitionId = new Map<number, string[]>()
  for (const n of notifRows ?? []) {
    for (const eid of n.exhibition_ids ?? []) {
      if (allCandidateIds.includes(eid)) {
        referencedIds.add(eid)
        const list = notificationsByExhibitionId.get(eid) ?? []
        list.push(n.id)
        notificationsByExhibitionId.set(eid, list)
      }
    }
  }

  const idsToDelete: number[] = []
  const remaps: { from: number; to: number }[] = []

  for (const group of duplicateGroups) {
    const withRefs = group.filter((r) => referencedIds.has(r.id))
    let winner: any
    if (withRefs.length === 1) {
      winner = withRefs[0]
    } else if (withRefs.length === 0) {
      // No real data on either side — keep the more complete venue name.
      winner = [...group].sort((a, b) => (b.venue?.length ?? 0) - (a.venue?.length ?? 0) || a.id - b.id)[0]
    } else {
      // 2+ candidates each have real references (e.g. two different users
      // favorited two different copies) — ambiguous, don't auto-resolve.
      console.log('[Dedupe] Skipped ambiguous group (multiple referenced rows):', group.map((r: any) => r.id))
      continue
    }
    for (const r of group) {
      if (r.id === winner.id) continue
      idsToDelete.push(r.id)
      remaps.push({ from: r.id, to: winner.id })
    }
  }

  if (idsToDelete.length === 0) return

  for (const { from, to } of remaps) {
    const notifIds = notificationsByExhibitionId.get(from)
    if (!notifIds) continue
    for (const notifId of notifIds) {
      const notif = (notifRows ?? []).find((n: any) => n.id === notifId)
      if (!notif) continue
      const updated = (notif.exhibition_ids ?? []).map((eid: number) => (eid === from ? to : eid))
      await supabase.from('notifications').update({ exhibition_ids: updated }).eq('id', notifId)
    }
  }

  const { error: deleteError } = await supabase.from('exhibitions').delete().in('id', idsToDelete)
  if (deleteError) {
    console.error('[Dedupe] Failed to delete duplicates:', deleteError)
  } else {
    console.log(`[Dedupe] Removed ${idsToDelete.length} cross-run duplicate(s):`, idsToDelete)
  }
}

Deno.serve(async () => {
  const supabase = createClient(SUPABASE_URL!, SUPABASE_SERVICE_KEY!)

  try {
    const [fromParis, fromIleDeFrance] = await Promise.all([
      fetchParisOpenData(),
      fetchIleDeFrance(),
    ])

    const all = [...fromParis, ...fromIleDeFrance]

    if (all.length === 0) {
      return new Response('No exhibitions found', { status: 200 })
    }

    // Same-batch duplicates: matched by title + rounded coordinates, not
    // title + venue string. Paris Open Data sometimes spells the same venue
    // slightly differently across records for the exact same event (e.g.
    // "Centre Paris Anim' Wangari Maathai" vs. "... Wangari Muta Maathai"),
    // which a venue-string match would let through as two separate rows.
    // When a group has duplicates, keeps the one with the longest venue
    // name (the more complete/accurate spelling in every case checked so
    // far) rather than just the first one encountered.
    const dupKey = (e: any) => `${e.title}__${Math.round(e.lat * 10000)}_${Math.round(e.lng * 10000)}`
    const bestByKey = new Map<string, any>()
    for (const e of all) {
      const key = dupKey(e)
      const existing = bestByKey.get(key)
      if (!existing || (e.venue?.length ?? 0) > (existing.venue?.length ?? 0)) {
        bestByKey.set(key, e)
      }
    }
    // Second pass: the upsert's onConflict target is (title, venue) — if
    // two entries share that exact pair but ended up in different
    // title+coordinate buckets above (e.g. two independent geocoding calls
    // for the same address returning marginally different lat/lng),
    // Postgres refuses the whole upsert ("ON CONFLICT DO UPDATE command
    // cannot affect row a second time"). Collapse those too.
    const seenTitleVenue = new Set<string>()
    const deduplicated = [...bestByKey.values()].filter((e) => {
      const key = `${e.title}__${e.venue}`
      if (seenTitleVenue.has(key)) return false
      seenTitleVenue.add(key)
      return true
    })

    // Same physical venue must always carry the same venue_type. Grouped
    // by rounded coordinates (~11m), not by venue name string: Paris Open
    // Data spells the same place differently across records (e.g. "Mac Val"
    // vs. "MAC VAL - Musée d'art contemporain du Val-de-Marne"), which a
    // name-based grouping would treat as two different venues even though
    // they share the same address. Force every exhibition in this batch to
    // the most common non-empty venue_type among its own coordinate group.
    const coordKey = (e: any): string | null =>
      e.lat != null && e.lng != null
        ? `${Math.round(e.lat * 10000)}_${Math.round(e.lng * 10000)}`
        : null

    const votesByLocation = new Map<string, Map<string, number>>()
    for (const e of deduplicated) {
      const key = coordKey(e)
      if (!key || !e.venue_type) continue
      const votes = votesByLocation.get(key) ?? new Map<string, number>()
      votes.set(e.venue_type, (votes.get(e.venue_type) ?? 0) + 1)
      votesByLocation.set(key, votes)
    }
    const venueTypeByLocation = new Map<string, string>()
    for (const [key, votes] of votesByLocation) {
      const [winner] = [...votes.entries()].sort((a, b) => b[1] - a[1])[0]
      venueTypeByLocation.set(key, winner)
    }
    for (const e of deduplicated) {
      const key = coordKey(e)
      const consistent = key ? venueTypeByLocation.get(key) : undefined
      if (consistent) e.venue_type = consistent
      e.duration = durationForVenueType(e.venue_type)
    }

    const { error } = await supabase
      .from('exhibitions')
      .upsert(deduplicated, { onConflict: 'title,venue' })

    if (error) throw error

    await dedupeExhibitions(supabase)

    return new Response(
      `Synced ${deduplicated.length} exhibitions (Paris: ${fromParis.length}, Île-de-France: ${fromIleDeFrance.length})`,
      { status: 200 }
    )

  } catch (err) {
    return new Response(`Error: ${err.message}`, { status: 500 })
  }
})