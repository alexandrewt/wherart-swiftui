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
        paths: ["/e/*", "/reset-password"],
      },
    ],
  },
};

const SHARE_FUNCTION_BASE =
  "https://etfarydonmbkuxdharjl.supabase.co/functions/v1/share-exhibition";

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

    // Anything else — pass through to whatever already serves wherart.com.
    return fetch(request);
  },
};
