import { createClient } from "jsr:@supabase/supabase-js@2";
import { createRemoteJWKSet, importPKCS8, jwtVerify, SignJWT } from "npm:jose@6.1.0";
import { makeRevocationHandler } from "./handler.ts";

const clientID = Deno.env.get("APPLE_CLIENT_ID") ?? "com.campus.social";
const appleKeys = createRemoteJWKSet(new URL("https://appleid.apple.com/auth/keys"));

Deno.serve(makeRevocationHandler({
  clientID,
  now: () => Math.floor(Date.now() / 1000),
  fetch,
  authenticate: async (bearer) => {
    // getUser contacts Supabase Auth and verifies the bearer. Local JWT decoding
    // or user_metadata would not provide a trustworthy account binding.
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { auth: { persistSession: false, autoRefreshToken: false } },
    );
    const { data, error } = await supabase.auth.getUser(bearer);
    if (error || !data.user) return null;
    return {
      appleSubjects: (data.user.identities ?? [])
        .filter((identity) => identity.provider === "apple")
        .map((identity) => identity.identity_data?.sub)
        .filter((subject): subject is string => typeof subject === "string" && subject.length > 0),
    };
  },
  verifyAppleToken: async (token) => {
    const { payload } = await jwtVerify(token, appleKeys, {
      algorithms: ["RS256"],
      issuer: "https://appleid.apple.com",
      audience: clientID,
      requiredClaims: ["sub", "iat", "exp", "nonce"],
      maxTokenAge: "5m",
      clockTolerance: 30,
    });
    return payload;
  },
  createClientSecret: async () => {
    const teamID = Deno.env.get("APPLE_TEAM_ID");
    const keyID = Deno.env.get("APPLE_KEY_ID");
    const privateKey = Deno.env.get("APPLE_PRIVATE_KEY")?.replace(/\\n/g, "\n");
    if (!teamID || !keyID || !privateKey) throw new Error("apple_not_configured");
    const key = await importPKCS8(privateKey, "ES256");
    return await new SignJWT({})
      .setProtectedHeader({ alg: "ES256", kid: keyID })
      .setIssuer(teamID)
      .setSubject(clientID)
      .setAudience("https://appleid.apple.com")
      .setIssuedAt()
      .setExpirationTime("5m")
      .sign(key);
  },
}));
