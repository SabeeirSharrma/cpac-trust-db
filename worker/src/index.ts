export interface Env {
  SUPABASE_URL: string;
  SUPABASE_ANON_KEY: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    // Strip the proxy prefix: /cpac-trust-db/api/... → /rest/v1/...
    const prefix = "/cpac-trust-db/api";
    let supabasePath = url.pathname;

    if (supabasePath.startsWith(prefix)) {
      supabasePath = "/rest/v1" + supabasePath.slice(prefix.length);
    } else {
      return json({ error: "Not found" }, 404);
    }

    // Build Supabase request URL, forwarding query params
    const supabaseUrl = new URL(supabasePath, env.SUPABASE_URL);
    url.searchParams.forEach((v, k) => supabaseUrl.searchParams.set(k, v));

    // Forward headers
    const headers = new Headers();
    headers.set("apikey", env.SUPABASE_ANON_KEY);
    headers.set("Authorization", `Bearer ${env.SUPABASE_ANON_KEY}`);
    headers.set("Content-Type", "application/json");

    // Forward client token for rate limiting on writes
    const clientToken = request.headers.get("X-Client-Token");
    if (clientToken) {
      headers.set("X-Client-Token", clientToken);
    }

    try {
      const res = await fetch(supabaseUrl.toString(), {
        method: request.method,
        headers,
        body: request.method !== "GET" && request.method !== "HEAD"
          ? await request.text()
          : undefined,
      });

      // Return Supabase response directly
      return new Response(res.body, {
        status: res.status,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Token",
        },
      });
    } catch (e) {
      return json({ error: "Upstream error", detail: String(e) }, 502);
    }
  },
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
  });
}
