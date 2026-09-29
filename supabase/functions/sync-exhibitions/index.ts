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
  const primary = fold(`${title || ''} ${description || ''}`)
  const secondary = fold(`${venueName || ''} ${address || ''}`)
  return {
    type: classifyField(primary, secondary, TYPE_KEYWORDS),
    venueType: classifyField(primary, secondary, VENUE_KEYWORDS),
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
    duration: '1h30',
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

    const deduplicated = all.filter((e: any, index: number, self: any[]) =>
      index === self.findIndex((t: any) => t.title === e.title && t.venue === e.venue)
    )

    const { error } = await supabase
      .from('exhibitions')
      .upsert(deduplicated, { onConflict: 'title,venue' })

    if (error) throw error

    return new Response(
      `Synced ${deduplicated.length} exhibitions (Paris: ${fromParis.length}, Île-de-France: ${fromIleDeFrance.length})`,
      { status: 200 }
    )

  } catch (err) {
    return new Response(`Error: ${err.message}`, { status: 500 })
  }
})