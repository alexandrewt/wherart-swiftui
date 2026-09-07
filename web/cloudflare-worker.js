// Front for wherart.com's Universal Link support. Handles the two things a
// bare Supabase custom domain can't: serving a static file at the mandatory
// /.well-known/apple-app-site-association root path, and giving /e/{id}
// links a clean, brandable URL that proxies to the Supabase Edge Function.
//
// Deploy (free tier is enough):
//   1. Add wherart.com to a Cloudflare account (Websites > Add a site) and
//      switch its nameservers to Cloudflare's at your registrar.
//   2. Workers & Pages > Create Worker, paste this file, deploy.
//   3. Worker > Settings > Triggers > Add route: wherart.com/* (and
//      www.wherart.com/* if used).
//
// Everything else on wherart.com (the marketing site, wherever it's
// actually hosted) still needs its own route/origin — this worker only
// needs to own the two paths below; let unmatched requests fall through
// to your existing site by replacing the final `fetch(request)` with a
// fetch to your real origin if Cloudflare isn't already your DNS/proxy
// for the rest of the domain.

const AASA_JSON = {
  applinks: {
    apps: [],
    details: [
      {
        appID: "GHAUCX2368.com.alexandrewt.wherart",
        paths: ["/e/*", "/reset-password", "/reset-password*"],
      },
    ],
  },
};

const SHARE_FUNCTION_BASE =
  "https://etfarydonmbkuxdharjl.supabase.co/functions/v1/share-exhibition";

const APP_STORE_URL = "https://apps.apple.com/app/id6768729154";

// Normally reached only when the app ISN'T installed — with the app
// installed, the Universal Link opens it directly and this worker is never
// hit at all (see WherartApp's application(_:continue:restorationHandler:)).
// But Universal Link resolution isn't 100% reliable even with the app
// installed (a long-press, or Safari having previously "remembered" to
// open this domain in-browser can both skip it) — so as a last-ditch,
// best-effort second attempt, this also tries the wherart:// custom scheme
// (still registered and handled in application(_:open:)) before settling
// on the App Store after a short delay. If the scheme attempt succeeds the
// redirect timer keeps running backgrounded in Safari and can still fire
// later — a known minor quirk of this pattern, not worth the complexity to
// fully suppress.
const RESET_PASSWORD_FALLBACK_HTML = `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Wherart</title>
<style>
  body { font-family: -apple-system, sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; background: #fafafa; color: #111; text-align: center; }
  a { color: #2563eb; text-decoration: none; font-weight: 600; }
</style>
</head>
<body>
  <div>
    <p>Redirecting to Wherart...</p>
    <p><a href="${APP_STORE_URL}">If not redirected, open in the App Store</a></p>
  </div>
  <script>
    // Forward the query string as-is — the Supabase email template links
    // here with ?token_hash=...&type=recovery, not the older PKCE
    // ?code=... shape this used to special-case. Passing it through
    // verbatim means this doesn't need updating again if the link shape
    // ever changes.
    const deepLink = 'wherart://reset-password' + window.location.search;
    window.location = deepLink;
    setTimeout(() => {
      window.location = '${APP_STORE_URL}';
    }, 1000);
  </script>
</body>
</html>`;

export default {
  async fetch(request) {
    const url = new URL(request.url);

    if (url.pathname === "/.well-known/apple-app-site-association") {
      return new Response(JSON.stringify(AASA_JSON), {
        headers: { "content-type": "application/json" },
      });
    }

    if (url.pathname.startsWith("/e/")) {
      const id = url.pathname.slice("/e/".length);
      return fetch(`${SHARE_FUNCTION_BASE}/${encodeURIComponent(id)}`);
    }

    if (url.pathname === "/reset-password") {
      return new Response(RESET_PASSWORD_FALLBACK_HTML, {
        headers: { "content-type": "text/html; charset=utf-8" },
      });
    }

    // Anything else — pass through to whatever already serves wherart.com.
    return fetch(request);
  },
};
