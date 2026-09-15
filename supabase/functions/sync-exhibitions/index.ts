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

  return {
    title: normalizeText(event.title_event || event.title || ''),
    artist: '',
    venue: normalizeText(event.address_name || ''),
    venue_type: 'Museums',
    type: 'Contemporary Art',
    address: `${event.address_street || ''}, ${event.address_zipcode || ''} ${event.address_city || ''}`.trim(),
    schedule: event.date_description?.replace(/<[^>]*>/g, '').trim() || '',
    description: event.lead_text || '',
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