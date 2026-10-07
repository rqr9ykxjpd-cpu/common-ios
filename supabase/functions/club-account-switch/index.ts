// Kulüp hesabına geçiş. Kulübün yöneticisi (ya da kurucu / Common) kulübün
// hesabına şifresiz geçer: fonksiyon çağıranı doğrular, kulübün hesabı
// yoksa açar ve tek kullanımlık bir giriş anahtarı döner. Uygulama anahtarı
// `verifyOTP(tokenHash:type: .magiclink)` ile oturuma çevirir. E-posta
// gönderilmez; kulüp hesabının adresi teslim edilemeyen bir adrestir
// (.invalid), kimse o adresle giriş bağlantısı alamaz.
//
// Kim geçebilir kararı SQL'de (club_account_switch_target,
// 20261007020000_club_accounts). Ana hesaba dönüş sunucuya uğramaz:
// uygulama ana hesabın oturumunu cihazda saklar; kulüp hesabı hiçbir
// zaman yöneticinin hesabına anahtar alamaz.
//
// JWT doğrulaması KAPALI deploy edilir (yeni imza anahtarları); çağıran
// burada auth.getUser ile doğrulanır, anahtarsız istek 401 döner.
// SUPABASE_URL, SUPABASE_ANON_KEY ve SUPABASE_SERVICE_ROLE_KEY ortamda hazır.

import { createClient } from "jsr:@supabase/supabase-js@2";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const KNOWN = new Set(["CLUB_ACCOUNT", "CLUB_NOT_FOUND", "CLUB_MANAGER_ONLY"]);

function reply(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function clubEmail(club: string): string {
  return `kulup-${club.toLowerCase()}@hesap.common.invalid`;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return reply(405, { error: "method_not_allowed" });

  const bearer = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "").trim();
  if (!bearer) return reply(401, { error: "unauthorized" });

  const url = Deno.env.get("SUPABASE_URL")!;
  const options = { auth: { persistSession: false, autoRefreshToken: false } };
  const anon = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, options);
  const { data: who, error: whoError } = await anon.auth.getUser(bearer);
  if (whoError || !who.user) return reply(401, { error: "unauthorized" });

  let club: unknown;
  try {
    club = (await req.json())?.club_id;
  } catch {
    return reply(400, { error: "bad_request" });
  }
  if (typeof club !== "string" || !UUID.test(club)) return reply(400, { error: "bad_request" });

  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, options);

  const { data: rows, error: targetError } = await admin.rpc("club_account_switch_target", {
    caller: who.user.id,
    club,
  });
  if (targetError) {
    const code = KNOWN.has(targetError.message) ? targetError.message : "switch_failed";
    return reply(code === "switch_failed" ? 500 : 403, { error: code });
  }
  const target = (rows as { account: string | null; club_name: string; logo_path: string | null }[])[0];
  if (!target) return reply(403, { error: "CLUB_NOT_FOUND" });

  const email = clubEmail(club);
  if (!target.account) {
    // Önceki bir deneme kullanıcıyı açıp profilde kaldıysa adres zaten var;
    // aşağıdaki generateLink o kullanıcıyı bulur, profil tamamlanır.
    const { error: createError } = await admin.auth.admin.createUser({
      email,
      email_confirm: true,
      app_metadata: { club_account: club },
    });
    if (createError && createError.code !== "email_exists") {
      return reply(500, { error: "switch_failed" });
    }
  }

  const { data: link, error: linkError } = await admin.auth.admin.generateLink({
    type: "magiclink",
    email,
  });
  const tokenHash = link?.properties?.hashed_token;
  const account = link?.user?.id;
  if (linkError || !tokenHash || !account) return reply(500, { error: "switch_failed" });

  if (!target.account) {
    // Kulübün logosu hesabın profil fotoğrafı olur; yoksa uygulama ilk
    // açılışta fotoğraf ister.
    let avatar: string | null = null;
    if (target.logo_path) {
      const { data: logo } = await admin.storage.from("club-media").download(target.logo_path);
      if (logo) {
        const ext = target.logo_path.split(".").pop()?.toLowerCase() === "png" ? "png" : "jpg";
        const path = `${account}/avatar-${crypto.randomUUID()}.${ext}`;
        const { error: uploadError } = await admin.storage.from("profile-photos").upload(path, logo, {
          contentType: ext === "png" ? "image/png" : "image/jpeg",
          upsert: false,
        });
        if (!uploadError) avatar = path;
      }
    }
    const { error: provisionError } = await admin.rpc("provision_club_account", {
      club,
      account,
      avatar,
    });
    if (provisionError) return reply(500, { error: "switch_failed" });
  }

  return reply(200, { token_hash: tokenHash, account, club_name: target.club_name });
});
