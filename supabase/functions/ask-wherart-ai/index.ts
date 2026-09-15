// Wherart AI Assistant — conversational exhibition search & recommendations.
//
// Called from AIAssistantSheet (iOS) via the Supabase Swift SDK's
// `client.functions.invoke`, which already attaches the caller's JWT (or the
// anon key for a guest), so this function relies on the default
// `verify_jwt = true` behavior — no custom auth check needed here.
//
// The client sends an already-trimmed, already-distance-sorted exhibition
// list (see HomeView's `exhibitions` state, reused by AIAssistantSheet) —
// this function does not query Postgres itself, to keep the request small
// and avoid a second round trip.
//
// Deploy: supabase functions deploy ask-wherart-ai
// Requires the ANTHROPIC_API_KEY secret:
//   supabase secrets set ANTHROPIC_API_KEY=sk-ant-... --project-ref etfarydonmbkuxdharjl

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY") ?? "";
const ANTHROPIC_MODEL = "claude-haiku-4-5-20251001";
const MAX_EXHIBITIONS_IN_PROMPT = 60;
const MAX_MESSAGE_LENGTH = 1000;

interface ExhibitionSummary {
  id: number;
  title: string;
  artist: string;
  venue: string;
  venueType: string;
  type: string;
  address: string;
  schedule: string | null;
  price: string | null;
  isFree: boolean;
  endDate: string | null;
  distance: number | null;
}

interface RequestBody {
  userMessage: string;
  userPreferences?: { genres: string[]; venues: string[] };
  userFavoriteIds?: number[];
  userViewedIds?: number[];
  exhibitions?: ExhibitionSummary[];
}

function corsHeaders(): HeadersInit {
  return { "Content-Type": "application/json" };
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders() });
}

function buildSystemPrompt(body: RequestBody): string {
  const prefs = body.userPreferences;
  const exhibitions = (body.exhibitions ?? []).slice(0, MAX_EXHIBITIONS_IN_PROMPT);

  const userContext = `
User's favorite art genres: ${prefs?.genres?.length ? prefs.genres.join(", ") : "none set"}
User's preferred venue types: ${prefs?.venues?.length ? prefs.venues.join(", ") : "none set"}
Number of exhibitions the user already favorited: ${body.userFavoriteIds?.length ?? 0}
Number of exhibitions the user already viewed: ${body.userViewedIds?.length ?? 0}

Exhibitions currently available (closest to the user first, distance in km):
${JSON.stringify(exhibitions, null, 2)}
`.trim();

  return `You are Wherart AI, a specialized assistant for discovering art exhibitions in and around Paris, inside the Wherart app.

Your expertise:
1. Find exhibitions matching what the user describes (keywords, artist, medium, neighborhood, budget, schedule).
2. Recommend exhibitions based on the user's taste profile and viewing history.
3. Help plan a group visit (accessible, easy-to-reach venues; practical logistics).
4. Give practical info (opening hours, distance, price, accessibility) drawn only from the data below.

Rules:
- Detect the language the user writes in and always reply in that same language.
- Only recommend exhibitions from the list below — never invent one, and never invent an id.
- When you have relevant matches, suggest 2-4 exhibitions, each with a one-line reason it matches the request.
- For group-visit requests, favor exhibitions with good accessibility and shorter distances.
- If nothing in the list matches, say so honestly in "message" and return an empty "exhibitions" array rather than forcing a suggestion.
- Politely redirect any question unrelated to Paris art exhibitions back to what you can help with, with an empty "exhibitions" array.
- Keep "message" concise — a few short sentences, not an essay.

Response format — respond with ONLY a single JSON object, no markdown code fences and no other text, matching exactly this shape:
{
  "message": "Natural language reply, in the user's language",
  "exhibitions": [
    { "id": 123, "title": "Exhibition title", "artist": "Artist name", "reason": "One-line reason this matches" }
  ]
}
Omit "exhibitions" or use an empty array when you have no suggestion. Every "id" must be one of the ids in the exhibitions list below.

${userContext}`;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse({ success: false, error: "Method not allowed" }, 405);
  }

  if (!ANTHROPIC_API_KEY) {
    return jsonResponse({ success: false, error: "AI assistant is not configured" }, 500);
  }

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ success: false, error: "Invalid JSON body" }, 400);
  }

  const userMessage = (body.userMessage ?? "").trim();
  if (!userMessage) {
    return jsonResponse({ success: false, error: "userMessage is required" }, 400);
  }
  if (userMessage.length > MAX_MESSAGE_LENGTH) {
    return jsonResponse({ success: false, error: "Message too long" }, 400);
  }

  try {
    const anthropicResponse = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: ANTHROPIC_MODEL,
        max_tokens: 2500,
        system: buildSystemPrompt(body),
        messages: [{ role: "user", content: userMessage }],
      }),
    });

    if (!anthropicResponse.ok) {
      const errorText = await anthropicResponse.text();
      console.error(`[ask-wherart-ai] Anthropic API error ${anthropicResponse.status}: ${errorText}`);
      return jsonResponse({ success: false, error: "AI request failed" }, 502);
    }

    const data = await anthropicResponse.json();
    const responseText = data.content?.find((block: { type: string }) => block.type === "text")?.text ?? "";

    return jsonResponse({
      success: true,
      response: responseText,
      usage: {
        inputTokens: data.usage?.input_tokens ?? 0,
        outputTokens: data.usage?.output_tokens ?? 0,
      },
    });
  } catch (error) {
    console.error("[ask-wherart-ai] Unexpected error:", error);
    return jsonResponse({ success: false, error: "Internal error" }, 500);
  }
});
