// Supabase Edge Function: send-push
// Uses Firebase Admin SDK service account + FCM v1 API (modern, recommended)
// Deploy:  supabase functions deploy send-push
// Secrets: see supabase/secrets.sh — run it once after deploying

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

// ─── JWT / OAuth helpers (Web Crypto — works in Deno/Edge runtime) ────────────

function b64url(buf: Uint8Array): string {
  return btoa(String.fromCharCode(...buf))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
}

function encodeB64url(str: string): string {
  return b64url(new TextEncoder().encode(str));
}

async function signRS256(data: string, pemKey: string): Promise<string> {
  const pem = pemKey
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8", der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false, ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5", key,
    new TextEncoder().encode(data),
  );
  return b64url(new Uint8Array(sig));
}

async function getAccessToken(clientEmail: string, privateKey: string): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header  = encodeB64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const payload = encodeB64url(JSON.stringify({
    iss:   clientEmail,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud:   "https://oauth2.googleapis.com/token",
    iat:   now,
    exp:   now + 3600,
  }));
  const sig = await signRS256(`${header}.${payload}`, privateKey);
  const jwt = `${header}.${payload}.${sig}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion:  jwt,
    }),
  });
  const json = await res.json();
  if (!json.access_token) {
    throw new Error(`OAuth2 failed: ${JSON.stringify(json)}`);
  }
  return json.access_token as string;
}

// ─── FCM v1 send (one message per token — v1 doesn't support multicast) ────────

async function sendOne(
  projectId: string,
  accessToken: string,
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<unknown> {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization:  `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          data,
          android: {
            priority: "high",
            notification: {
              channel_id:  "store_high_channel",
              sound:       "default",
              priority:    "max",
              visibility:  "public",
            },
          },
          apns: {
            headers: { "apns-priority": "10" },
            payload: { aps: { sound: "default", badge: 1 } },
          },
        },
      }),
    },
  );
  return res.json();
}

// ─── Main handler ─────────────────────────────────────────────────────────────

const CORS = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  try {
    const projectId   = Deno.env.get("FCM_PROJECT_ID")!;
    const clientEmail = Deno.env.get("FCM_CLIENT_EMAIL")!;
    // Secret stored with literal \n — convert back to real newlines
    const privateKey  = Deno.env.get("FCM_PRIVATE_KEY")!.replace(/\\n/g, "\n");

    if (!projectId || !clientEmail || !privateKey) {
      return new Response(
        JSON.stringify({ error: "FCM secrets not configured" }),
        { status: 500, headers: { ...CORS, "Content-Type": "application/json" } },
      );
    }

    const { tokens, token, title, body, data } = await req.json();
    const recipients: string[] = tokens ?? (token ? [token] : []);

    if (recipients.length === 0) {
      return new Response(
        JSON.stringify({ error: "No device tokens provided" }),
        { status: 400, headers: { ...CORS, "Content-Type": "application/json" } },
      );
    }

    const accessToken = await getAccessToken(clientEmail, privateKey);

    const results = await Promise.allSettled(
      recipients.map((t) =>
        sendOne(projectId, accessToken, t, title, body, data ?? {})
      ),
    );

    const summary = results.map((r, i) => ({
      token: recipients[i].slice(-8),
      status: r.status,
      value: r.status === "fulfilled" ? r.value : String((r as PromiseRejectedResult).reason),
    }));

    return new Response(
      JSON.stringify({ ok: true, sent: recipients.length, summary }),
      { headers: { ...CORS, "Content-Type": "application/json" } },
    );

  } catch (err) {
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...CORS, "Content-Type": "application/json" } },
    );
  }
});
