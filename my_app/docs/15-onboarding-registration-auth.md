# POS 15 — Onboarding: registration, sign-in & first-run setup

How a brand-new restaurant owner goes from "just installed the POS app" to "taking orders", plus how returning owners and staff sign in. Covers:

1. Discovering which sign-in / sign-up methods the server allows
2. Owner sign-up (mobile + SMS code, or email + password)
3. Sign-in (email + password, or mobile + SMS code)
4. Optional device pairing (6-digit code)
5. POS PIN
6. First-run setup wizard (business basics, first products / AI menu scan)

For bootstrap, terminals and shifts after sign-in see [10-auth-bootstrap-shifts.md](10-auth-bootstrap-shifts.md). Shared conventions (envelope, errors, headers) are in [../00-conventions-and-auth.md](../00-conventions-and-auth.md).

---

## End-to-end flow

```text
App start
  └─ GET /api/v1/auth/options            → login_method, registration_enabled, phone_default_country,
       │                                     phone_auth_provider, firebase_config
       │
       ├─ "Create a new restaurant"  (only if registration_enabled)
       │     phone mode:  POST /auth/phone/send (purpose=register, supports_firebase)
       │                  [auth_provider=firebase → app sends SMS via Firebase, gets id_token]
       │                  POST /auth/phone/verify (purpose=register, code | id_token)  → phone_token
       │                  POST /auth/register { phone_token, name, restaurant_name, … }
       │     email mode:  POST /auth/register { email, password, name, restaurant_name, … }
       │                                                              → Bearer token (ability pos)
       │
       ├─ "Sign in"
       │     email:       POST /auth/login                            → Bearer token
       │     phone:       POST /auth/phone/send (purpose=sign_in, supports_firebase)
       │                  [auth_provider=firebase → Firebase SMS → id_token]
       │                  POST /auth/phone/verify (purpose=sign_in, code | id_token)   → Bearer token
       │
       └─ "Pair with a code" (optional; binds device to a terminal)
             POST /pos/pairing/start → show code → poll GET /pos/pairing/status
             (admin enters code on the web: POST /admin/pos/pairing/complete)

After a token:
  pick restaurant / branch (if several) → set POS PIN (prompt) →
  GET /pos/bootstrap → if no menu items and user can manage menu → setup wizard
```

**Pairing ≠ login.** Pairing only binds hardware to a terminal; a staff/owner still signs in.

---

## Conventions

- Base URL: `{server}/api/v1`. All requests: `Accept: application/json`, `Content-Type: application/json` (multipart for uploads).
- Success envelope: `{ "data": { … } }`. Validation errors: HTTP **422** `{ "message": "…", "errors": { "field": ["…"] } }`. Show `errors[field][0]` next to the field.
- Every token-issuing call accepts these optional fields — **always send them from the POS**:

| Field | Value |
|------|-------|
| `token_ability` | `pos` (required for `/pos/*` routes; default would be `mobile`) |
| `device_name` | e.g. `ServeAI POS (Android)` — shown in the owner's active sessions |
| `restaurant_id` / `branch_id` | Optional: pre-select context in the returned profile |

- Authenticated calls: `Authorization: Bearer {token}`, `X-Restaurant-Id`, `X-Branch-Id`.
- Recommended device headers: `X-Pos-Platform` (`android`, `ios`, `windows`, `macos`…), `X-Pos-App-Version`.
- Phone numbers: send in E.164 (`+919876543210`). Prefill the country picker from `phone_default_country`. The server normalizes and validates.

---

## 1. Auth options

`GET /api/v1/auth/options` — public. Call on app start / before showing the welcome screen.

```json
{
  "data": {
    "login_method": "both",
    "registration_enabled": true,
    "phone_default_country": "IN",
    "phone_auth_provider": "server",
    "firebase_config": null
  }
}
```

`phone_auth_provider` is `server` (ServeAI texts the code) or `firebase` (the app texts it through Firebase phone auth, §2). When `firebase`, `firebase_config` holds the public Firebase config (no secrets):

```json
{
  "apiKey": "AIza…",
  "authDomain": "demo.firebaseapp.com",
  "projectId": "demo",
  "appId": "1:123:web:abc",
  "messagingSenderId": "123",
  "nativeAppIds": {
    "pos": { "android": "1:123:android:pos", "ios": "1:123:ios:pos" },
    "kiosk": { "android": "", "ios": "" },
    "customer": { "android": "", "ios": "" }
  }
}
```

| `login_method` | Sign-up form | Sign-in form |
|---|---|---|
| `both` | Mobile **or** email + password | Mobile code or email + password |
| `phone` | Mobile only (email/password are rejected) | Mobile code; email + password stays available as a fallback for staff/super-admins without a phone |
| `email` | Email + password only (`phone_token` rejected) | Email + password only |

- Hide "Create a new restaurant" when `registration_enabled` is `false`.
- Present Sign in / Pair / Create as **equal-weight options** (none "recommended").

---

## 2. SMS one-time codes

The code is texted either by ServeAI (Twilio, etc.) or, when the platform's SMS provider is **Firebase**, by the app itself through the Firebase Auth SDK. Always call **send** first; its `auth_provider` tells you which path to take.

### Send code

`POST /api/v1/auth/phone/send` — throttle 10/min per IP, plus max **3 sends per hour per number**.

```json
{ "phone": "+919876543210", "purpose": "register", "supports_firebase": true }
```

| Field | Rules |
|---|---|
| `purpose` | `register` \| `sign_in` |
| `supports_firebase` | `true` only if this build can run Firebase phone auth (Android / iOS). Omit or `false` on desktop (Windows, macOS, Linux) |

**Server-sent code** (`auth_provider: "server"`):

```json
{ "data": { "message": "We sent a 6-digit code to your mobile number.", "auth_provider": "server", "debug_otp": "123456" } }
```

`debug_otp` only appears on local/testing servers using the log SMS driver — never rely on it in production.

**Firebase** (`auth_provider: "firebase"`, only when you sent `supports_firebase: true`). The server has checked the number and the rate limit but **has not** sent an SMS:

```json
{
  "data": {
    "message": "We sent a 6-digit code to your mobile number.",
    "auth_provider": "firebase",
    "firebase_config": { "apiKey": "…", "projectId": "…", "appId": "…", "messagingSenderId": "…", "nativeAppIds": { "pos": { "android": "…", "ios": "…" } } }
  }
}
```

Then, in the app:

1. Initialize Firebase from `firebase_config` (`Firebase.initializeApp(options: …)`; no `google-services.json` needed). Use `nativeAppIds.pos.android` / `.ios` as the app ID on that platform, falling back to `appId` when empty. Reuse the existing Firebase app if push notifications already initialized one.
2. `FirebaseAuth.verifyPhoneNumber(phoneNumber: "+919876543210", …)` — Firebase texts the 6-digit code.
3. When the user enters it: `PhoneAuthProvider.credential(verificationId, smsCode)` → `signInWithCredential` → `user.getIdToken()`.
4. Send that ID token to **verify** (below) instead of `phone` + `code`.

Firebase errors (invalid number, quota, app not authorized, wrong code) come from the SDK — show `e.message`. Requirements in the Firebase console: Phone sign-in enabled; the POS registered as an Android app (package name + SHA-1/SHA-256 of the signing key) and iOS app (bundle ID), with their app IDs entered in Super Admin → Push notifications → Android & iOS apps.

**Older builds / desktop:** when Firebase is the platform provider but the request has no `supports_firebase`, the server texts the code itself through a configured server provider (Twilio) and answers with `auth_provider: "server"`. If no server provider is configured it returns the 422 below.

Possible 422 errors on `phone`:

| Situation | Message |
|---|---|
| Invalid number | Enter a valid mobile number. |
| `register` but number already has an account | This mobile number is already registered. Sign in as owner instead. |
| `sign_in` but no account with this number | No owner account uses this mobile number. |
| Too many sends | Too many code requests. Try again in :seconds seconds. |
| Phone login disabled (`login_method=email`) | Mobile number sign-in is turned off. Use your email address instead. |
| SMS gateway not configured | SMS verification is not set up on this server yet. |
| Firebase provider, no `supports_firebase`, and no server fallback (Twilio) | This server sends SMS codes with Firebase, which this app version does not support. Update the app or use email instead. |

`register` while registrations are disabled → **403** `New registrations are currently disabled.`

Code rules (server-sent codes): 6 digits, valid **10 minutes**, max **5** wrong attempts (then request a new code). Show a resend timer (e.g. 30–60 s); resend = call **send** again (for Firebase, pass the previous `forceResendingToken`).

### Verify code

`POST /api/v1/auth/phone/verify` — throttle 20/min.

Server-sent code:

```json
{
  "phone": "+919876543210",
  "code": "123456",
  "purpose": "sign_in",
  "token_ability": "pos",
  "device_name": "ServeAI POS (Android)"
}
```

Firebase — send the ID token instead of `phone` + `code` (the server reads the verified number from the token):

```json
{
  "id_token": "eyJhbGciOiJSUzI1NiIs…",
  "purpose": "sign_in",
  "token_ability": "pos",
  "device_name": "ServeAI POS (Android)"
}
```

`phone` and `code` are required unless `id_token` is sent. The same purpose checks apply to both: `register` rejects a number that already has an account, `sign_in` rejects an unknown number (422 on `phone`). An invalid or expired ID token → 422 on `id_token`.

- `purpose = register` → returns a short-lived proof of ownership (valid **30 minutes**):

```json
{ "data": { "phone": "+919876543210", "phone_token": "eyJpdiI6…" } }
```

- `purpose = sign_in` → returns the full **token payload** (see §4).

422 errors on `code`: `That code is incorrect. Try again.` · `This code has expired. Request a new one.` · `Too many incorrect attempts. Request a new code.`

---

## 3. Owner registration (create a new restaurant)

`POST /api/v1/auth/register` — public, throttle 10/min, blocked with **403** when registration is disabled.

Creates the owner user + restaurant (default branch, default plan/trial) and signs straight in.

### Mobile sign-up

```json
{
  "phone_token": "eyJpdiI6…",
  "name": "Ravi Kumar",
  "restaurant_name": "Spice Garden",
  "restaurant_city": "Pune",
  "restaurant_cuisine": "Indian",
  "token_ability": "pos",
  "device_name": "ServeAI POS (Android)"
}
```

### Email sign-up

```json
{
  "email": "ravi@example.com",
  "password": "S3cure-pass",
  "name": "Ravi Kumar",
  "restaurant_name": "Spice Garden",
  "token_ability": "pos",
  "device_name": "ServeAI POS (Android)"
}
```

| Field | Rules |
|---|---|
| `name` | required, ≤255 |
| `restaurant_name` | required, ≤255 |
| `restaurant_city`, `restaurant_cuisine` | optional, ≤255 |
| `plan_id` | optional; defaults to the platform signup plan |
| `phone_token` | required in `phone` mode; prohibited in `email` mode; in `both` mode required unless `email` is sent |
| `email` | required in `email` mode; prohibited in `phone` mode; unique, lowercase |
| `password` | required with `email`; platform password policy |

Response **201** = token payload (§4) plus:

```json
{ "data": { "…": "…", "pending_approval": false } }
```

If `pending_approval` is `true` the platform requires super-admin approval: show a "We're reviewing your restaurant" state; `current_restaurant.status` will be `pending`.

Errors: `phone_token` → `Mobile verification expired. Verify your number again.` (go back to the code step) or `This mobile number is already registered…`; `email` → unique / format errors.

---

## 4. Sign-in & token payload

### Email + password

`POST /api/v1/auth/login` — throttle 20/min plus per-email lockout.

```json
{
  "email": "owner@serveai.test",
  "password": "password",
  "token_ability": "pos",
  "device_name": "ServeAI POS (Android)"
}
```

Wrong credentials → 422 on `email` (`These credentials do not match our records.`).

### Mobile + code

`POST /auth/phone/send` with `purpose=sign_in`, then `POST /auth/phone/verify` with `purpose=sign_in` and either `phone` + `code` or a Firebase `id_token` (§2).

### Token payload (login, phone sign-in, register)

```json
{
  "data": {
    "token": "12|abcdef…",
    "token_type": "Bearer",
    "abilities": ["pos"],
    "user": { "id": 5, "name": "Ravi Kumar", "email": null, "has_pos_pin": false },
    "is_super_admin": false,
    "restaurants": [
      { "id": 3, "name": "Spice Garden", "slug": "spice-garden", "status": "active", "role": "owner",
        "branches": [{ "id": 7, "name": "Main", "slug": "main", "is_default": true }] }
    ],
    "current_restaurant": { "id": 3, "name": "Spice Garden", "slug": "spice-garden", "status": "active" },
    "current_branch": { "id": 7, "name": "Main", "slug": "main", "address": null, "phone": null },
    "permissions": ["access_pos", "manage_menu", "manage_settings", "…"],
    "plan_features": ["orders", "menu", "tables", "…"],
    "realtime": { "…": "…" }
  }
}
```

- Store `token` in secure storage (Keychain / Keystore). On desktop, use a store that survives rebuilds.
- `user.email` can be `null` for phone-only owners.
- If `restaurants` has more than one entry (or a restaurant has several branches) show a picker, then `POST /auth/switch-restaurant { restaurant_id }` / `POST /auth/switch-branch { branch_id }` — both return the same profile shape (without a new token).
- `GET /auth/me` re-reads the profile; `POST /auth/logout` revokes the current token.
- No `access_pos` / `access_pos_captain` in `permissions` → POS routes return 403; show "ask your owner to give you POS access".

---

## 5. Device pairing (optional)

For staff devices set up by an admin. Public endpoints (no token):

1. `POST /api/v1/pos/pairing/start` (throttle 10/min)

   ```json
   { "platform": "android", "app_version": "1.4.0", "device_name": "Front counter tablet" }
   ```

   → `{ "pairing_code": "482913", "device_uuid": "9f1c…", "expires_at": "2026-10-25T18:10:00Z" }` *(not wrapped in `data`)*

2. Show the code large on screen. Poll `GET /api/v1/pos/pairing/status?device_uuid=…` every ~2 s (throttle 60/min):

   | `status` | Meaning |
   |---|---|
   | `pending` | Waiting for admin |
   | `paired` | Also returns `restaurant_id`, `restaurant_name`, `branch_id`, `branch_name`, `pos_terminal {id, code, name}` |
   | `expired` | Offer "Get a new code" (call start again) |
   | `not_found` | Unknown device — restart |

3. Admin (web *Admin → POS terminals*, or `POST /api/v1/admin/pos/pairing/complete { pairing_code, pos_terminal_id }` with a token of ability `admin` and the `manage_tables` permission) enters the code.

4. Persist restaurant/branch/terminal on the device, then show sign-in pre-scoped to that restaurant (`restaurant_id`, `branch_id` on the login call).

---

## 6. POS PIN

Fast unlock between sessions; separate from the account password.

- `POST /api/v1/auth/set-pos-pin` — `{ "pin": "123456", "current_password": "…" }`
  - PIN: exactly **6 digits** when setting.
  - `current_password` required only when the user has an email/password account; phone-only owners omit it.
  - → `{ "data": { "has_pos_pin": true } }`
- `POST /api/v1/auth/verify-pos-pin` — `{ "pin": "123456" }` (4–6 digits accepted) → `{ "data": { "verified": true } }`; 422 on `pin` if not configured or wrong.

Prompt to set a PIN after the first sign-in when `user.has_pos_pin` is `false` (after the setup wizard if it opens).

---

## 7. First-run setup wizard

Show when **all** are true after `GET /pos/bootstrap`:

- the menu has no items,
- `admin_capabilities.can_manage_menu` is true,
- the owner hasn't dismissed the wizard on this device (store a per-restaurant "dismissed" flag locally).

Steps: **Business basics → First products → Receipt printer (local) → You're live**. Every step can be skipped; the wizard can be reopened from a "Finish setup" card.

All routes below are under `{server}/api/v1/pos/admin`, require the POS token + `X-Restaurant-Id` / `X-Branch-Id`.

### 7.1 Setup status

`GET /pos/admin/setup` (needs `manage_menu` or `manage_settings`)

```json
{
  "data": {
    "complete": false,
    "menu": { "categories": 0, "items": 0 },
    "business": {
      "done": false,
      "currency": "",
      "suggested_currency": "INR",
      "country": "IN",
      "tax": null,
      "taxes": [],
      "tax_editable": true,
      "prices_include_tax": true,
      "opening_hours": { "enabled": false, "open_time": "09:00", "close_time": "22:00", "open_days": ["mon","tue","wed","thu","fri","sat","sun"] }
    },
    "currency_options": ["INR", "USD", "EUR", "…"]
  }
}
```

- `complete` is true once at least one menu item exists.
- Pre-select `currency` if set, otherwise `suggested_currency`.
- `tax_editable` is false when more than one tax already exists and the single `tax_*` fields are used — use the `taxes[]` array form instead, or send owners to the web settings.

### 7.2 Save business basics

`PUT /pos/admin/setup/business` (needs `manage_settings`) → returns the refreshed status (same shape as 7.1).

```json
{
  "currency": "INR",
  "prices_include_tax": true,
  "taxes": [
    { "name": "CGST", "rate": 2.5 },
    { "name": "SGST", "rate": 2.5 }
  ],
  "opening_hours_enabled": true,
  "open_time": "09:00",
  "close_time": "22:00",
  "open_days": ["mon", "tue", "wed", "thu", "fri", "sat"]
}
```

| Field | Rules |
|---|---|
| `currency` | required, 3 letters |
| `prices_include_tax` | boolean, default `true` |
| `taxes[]` | optional, ≤10; each `rate` 0–100, `name` ≤64. **Replaces** all taxes; zero rates are dropped |
| `tax_name` / `tax_rate` | single-tax alternative to `taxes[]`; `tax_rate: 0` removes the tax |
| `opening_hours_enabled` | boolean; omit to leave hours untouched |
| `open_time` / `close_time` | `HH:mm`, required when hours enabled |
| `open_days[]` | `mon`…`sun`; same hours for every selected day |

### 7.3 First products

Two paths:

**A. Add manually**

1. `POST /pos/admin/menu-categories` `{ "name": "Starters", "is_active": true }` → `data.category.id`
2. `POST /pos/admin/menu-items` (multipart if a photo is attached): `menu_category_id`, `name`, `price`, `is_available=1`, optional `image`.

**B. Scan the menu with AI** (needs plan feature `menu`)

1. `GET /pos/admin/menu-import/capabilities` → `capabilities.image_import_available`, `ai_assist_available`, `ai_unavailable_reason`, `ai_credits_remaining`, `pdf_import_available`, `accepted_mimes`, `max_upload_kb`, plus `active_import` (resume it if present). Hide the scan option when image import isn't available and show the reason.
2. `POST /pos/admin/menu-import` multipart: `file` (jpg/png/webp/gif/pdf/csv/xlsx, ≤20 MB), `ai_assist=1` → import status.
3. Poll `GET /pos/admin/menu-import/{id}` every ~2 s while `status` is `extracting`, `pending` or `processing`.

   | `status` | UI |
   |---|---|
   | `extracting` | "Reading your menu…" (+ `progress`) |
   | `awaiting_confirmation` | Show `draft_rows` for review (items = rows with `item_name` and no `modifier_name`) |
   | `pending` / `processing` | "Adding items…" after confirm |
   | `completed` | Done → refresh setup status / bootstrap |
   | `failed` | Show `result` / error, offer retry |
   | `cancelled` | Back to start |

4. Optional edits: `PUT /pos/admin/menu-import/{id}/draft { rows: [...] }` (set `_delete: true` to drop a row).
5. `POST /pos/admin/menu-import/{id}/confirm` → status becomes `pending`; keep polling until `completed`.
6. `POST /pos/admin/menu-import/{id}/cancel` to discard.

Full AI import spec: [../06-ai-menu-upload-api.md](../06-ai-menu-upload-api.md).

### 7.4 Finish

Refresh bootstrap/menu so the register shows the new items, mark the wizard dismissed locally, then show the set-PIN prompt if needed.

---

## Error & edge handling checklist

| Case | Handling |
|---|---|
| 401 on any authed call | Token revoked/expired → clear session, back to sign-in (keep pairing data) |
| 403 with `trial_expired: true` on bootstrap | Lock POS; if `can_manage_billing`, open billing (`GET /billing`, `POST /billing/checkout`) |
| 403 without POS permission | "You don't have POS access" + sign out |
| `pending_approval: true` after register | Review-pending screen; re-check `GET /auth/me` periodically |
| 429 | Back off; show "Too many attempts, try again shortly" |
| Network errors | Keep form input; retry button |

---

## Acceptance tests

1. `login_method=phone`: sign-up form has no email/password; email sign-up attempt returns 422.
2. `registration_enabled=false`: "Create a new restaurant" hidden; direct `POST /auth/register` returns 403.
3. Register with a number that already exists → `phone_taken` error, CTA to sign in.
4. Phone-only owner sets a POS PIN without `current_password`.
5. New owner with an empty menu lands in the setup wizard; after adding one item `GET /pos/admin/setup` returns `complete: true` and the wizard no longer opens.
6. Saving CGST 2.5 + SGST 2.5 shows both taxes in the returned status.
7. AI scan: upload → `awaiting_confirmation` → confirm → `completed`; items appear in bootstrap.
8. Pairing code expires → `expired` → new code can be generated.
9. Firebase provider, Android/iOS build: send returns `auth_provider: firebase` with no SMS from ServeAI; Firebase texts the code; verify with `id_token` signs in (or returns `phone_token` for register).
10. Firebase provider, desktop build (no `supports_firebase`) with Twilio configured: send returns `auth_provider: server` and the code arrives by Twilio; without Twilio, send returns the "update the app or use email" 422.
