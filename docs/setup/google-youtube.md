# Google and YouTube Setup

This is the setup needed to wire a real Google/YouTube account into PhonoDeck.

## What I Need From You

Required:

1. A Google Cloud project for PhonoDeck.
2. YouTube Data API v3 enabled in that project.
3. OAuth consent screen configured for PhonoDeck.
4. An OAuth client of type **Desktop app**.
5. The OAuth **Client ID** copied into local config.
6. The OAuth **Client secret** copied into local config.

Not needed:

- Do not send or commit a client secret.
- Do not send your Google password.
- Do not send access tokens or refresh tokens.

## Create The Google Cloud Project

1. Open https://console.cloud.google.com/.
2. Create/select project: `PhonoDeck`.
3. Open API Library.
4. Enable **YouTube Data API v3**.

## Configure OAuth Consent

1. Open Google Auth Platform / OAuth consent screen.
2. App name: `PhonoDeck`.
3. User support email: your email.
4. Developer contact email: your email.
5. User type: External for normal Gmail accounts, Internal only if you are inside a Google Workspace organization.
6. Publishing status can stay Testing for private development.
7. Add your Google account as a test user if the app is in Testing.

## Create OAuth Client

1. Open Credentials / Clients.
2. Create client.
3. Application type: **Desktop app**.
4. Name: `PhonoDeck macOS`.
5. Copy the Client ID and Client secret.

PhonoDeck uses Google's installed-app flow: system browser + PKCE + loopback callback. Google documents `client_secret` as optional for some installed-app token exchanges, but the OAuth clients created in this project returned `client_secret is missing` without it. Keep the secret local and ignored by Git.

## Local Config

Copy the template:

```sh
cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig
```

Edit `Config/Secrets.xcconfig`:

```xcconfig
GOOGLE_OAUTH_CLIENT_ID = <your-client-id>.apps.googleusercontent.com
GOOGLE_OAUTH_CLIENT_SECRET = <your-client-secret>
```

`Config/Secrets.xcconfig` is ignored by Git. Do not commit it and do not paste the secret into chat.

## Initial Scopes

Start with the narrowest useful account-aware YouTube scope:

```text
https://www.googleapis.com/auth/youtube.readonly
```

This supports user-authorized account/library metadata surfaces. It does not grant native playback, downloads, stream extraction, or offline access to YouTube Music.

## First API Smoke Test Target

After OAuth succeeds, PhonoDeck should call:

```http
GET https://www.googleapis.com/youtube/v3/channels?part=snippet&mine=true
Authorization: Bearer <access-token>
```

If that returns the signed-in user's YouTube channel metadata, account wiring is real.

## Implementation Sequence

1. Local config ingestion for `GOOGLE_OAUTH_CLIENT_ID` exists.
2. PKCE generation exists.
3. Loopback callback server exists.
4. Google OAuth opens in the system browser.
5. Authorization code exchange exists.
6. Refresh/access tokens are stored in Keychain.
7. `channels.list?part=snippet&mine=true` is called after sign-in.
8. Signed-in account state is displayed in the YouTube Music screen.
9. Token revocation still needs a follow-up implementation; local disconnect deletes stored tokens.
