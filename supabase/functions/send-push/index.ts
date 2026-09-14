// Kilit ekranı / banner push. Uygulama içi bildirim satırı oluşunca
// (eşleşme, mesaj, beğeni, yorum…) burası APNs'e gider.
//
// JWT doğrulaması KAPALI: tetikleyici Supabase jetonu değil, Vault'taki
// paylaşılan sırrı gönderir; fonksiyon sırrı kendisi kontrol eder.
//
// Gizli değerler (Edge Functions → Secrets). Yoksa 200 döner, bildirim
// yine de uygulama içinde durur; kilit ekranı sessiz kalır:
//   APNS_KEY_ID       Apple Developer → Keys → APNs anahtarının kimliği
//   APNS_TEAM_ID      Apple Developer → Membership → Team ID
//   APNS_PRIVATE_KEY  o anahtarın .p8 içeriği (BEGIN/END dahil)
//   APNS_BUNDLE_ID    com.campus.social
//
// SUPABASE_URL ve SUPABASE_SERVICE_ROLE_KEY ortamda hazır gelir.

import { createClient } from "jsr:@supabase/supabase-js@2";

const PRODUCTION = "https://api.push.apple.com";
const SANDBOX = "https://api.sandbox.push.apple.com";

function pemToPkcs8(pem: string): Uint8Array {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const binary = atob(body);
  return Uint8Array.from(binary, (c) => c.charCodeAt(0));
}

function base64url(bytes: Uint8Array): string {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function apnsJWT(): Promise<string | null> {
  const keyID = Deno.env.get("APNS_KEY_ID");
  const teamID = Deno.env.get("APNS_TEAM_ID");
  const privateKey = Deno.env.get("APNS_PRIVATE_KEY");
  if (!keyID || !teamID || !privateKey) return null;

  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "ES256", kid: keyID };
  const payload = { iss: teamID, iat: now };
  const encoder = new TextEncoder();
  const signingInput =
    base64url(encoder.encode(JSON.stringify(header))) + "." +
    base64url(encoder.encode(JSON.stringify(payload)));

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToPkcs8(privateKey),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    encoder.encode(signingInput),
  );
  return signingInput + "." + base64url(new Uint8Array(signature));
}

type NotificationRecord = {
  id?: string;
  user_id?: string;
  title?: string;
  body?: string;
  kind?: string;
};

function recordFromBody(payload: Record<string, unknown>): NotificationRecord | null {
  const nested = payload.record;
  if (nested && typeof nested === "object") {
    return nested as NotificationRecord;
  }
  if (typeof payload.user_id === "string") {
    return payload as NotificationRecord;
  }
  return null;
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const supabaseURL = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const token = (request.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  // Paylaşılan sır Vault'ta (push_webhook_secret); env'de varsa o da geçer.
  // Tetikleyici bu sırla çağırıyor; sırrı elle kopyalamak gerekmiyor.
  let webhookSecret = Deno.env.get("PUSH_WEBHOOK_SECRET") ?? "";
  if (!webhookSecret && serviceKey) {
    const vault = createClient(supabaseURL, serviceKey);
    const { data } = await vault.rpc("push_webhook_secret");
    if (typeof data === "string") webhookSecret = data;
  }
  if (!serviceKey || (token !== serviceKey && !(webhookSecret && token === webhookSecret))) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  let payload: Record<string, unknown>;
  try {
    payload = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "bad_request" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const record = recordFromBody(payload);
  const userID = record?.user_id;
  const title = String(record?.title ?? "").trim();
  if (!userID || !title) {
    return new Response(JSON.stringify({ skipped: true, reason: "no_record" }), {
      headers: { "Content-Type": "application/json" },
    });
  }

  const jwt = await apnsJWT();
  if (!jwt) {
    return new Response(JSON.stringify({ skipped: true, reason: "apns_unconfigured" }), {
      headers: { "Content-Type": "application/json" },
    });
  }

  const admin = createClient(supabaseURL, serviceKey);
  const { data: tokens, error: tokenError } = await admin
    .from("device_tokens")
    .select("token")
    .eq("user_id", userID)
    .eq("platform", "ios");
  if (tokenError) {
    console.error("device_tokens", tokenError);
    return new Response(JSON.stringify({ error: "tokens_failed" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
  if (!tokens?.length) {
    return new Response(JSON.stringify({ skipped: true, reason: "no_tokens" }), {
      headers: { "Content-Type": "application/json" },
    });
  }

  const { count } = await admin
    .from("notifications")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userID)
    .eq("is_read", false);

  const bundleID = Deno.env.get("APNS_BUNDLE_ID") || "com.campus.social";
  const body = {
    aps: {
      alert: { title, body: String(record?.body ?? "") },
      sound: "default",
      badge: count ?? 1,
    },
    kind: record?.kind ?? null,
    notification_id: record?.id ?? null,
  };

  const stale: string[] = [];
  for (const row of tokens) {
    const device = String(row.token ?? "");
    if (!device) continue;
    let delivered = false;
    // Geliştirme build'i sandbox, mağaza build'i production token üretir;
    // hangisi olduğu satırda yazmıyor. Sırayla dene: bir ortam "bu token
    // benim değil" (400 BadDeviceToken / 410) derse ötekine geç. Yalnız iki
    // ortam da reddederse token gerçekten ölüdür ve silinir. Başka bir hata
    // (403 anahtar, 429…) token'ı silmez; loglanır.
    let rejectedEverywhere = true;
    for (const host of [PRODUCTION, SANDBOX]) {
      const response = await fetch(`${host}/3/device/${device}`, {
        method: "POST",
        headers: {
          authorization: `bearer ${jwt}`,
          "apns-topic": bundleID,
          "apns-push-type": "alert",
          "apns-priority": "10",
          "content-type": "application/json",
        },
        body: JSON.stringify(body),
      });
      if (response.ok) {
        delivered = true;
        break;
      }
      const reason = String((await response.json().catch(() => ({})))?.reason ?? "");
      const wrongEnvironment = response.status === 410 ||
        (response.status === 400 && reason === "BadDeviceToken");
      console.error("apns", host === PRODUCTION ? "production" : "sandbox", response.status, reason);
      if (wrongEnvironment) continue;
      rejectedEverywhere = false;
      break;
    }
    if (!delivered && rejectedEverywhere) stale.push(device);
  }

  if (stale.length) {
    await admin.from("device_tokens").delete().in("token", stale).eq("user_id", userID);
  }

  return new Response(JSON.stringify({ ok: true, devices: tokens.length, delivered: tokens.length - stale.length }), {
    headers: { "Content-Type": "application/json" },
  });
});
