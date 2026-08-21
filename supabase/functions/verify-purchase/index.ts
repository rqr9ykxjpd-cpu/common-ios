// Satın alma doğrulama.
//
// İstemci "ben Pro oldum" diyemez: uygulamayı kurcalayan biri o çağrıyı da
// yapardı. Buraya yalnızca Apple'ın imzaladığı işlem belgesi (JWS) geliyor ve
// belgeye de doğrudan güvenilmiyor — içindeki işlem numarasıyla Apple'ın App
// Store Server API'sine sorup cevabı oradan alıyoruz. Kademeyi yazan tek yer
// burası; `subscriptions` tablosunda hiçbir kullanıcının yazma yetkisi yok.
//
// Gereken gizli değerler (Supabase → Edge Functions → Secrets):
//   APPLE_ISSUER_ID    App Store Connect → Users and Access → Integrations
//   APPLE_KEY_ID       aynı yerde oluşturulan In-App Purchase anahtarının kimliği
//   APPLE_PRIVATE_KEY  o anahtarın .p8 dosyasının içeriği (BEGIN/END satırları dahil)
//   APPLE_BUNDLE_ID    com.campus.social
//
// SUPABASE_URL ve SUPABASE_SERVICE_ROLE_KEY ortamda hazır geliyor.

import { createClient } from "jsr:@supabase/supabase-js@2";

const PLAN_BY_PRODUCT: Record<string, string> = {
  "com.campus.social.plus.weekly": "plus",
  "com.campus.social.pro.weekly": "pro",
};

const APPLE_PRODUCTION = "https://api.storekit.itunes.apple.com";
const APPLE_SANDBOX = "https://api.storekit-sandbox.itunes.apple.com";

/** JWS'in orta parçasını okur. Buna güvenmiyoruz; yalnızca işlem numarasını
 *  öğrenip Apple'a sormak için. Doğruluk kararı Apple'ın cevabına dayanıyor. */
function decodeJWSPayload(jws: string): Record<string, unknown> {
  const parts = jws.split(".");
  if (parts.length !== 3) throw new Error("Malformed JWS");
  const padded = parts[1].replace(/-/g, "+").replace(/_/g, "/");
  const json = atob(padded + "=".repeat((4 - (padded.length % 4)) % 4));
  return JSON.parse(json);
}

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

/** App Store Server API'nin istediği ES256 JWT. Harici kütüphane yok:
 *  bağımlılık ne kadar azsa dağıtım o kadar az yerde kırılıyor. */
async function appleToken(): Promise<string> {
  const issuer = Deno.env.get("APPLE_ISSUER_ID");
  const keyID = Deno.env.get("APPLE_KEY_ID");
  const privateKey = Deno.env.get("APPLE_PRIVATE_KEY");
  const bundleID = Deno.env.get("APPLE_BUNDLE_ID");
  if (!issuer || !keyID || !privateKey || !bundleID) {
    throw new Error("Apple credentials are not configured");
  }

  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "ES256", kid: keyID, typ: "JWT" };
  const payload = {
    iss: issuer,
    iat: now,
    exp: now + 600,
    aud: "appstoreconnect-v1",
    bid: bundleID,
  };

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

/** Önce üretim, sonra sandbox. Apple'ın kendi tavsiyesi bu sıra: inceleme
 *  ekibi ve TestFlight sandbox'ta, gerçek kullanıcılar üretimde. */
async function fetchSubscriptionStatus(transactionID: string, token: string) {
  for (const host of [APPLE_PRODUCTION, APPLE_SANDBOX]) {
    const response = await fetch(
      `${host}/inApps/v1/subscriptions/${transactionID}`,
      { headers: { Authorization: `Bearer ${token}` } },
    );
    if (response.ok) return await response.json();
    // 404: bu ortamda yok, diğerine bak. Başka hata gerçek bir arıza.
    if (response.status !== 404) {
      throw new Error(`Apple responded ${response.status}`);
    }
  }
  throw new Error("Transaction not found in either environment");
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const supabaseURL = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const authHeader = request.headers.get("Authorization") ?? "";

  // Kimin adına yazdığımızı istemcinin gönderdiği bir kimlikten değil,
  // oturum jetonundan öğreniyoruz. Aksi halde herkes başkasının hesabına
  // abonelik yazabilirdi.
  const asUser = createClient(supabaseURL, serviceKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await asUser.auth.getUser();
  if (userError || !userData?.user) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }
  const userID = userData.user.id;

  let jws: string;
  try {
    const body = await request.json();
    jws = String(body.jws ?? "");
    if (!jws) throw new Error("missing jws");
  } catch {
    return new Response(JSON.stringify({ error: "bad_request" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const claimed = decodeJWSPayload(jws);
    const transactionID = String(claimed.transactionId ?? "");
    if (!transactionID) throw new Error("missing transactionId");

    const token = await appleToken();
    const status = await fetchSubscriptionStatus(transactionID, token);

    // Apple'ın cevabındaki imzalı işlem, tek gerçek kaynak. İstemcinin
    // gönderdiği productId'ye bakmıyoruz.
    let plan = "free";
    let expiresAt: string | null = null;
    let originalTransactionID: string | null = null;
    let productID: string | null = null;

    for (const group of status.data ?? []) {
      for (const item of group.lastTransactions ?? []) {
        // 1 = etkin, 4 = ödeme sorunu ama hâlâ hak sahibi (grace period).
        if (item.status !== 1 && item.status !== 4) continue;
        const info = decodeJWSPayload(item.signedTransactionInfo);
        if (info.bundleId !== Deno.env.get("APPLE_BUNDLE_ID")) continue;
        const aday = PLAN_BY_PRODUCT[String(info.productId)];
        if (!aday) continue;
        const bitis = typeof info.expiresDate === "number" ? info.expiresDate : 0;
        if (bitis && bitis <= Date.now()) continue;
        // En yüksek kademe kazanır: Plus'tan Pro'ya geçişte ikisi de bir süre
        // etkin görünebiliyor.
        if (plan === "free" || (plan === "plus" && aday === "pro")) {
          plan = aday;
          productID = String(info.productId);
          originalTransactionID = String(info.originalTransactionId ?? "");
          expiresAt = bitis ? new Date(bitis).toISOString() : null;
        }
      }
    }

    const admin = createClient(supabaseURL, serviceKey);
    const { error } = await admin.rpc("set_plan", {
      account: userID,
      new_plan: plan,
      original_transaction: originalTransactionID,
      product: productID,
      expires: expiresAt,
    });
    if (error) throw new Error(error.message);

    return new Response(JSON.stringify({ plan, expires_at: expiresAt }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("verify-purchase failed", error);
    return new Response(JSON.stringify({ error: "verification_failed" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }
});
