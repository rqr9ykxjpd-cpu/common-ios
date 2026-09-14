# Sign in with Apple account deletion

Status: local implementation; **not deployed or end-to-end tested against Apple**.
This does not modify the existing App Store submission or its build. A new build
is needed for the updated deletion UI.

The iOS deletion sheet requests a fresh Apple authorization code and ID token.
This function verifies the caller through Supabase Auth, checks both Apple ID
tokens against Apple's JWKS and the configured native client ID, binds the
verified Apple subject to the caller's existing Apple identity, and checks the
nonce and five-minute freshness. It then exchanges the one-use code and revokes
the returned refresh token. A code belonging to a different identity can never
reach the revocation request. Credentials and token responses are not logged,
stored, or returned to the device.

The existing signed-in account deletion RPC and Storage cleanup run in iOS after
revocation. If revocation succeeds but account deletion fails, the sheet retains
the revoked state and allows retrying account deletion without reauthorization.
Only the user UUID/deletion intent is persisted on the device (never Apple
tokens), so RootView resumes the restricted deletion screen across relaunch.
The marker is observable AppState state backed by the injected UserDefaults.
This screen cannot be dismissed back to normal app use after revocation; it
offers retry or explicit sign-out. Revocation notifications do not clear the
Supabase session while this deletion is pending. Completing deletion clears
the marker; a fresh Apple sign-in also clears it because permission is granted
again and any future deletion must revoke that new authorization.
Canceling Apple authentication never deletes the account. A separately confirmed
manual path can delete a legacy account even when its Apple credentials are
unavailable. It explains that Apple permission still needs to be removed and
shows Apple's instructions again after deletion. This follows the fallback
described in TN3194; it is not a claim that automatic revocation succeeded.

## Deployment prerequisites (Supabase work, deferred)

Configure only as Supabase Edge Function secrets:

- `APPLE_CLIENT_ID`: `com.campus.social` (native bundle ID, not a web Services ID).
- `APPLE_TEAM_ID`: Apple Developer Team ID associated with this app.
- `APPLE_KEY_ID`: identifier of a **Sign in with Apple** enabled private key.
- `APPLE_PRIVATE_KEY`: complete PKCS#8 `.p8` key including BEGIN/END lines.

The App Store purchase key/RevenueCat key is not interchangeable with a Sign in
with Apple key. Never put this private key or generated client secret in an
xcconfig, Info.plist, the app binary, git, or a user-visible log. The short-lived
client secret is signed on the server per request, avoiding a hardcoded
six-month client-secret expiry. Supabase provides `SUPABASE_URL` and
`SUPABASE_ANON_KEY` automatically; no service-role/database-admin access is used.

Deploy to the app's actual Supabase project with:

```sh
supabase functions deploy revoke-apple-token --no-verify-jwt
```

The gateway JWT check may be disabled for modern Supabase signing keys because
the handler performs mandatory `auth.getUser(bearer)` validation itself. The
function is **not anonymous**: a missing/invalid bearer returns 401 before any
Apple request. Do not remove this validation. This deployment command has not
been run.

## Verification

Offline handler tests (no Apple/Supabase network calls):

```sh
node --experimental-strip-types --test supabase/functions/revoke-apple-token/handler.test.ts
```

Before release, deploy with the real Apple credentials, then use a dedicated
test account to check:

1. Apple-linked account: confirm deletion, reauthorize the same Apple account,
   verify Common account/storage removal and Apple authorization state.
2. Cancel reauthorization: account remains intact.
3. Reauthorize a different Apple account: reject without revoking either account.
4. Missing/expired Apple authorization or unavailable function: show a truthful
   retry/manual explanation; manual deletion needs its own destructive confirm.
5. Simulate a failed account-deletion RPC after successful revocation: retry
   deletion without requiring a fresh Apple sign-in, including after relaunch.
   Confirm ordinary app screens are gated and explicit sign-out remains usable.
6. Google-only account: existing deletion flow remains available without an
   Apple step.
7. Apple credential-revoked notification: local session is cleared outside an
   ongoing deletion, but the event cannot interrupt the deletion RPC.

This implementation obtains tokens just in time for in-app account deletion.
It does not implement a server token vault or server-to-server Apple account
change notifications, which would be needed for offline revocation without a
fresh device authorization.

## Official references

- https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple
- https://developer.apple.com/documentation/signinwithapplerestapi/generate-and-validate-tokens
- https://developer.apple.com/documentation/signinwithapplerestapi/revoke-tokens
- https://support.apple.com/102571
