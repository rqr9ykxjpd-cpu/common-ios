// RevenueCat webhook alıcısı.
//
// RevenueCat, Apple'ın satın alma/yenileme/iptal/iade bildirimlerini bizim
// yerimize dinliyor ve her değişiklikte buraya bir istek atıyor. Kademeyi
// yazan tek yer burası; `subscriptions` tablosunda hiçbir kullanıcının yazma
// yetkisi yok.
//
// İsteğin gerçekten RevenueCat'ten geldiğini `Authorization` başlığındaki
// paylaşılan sırla doğruluyoruz. Doğrulamasaydık adresi bilen herkes kendini
// Pro yapabilirdi — adres gizli değil, sır gizli.
//
// Gereken gizli değerler (Supabase → Edge Functions → Secrets):
//   REVENUECAT_WEBHOOK_SECRET   RevenueCat → Integrations → Webhooks'ta
//                               belirlediğin Authorization değerinin aynısı
//
// SUPABASE_URL ve SUPABASE_SERVICE_ROLE_KEY ortamda hazır geliyor.
//
// Dağıtım (jwt doğrulaması kapalı olmalı, RevenueCat Supabase jetonu
// göndermiyor — kendi sırrımızla doğruluyoruz):
//   supabase functions deploy revenuecat-webhook --no-verify-jwt

import { createClient } from "jsr:@supabase/supabase-js@2";

/// RevenueCat'teki entitlement kimlikleri. Panelde birebir böyle olmalı.
const PLAN_BY_ENTITLEMENT: Record<string, string> = {
  plus: "plus",
  pro: "pro",
};

/// Hakkı bitiren olaylar. Diğerlerinde entitlement listesine bakıyoruz.
///
/// CANCELLATION bilerek burada DEĞİL: iptal "otomatik yenileme kapandı"
/// demek, hak dönem sonuna kadar sürüyor. Onu da bitirseydik parasını ödemiş
/// kullanıcının özellikleri iptal ettiği anda kapanırdı.
const BITIREN_OLAYLAR = new Set([
  "EXPIRATION",
  "TRANSFER",
  "SUBSCRIPTION_PAUSED",
]);

function uuidMi(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const beklenen = Deno.env.get("REVENUECAT_WEBHOOK_SECRET");
  if (!beklenen) {
    console.error("REVENUECAT_WEBHOOK_SECRET tanımlı değil");
    return new Response(JSON.stringify({ error: "not_configured" }), { status: 500 });
  }
  if (request.headers.get("Authorization") !== beklenen) {
    return new Response(JSON.stringify({ error: "unauthorized" }), { status: 401 });
  }

  let olay: Record<string, unknown>;
  try {
    const govde = await request.json();
    olay = (govde.event ?? {}) as Record<string, unknown>;
  } catch {
    return new Response(JSON.stringify({ error: "bad_request" }), { status: 400 });
  }

  const kullanici = String(olay.app_user_id ?? "");
  // Uygulama, RevenueCat'i Supabase kullanıcı kimliğiyle yapılandırıyor.
  // Anonim kimlikler ($RCAnonymousID:...) hiçbir hesaba bağlı değil; onlar
  // için yazacak bir satır yok.
  if (!uuidMi(kullanici)) {
    return new Response(JSON.stringify({ ok: true, skipped: "anonymous" }), {
      headers: { "Content-Type": "application/json" },
    });
  }

  const tur = String(olay.type ?? "");
  const haklar = Array.isArray(olay.entitlement_ids) ? olay.entitlement_ids as string[] : [];
  const bitisMs = typeof olay.expiration_at_ms === "number" ? olay.expiration_at_ms : 0;

  let plan = "free";
  let expires: string | null = null;

  if (!BITIREN_OLAYLAR.has(tur) && bitisMs > Date.now()) {
    // En yüksek kademe kazanır: Plus'tan Pro'ya geçişte iki hak da bir süre
    // etkin görünebiliyor.
    for (const hak of haklar) {
      const aday = PLAN_BY_ENTITLEMENT[hak];
      if (!aday) continue;
      if (plan === "free" || (plan === "plus" && aday === "pro")) plan = aday;
    }
    if (plan !== "free") expires = new Date(bitisMs).toISOString();
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { error } = await admin.rpc("set_plan", {
    account: kullanici,
    new_plan: plan,
    original_transaction: olay.original_transaction_id ?? null,
    product: olay.product_id ?? null,
    expires,
  });
  if (error) {
    console.error("set_plan başarısız", error.message);
    // 500 dönüyoruz ki RevenueCat tekrar denesin; sessizce yutmak, parasını
    // ödemiş kullanıcıyı ücretsiz bırakır.
    return new Response(JSON.stringify({ error: "write_failed" }), { status: 500 });
  }

  return new Response(JSON.stringify({ ok: true, plan }), {
    headers: { "Content-Type": "application/json" },
  });
});
