import { createClient } from "@supabase/supabase-js";

// Edge Function: Sync exhibitions from Paris Open Data
// Optimized version with batch upsert, improved logging, and error handling

const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

const db = createClient(supabaseUrl, supabaseServiceKey);

// Only Paris Open Data (removed Île-de-France as it returns 0 records)
const PARIS_URL =
  "https://opendata.paris.fr/api/records/1.0/search/?dataset=galeries-musees-salles-expositions&rows=500&fields=nom,geometry,adresse,code_postal,commune,telephone,url,horaires";

// Geocoding fallback (Nominatim)
const geocode = async (address: string): Promise<[number, number] | null> => {
  try {
    const query = encodeURIComponent(address);
    const res = await fetch(
      `https://nominatim.openstreetmap.org/search?format=json&q=${query}`
    );

    const data = await res.json();
    if (data.length > 0) {
      const lat = parseFloat(data[0].lat);
      const lon = parseFloat(data[0].lon);
      return [lat, lon];
    }
  } catch (error) {
    console.error(`[Geocoding Error] ${address}: ${error.message}`);
  }
  return null;
};

// Geocode multiple addresses in parallel
const geocodeParallel = async (
  addresses: string[]
): Promise<Map<string, [number, number]>> => {
  console.log(
    `[Geocoding] Starting batch geocoding for ${addresses.length} addresses`
  );

  const results = await Promise.allSettled(
    addresses.map(async (addr) => {
      const coords = await geocode(addr);
      return { address: addr, coords };
    })
  );

  const coordMap = new Map<string, [number, number]>();
  let successCount = 0;

  results.forEach((result) => {
    if (result.status === "fulfilled" && result.value.coords) {
      coordMap.set(result.value.address, result.value.coords);
      successCount++;
    }
  });

  console.log(
    `[Geocoding] Completed: ${successCount}/${addresses.length} successful`
  );
  return coordMap;
};

// Main sync function
async function syncExhibitions() {
  console.log(`[Sync Started] ${new Date().toISOString()}`);

  try {
    // STEP 1: Fetch from Paris Open Data
    console.log(`[Paris API] Fetching exhibitions...`);

    const parisRes = await fetch(PARIS_URL);
    const parisData = await parisRes.json();

    if (!parisData.records) {
      throw new Error("Invalid response from Paris API");
    }

    console.log(`[Paris API] Retrieved ${parisData.records.length} records`);

    // STEP 2: Transform and enrich exhibitions
    const exhibitions = parisData.records.map((record: any) => {
      const geo = record.geometry?.coordinates;
      const [lng, lat] = geo ? [geo[0], geo[1]] : [null, null];

      return {
        id: record.recordid || `${Date.now()}_${Math.random()}`,
        title: record.fields?.nom || "Unknown",
        venue: record.fields?.commune || "Unknown",
        address: record.fields?.adresse || null,
        postal_code: record.fields?.code_postal || null,
        phone: record.fields?.telephone || null,
        website: record.fields?.url || null,
        hours: record.fields?.horaires || null,
        lat: lat,
        lng: lng,
        source: "paris_open_data",
        synced_at: new Date().toISOString(),
      };
    });

    // STEP 3: Check which exhibitions need geocoding
    const needsGeocode = exhibitions.filter((e) => !e.lat || !e.lng);
    console.log(
      `[Geocoding Check] ${needsGeocode.length}/${exhibitions.length} need geocoding`
    );

    if (needsGeocode.length > 0) {
      // Geocode in parallel
      const addresses = needsGeocode.map(
        (e) => e.address || `${e.title}, ${e.venue}`
      );
      const coordMap = await geocodeParallel(addresses);

      // Apply coordinates to exhibitions
      needsGeocode.forEach((exh) => {
        const key = exh.address || `${exh.title}, ${exh.venue}`;
        const coords = coordMap.get(key);
        if (coords) {
          exh.lat = coords[0];
          exh.lng = coords[1];
        }
      });
    }

    // STEP 4: Batch upsert (OPTIMIZED - single query instead of 250)
    console.log(
      `[Upsert] Preparing to insert/update ${exhibitions.length} exhibitions...`
    );

    const { error: upsertError, data: upsertData } = await db
      .from("exhibitions")
      .upsert(exhibitions, { onConflict: "id" })
      .select();

    if (upsertError) {
      throw new Error(`Upsert failed: ${upsertError.message}`);
    }

    console.log(
      `[Success] Synced ${upsertData?.length || exhibitions.length} exhibitions`
    );

    // STEP 5: Return success response
    return new Response(
      JSON.stringify({
        success: true,
        synced_at: new Date().toISOString(),
        count: exhibitions.length,
        message: `Successfully synced ${exhibitions.length} exhibitions`,
      }),
      {
        headers: { "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    console.error(`[Critical Error] Sync failed: ${error.message}`);

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
        timestamp: new Date().toISOString(),
      }),
      {
        headers: { "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
}

// Handle HTTP request
Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  return await syncExhibitions();
});
