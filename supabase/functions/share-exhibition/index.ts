// Fallback web page for a shared exhibition link (https://wherart.com/e/{id}).
//
// Universal Links intercept the link at the OS level BEFORE it ever reaches
// this function when the app is installed — iOS opens the app directly
// using the cached apple-app-site-association file, no network round trip
// to here at all. This function only ever runs for someone who does NOT
// have the app: it renders an Open Graph preview (for the rich link
// unfurl in iMessage/WhatsApp/etc.) and redirects to the App Store.
//
// There is no deferred deep link back to this exact exhibition after
// install — that would need a third-party attribution service (Branch,
// AppsFlyer) or App Clips; out of scope here. A fresh install just opens
// normally and the user browses to the exhibition themselves.
//
// Deploy: supabase functions deploy share-exhibition
// Invoked at: https://etfarydonmbkuxdharjl.supabase.co/functions/v1/share-exhibition/{id}
// (proxied at https://wherart.com/e/{id} — see the Cloudflare Worker / host
// rewrite rule that needs to point there).

const SUPABASE_URL = "https://etfarydonmbkuxdharjl.supabase.co";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ??
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV0ZmFyeWRvbm1ia3V4ZGhhcmpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkyNTkxODUsImV4cCI6MjA4NDgzNTE4NX0.Cq8Wwe-BsLnGynHZ6_dd1eeWjO0NGRmH47-b10o9DXc";
const APP_STORE_URL = "https://apps.apple.com/app/id6768729154";

interface ExhibitionRow {
  id: number;
  title: string;
  venue: string;
  image: string | null;
}

function escapeHtml(input: string): string {
  return input
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function renderPage(exhibition: ExhibitionRow | null): string {
  const title = exhibition ? escapeHtml(exhibition.title) : "Wherart";
  const description = exhibition
    ? `${escapeHtml(exhibition.title)} at ${escapeHtml(exhibition.venue)} — discover it on Wherart.`
    : "Discover art exhibitions near you on Wherart.";
  const image = exhibition?.image ? escapeHtml(exhibition.image) : "";

  return `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title} — Wherart</title>
<meta property="og:title" content="${title}">
<meta property="og:description" content="${description}">
${image ? `<meta property="og:image" content="${image}">` : ""}
<meta property="og:type" content="website">
<meta name="twitter:card" content="summary_large_image">
<meta http-equiv="refresh" content="0; url=${APP_STORE_URL}">
<style>
  body { font-family: -apple-system, sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; background: #fafafa; color: #111; text-align: center; }
  a { color: #2563eb; text-decoration: none; font-weight: 600; }
</style>
</head>
<body>
  <div>
    <p>${description}</p>
    <p><a href="${APP_STORE_URL}">Open in the App Store</a></p>
  </div>
</body>
</html>`;
}

Deno.serve(async (req) => {
  const url = new URL(req.url);
  // Path is /functions/v1/share-exhibition/{id} when hit directly, or
  // whatever segment the front proxy forwards as the last path component.
  const segments = url.pathname.split("/").filter(Boolean);
  const idString = segments[segments.length - 1];
  const exhibitionId = Number(idString);

  let exhibition: ExhibitionRow | null = null;
  if (Number.isFinite(exhibitionId)) {
    try {
      const res = await fetch(
        `${SUPABASE_URL}/rest/v1/exhibitions?id=eq.${exhibitionId}&select=id,title,venue,image`,
        {
          headers: {
            apikey: SUPABASE_ANON_KEY,
            Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
          },
        },
      );
      const rows = await res.json();
      exhibition = Array.isArray(rows) && rows.length > 0 ? rows[0] : null;
    } catch (_error) {
      // Fall through with exhibition = null — still render a generic page
      // and redirect to the App Store rather than error out.
    }
  }

  return new Response(renderPage(exhibition), {
    headers: { "content-type": "text/html; charset=utf-8" },
  });
});
