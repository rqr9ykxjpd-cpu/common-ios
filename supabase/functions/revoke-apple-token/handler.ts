/** All identity claims passed here must come from a verified Apple signature. */
export interface AppleClaims {
  sub?: string;
  nonce?: unknown;
  iat?: number;
  exp?: number;
}

export interface RevocationDependencies {
  /** Validate the Supabase bearer on the server; never trust a body user ID. */
  authenticate: (bearer: string) => Promise<{ appleSubjects: string[] } | null>;
  /** Verify signature, issuer, audience, expiry and required claims with Apple JWKS. */
  verifyAppleToken: (token: string) => Promise<AppleClaims>;
  clientID: string;
  createClientSecret: () => Promise<string>;
  fetch: typeof fetch;
  now: () => number;
}

const APPLE_ORIGIN = "https://appleid.apple.com";
const MAX_BODY_BYTES = 16_384;

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

function isString(value: unknown, maximum: number): value is string {
  return typeof value === "string" && value.length > 0 && value.length <= maximum;
}

async function nonceDigest(nonce: string): Promise<string> {
  const bytes = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(nonce));
  return [...new Uint8Array(bytes)].map((value) => value.toString(16).padStart(2, "0")).join("");
}

function matchesFreshAuthorization(claims: AppleClaims, subject: string, nonce: string, now: number): boolean {
  // The authorization code is one-use and valid for five minutes. Requiring
  // a fresh, matching token also prevents replaying an old sign-in ID token.
  return claims.sub === subject && claims.nonce === nonce &&
    typeof claims.iat === "number" && Number.isFinite(claims.iat) &&
    claims.iat <= now + 30 && claims.iat >= now - 300 &&
    typeof claims.exp === "number" && Number.isFinite(claims.exp) && claims.exp > now;
}

export function makeRevocationHandler(deps: RevocationDependencies) {
  return async (request: Request): Promise<Response> => {
    if (request.method !== "POST") return json(405, { error: "method_not_allowed" });
    const bearer = request.headers.get("Authorization")?.match(/^Bearer\s+(\S+)$/i)?.[1];
    if (!bearer) return json(401, { error: "unauthorized" });

    try {
      const user = await deps.authenticate(bearer);
      if (!user) return json(401, { error: "unauthorized" });
      if (!user.appleSubjects.length) return json(403, { error: "apple_identity_missing" });
      if (!request.headers.get("Content-Type")?.toLowerCase().startsWith("application/json")) {
        return json(415, { error: "json_required" });
      }
      if (Number(request.headers.get("Content-Length") ?? 0) > MAX_BODY_BYTES) {
        return json(413, { error: "body_too_large" });
      }
      let body: Record<string, unknown>;
      try {
        const raw = await request.text();
        if (new TextEncoder().encode(raw).length > MAX_BODY_BYTES) return json(413, { error: "body_too_large" });
        body = JSON.parse(raw);
        if (!body || typeof body !== "object" || Array.isArray(body)) throw new Error("invalid_body");
      } catch {
        return json(400, { error: "bad_request" });
      }
      if (!isString(body.authorizationCode, 4096) || !isString(body.identityToken, 8192) ||
          !isString(body.nonce, 256) || body.nonce.length < 32) {
        return json(400, { error: "bad_request" });
      }

      const expectedNonce = await nonceDigest(body.nonce);
      let suppliedClaims: AppleClaims;
      try {
        suppliedClaims = await deps.verifyAppleToken(body.identityToken);
      } catch {
        return json(400, { error: "invalid_apple_token" });
      }
      // Use ONLY the Apple subject stored in the authenticated Supabase identity.
      // Never bind by email (Apple relay addresses can differ) or a submitted ID.
      const subject = user.appleSubjects.find((value) => value === suppliedClaims.sub);
      if (!subject) return json(403, { error: "apple_identity_mismatch" });
      if (!matchesFreshAuthorization(suppliedClaims, subject, expectedNonce, deps.now())) {
        return json(400, { error: "invalid_apple_authorization" });
      }

      let clientSecret: string;
      try {
        clientSecret = await deps.createClientSecret();
        if (!clientSecret || !deps.clientID) throw new Error("not_configured");
      } catch {
        return json(503, { error: "not_configured" });
      }
      const tokenReply = await deps.fetch(`${APPLE_ORIGIN}/auth/token`, {
        method: "POST",
        redirect: "error",
        signal: AbortSignal.timeout(10_000),
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
          client_id: deps.clientID,
          client_secret: clientSecret,
          code: body.authorizationCode,
          grant_type: "authorization_code",
        }),
      });
      // Do not echo Apple's token response or log authorization credentials.
      if (!tokenReply.ok) return json(502, { error: "apple_exchange_failed" });
      const tokens = await tokenReply.json() as Record<string, unknown>;
      if (!isString(tokens.id_token, 8192) || !isString(tokens.refresh_token, 8192)) {
        return json(502, { error: "invalid_apple_response" });
      }
      let exchangedClaims: AppleClaims;
      try {
        exchangedClaims = await deps.verifyAppleToken(tokens.id_token);
      } catch {
        return json(502, { error: "invalid_apple_response" });
      }
      // A caller must not combine their ID token with someone else's code.
      // Verify the exchanged token before sending ANY revocation request.
      if (exchangedClaims.sub !== subject) return json(403, { error: "apple_identity_mismatch" });
      if (!matchesFreshAuthorization(exchangedClaims, subject, expectedNonce, deps.now())) {
        return json(400, { error: "invalid_apple_authorization" });
      }

      const revokeReply = await deps.fetch(`${APPLE_ORIGIN}/auth/revoke`, {
        method: "POST",
        redirect: "error",
        signal: AbortSignal.timeout(10_000),
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
          client_id: deps.clientID,
          client_secret: clientSecret,
          token: tokens.refresh_token,
          token_type_hint: "refresh_token",
        }),
      });
      if (!revokeReply.ok) return json(502, { error: "apple_revocation_failed" });
      // The refresh token is used only in memory and is never stored or returned.
      // Account/storage deletion continues through the signed-in app's existing
      // delete_my_account RPC. This endpoint never deletes arbitrary accounts.
      return json(200, { revoked: true });
    } catch {
      return json(502, { error: "revocation_unavailable" });
    }
  };
}
