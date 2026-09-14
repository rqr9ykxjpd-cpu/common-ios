import assert from "node:assert/strict";
import test from "node:test";
import { makeRevocationHandler } from "./handler.ts";
import type { AppleClaims, RevocationDependencies } from "./handler.ts";

const now = 1_800_000_000;
const nonce = "4".repeat(64);
const hash = [...new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(nonce)))]
  .map((value) => value.toString(16).padStart(2, "0")).join("");

function fixture() {
  const calls: { url: string; body: URLSearchParams }[] = [];
  const claims: Record<string, AppleClaims> = {
    native: { sub: "apple-owner", nonce: hash, iat: now - 10, exp: now + 300 },
    exchanged: { sub: "apple-owner", nonce: hash, iat: now - 10, exp: now + 300 },
  };
  const deps: RevocationDependencies = {
    clientID: "com.campus.social",
    now: () => now,
    authenticate: async (bearer) => bearer === "valid-session" ? { appleSubjects: ["apple-owner"] } : null,
    verifyAppleToken: async (token) => {
      if (!(token in claims)) throw new Error("invalid_signature");
      return claims[token];
    },
    createClientSecret: async () => "server-only-secret",
    fetch: (async (url, init) => {
      calls.push({ url: String(url), body: new URLSearchParams(init?.body as URLSearchParams) });
      assert.equal(init?.redirect, "error");
      if (String(url).endsWith("/auth/token")) {
        return Response.json({ id_token: "exchanged", refresh_token: "apple-refresh-token" });
      }
      return new Response(null, { status: 200 });
    }) as typeof fetch,
  };
  const request = (overrides: Record<string, unknown> = {}, bearer = "valid-session") => new Request("https://test.invalid/revoke-apple-token", {
    method: "POST",
    headers: { "Authorization": `Bearer ${bearer}`, "Content-Type": "application/json" },
    body: JSON.stringify({ authorizationCode: "fresh-code", identityToken: "native", nonce, ...overrides }),
  });
  return { deps, calls, claims, request, run: (req = request()) => makeRevocationHandler(deps)(req) };
}

test("only a verified bound authorization reaches Apple's revocation endpoint", async () => {
  const f = fixture();
  const response = await f.run();
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { revoked: true });
  assert.equal(response.headers.get("Cache-Control"), "no-store");
  assert.equal(f.calls.length, 2);
  assert.equal(f.calls[0].url, "https://appleid.apple.com/auth/token");
  assert.equal(f.calls[0].body.get("grant_type"), "authorization_code");
  assert.equal(f.calls[1].url, "https://appleid.apple.com/auth/revoke");
  assert.equal(f.calls[1].body.get("token"), "apple-refresh-token");
  assert.equal(f.calls[1].body.get("token_type_hint"), "refresh_token");
});

test("missing or invalid Supabase session cannot exchange or revoke", async () => {
  const f = fixture();
  assert.equal((await f.run(f.request({}, "invalid-session"))).status, 401);
  assert.equal((await f.run(new Request("https://test.invalid", { method: "POST" }))).status, 401);
  assert.equal(f.calls.length, 0);
});

test("an unlinked account or spoofed body user ID cannot revoke someone else's Apple identity", async () => {
  const f = fixture();
  f.deps.authenticate = async () => ({ appleSubjects: ["another-apple-owner"] });
  assert.equal((await f.run(f.request({ user_id: "victim", appleSubject: "apple-owner" }))).status, 403);
  f.deps.authenticate = async () => ({ appleSubjects: [] });
  assert.equal((await f.run()).status, 403);
  assert.equal(f.calls.length, 0);
});

test("invalid Apple signature is rejected before exchange", async () => {
  const f = fixture();
  assert.equal((await f.run(f.request({ identityToken: "forged" }))).status, 400);
  assert.equal(f.calls.length, 0);
});

test("nonce mismatch, missing nonce, expired or stale tokens never reach exchange", async () => {
  for (const change of [
    { nonce: "wrong" }, { nonce: undefined }, { iat: now - 301 },
    { iat: now + 60 }, { exp: now }, { exp: undefined }, { iat: undefined },
  ]) {
    const f = fixture();
    Object.assign(f.claims.native, change);
    assert.equal((await f.run()).status, 400);
    assert.equal(f.calls.length, 0);
  }
});

test("own identity token plus another person's authorization code never triggers revoke", async () => {
  const f = fixture();
  f.claims.exchanged.sub = "another-apple-owner";
  assert.equal((await f.run()).status, 403);
  assert.equal(f.calls.length, 1);
  assert.ok(f.calls.every((call) => !call.url.endsWith("/auth/revoke")));
});

test("exchanged token must have a valid signature and match the original fresh nonce", async () => {
  for (const mutation of ["bad-signature", "wrong-nonce", "expired"]) {
    const f = fixture();
    if (mutation === "bad-signature") delete f.claims.exchanged;
    if (mutation === "wrong-nonce") f.claims.exchanged.nonce = "different-request";
    if (mutation === "expired") f.claims.exchanged.exp = now - 1;
    assert.notEqual((await f.run()).status, 200);
    assert.equal(f.calls.length, 1);
  }
});

test("missing server secret is explicit and no provider request is sent", async () => {
  const f = fixture();
  f.deps.createClientSecret = async () => { throw new Error("secret missing"); };
  assert.equal((await f.run()).status, 503);
  assert.equal(f.calls.length, 0);
});

test("provider exchange errors do not claim successful revocation or leak the response", async () => {
  const f = fixture();
  f.deps.fetch = (async () => new Response("SECRET-TOKEN", { status: 400 })) as typeof fetch;
  const response = await f.run();
  assert.equal(response.status, 502);
  assert.deepEqual(await response.json(), { error: "apple_exchange_failed" });
});

test("provider revocation errors do not claim success", async () => {
  const f = fixture();
  const original = f.deps.fetch;
  f.deps.fetch = (async (url, init) => String(url).endsWith("/auth/revoke")
    ? new Response(null, { status: 503 }) : original(url, init)) as typeof fetch;
  const response = await f.run();
  assert.equal(response.status, 502);
  assert.deepEqual(await response.json(), { error: "apple_revocation_failed" });
});

test("malformed request and oversized payload are rejected", async () => {
  const f = fixture();
  assert.equal((await f.run(f.request({ nonce: "short" }))).status, 400);
  assert.equal((await f.run(f.request({ authorizationCode: "x".repeat(20_000) }))).status, 413);
  assert.equal((await f.run(new Request("https://test.invalid", { method: "GET" }))).status, 405);
  assert.equal(f.calls.length, 0);
});
