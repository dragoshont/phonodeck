# Developer OAuth Credentials

This page explains how to create and store PhonoDeck OAuth credentials for local development, CI, and future runtime services.

## Do You Need These To Build?

No. Normal build, test, and unsigned package commands do not need OAuth credentials:

```sh
make build
make test
make package-local
```

Those commands are designed to work with empty OAuth values. `make package-local` also forces `GOOGLE_OAUTH_CLIENT_SECRET` empty so the local unsigned package does not embed a secret.

You need Google OAuth credentials only for local sign-in and live YouTube Data API validation.

## Create Google OAuth Credentials

1. Open Google Cloud Console.
2. Create or select a Google Cloud project for PhonoDeck.
3. Enable YouTube Data API v3.
4. Configure Google Auth Platform / OAuth consent screen.
5. Create an OAuth client of type **Desktop app**.
6. Copy the client ID and client secret into local ignored config only.

## Store Credentials Locally

Create the local ignored file:

```sh
cd /path/to/phonodeck
cp -n Config/Secrets.xcconfig.example Config/Secrets.xcconfig
```

Edit it:

```xcconfig
GOOGLE_OAUTH_CLIENT_ID = <desktop-client-id>.apps.googleusercontent.com
GOOGLE_OAUTH_CLIENT_SECRET = <desktop-client-secret>
```

Do not paste real values into GitHub issues, docs, commits, screenshots, chat, or run artifacts.

## Safe Local Update One-Liner

Use this when you have a rotated secret and want to update local config without printing it:

```sh
cd /path/to/phonodeck && mkdir -p Config && cp -n Config/Secrets.xcconfig.example Config/Secrets.xcconfig && read -s -p "Google OAuth client secret: " secret; printf "\n"; /usr/bin/sed -i '' "s|^GOOGLE_OAUTH_CLIENT_SECRET *=.*|GOOGLE_OAUTH_CLIENT_SECRET = ${secret}|" Config/Secrets.xcconfig; unset secret
```

Then verify:

```sh
make release-preflight
make package-local
```

## GitHub Secrets

Use GitHub Secrets only when a GitHub Actions workflow actually needs credentials.

Current PhonoDeck build/test/package workflows do not need them. Add these only for future CI live OAuth smoke tests or release-time injection:

```text
GOOGLE_OAUTH_CLIENT_ID
GOOGLE_OAUTH_CLIENT_SECRET
```

Do not use GitHub Secrets as a runtime secret store for a distributed desktop app.

## Key Vault / KV

Use Key Vault / KV only if PhonoDeck later has a backend or operational service that reads secrets at runtime.

For Azure Key Vault, after logging in with `az login`, set a vault name and write values without printing them:

```sh
cd /path/to/phonodeck
export PHONODECK_KEY_VAULT_NAME=<your-key-vault-name>

client_id=$(awk -F= '/^GOOGLE_OAUTH_CLIENT_ID[[:space:]]*=/{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2}' Config/Secrets.xcconfig)
client_secret=$(awk -F= '/^GOOGLE_OAUTH_CLIENT_SECRET[[:space:]]*=/{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2}' Config/Secrets.xcconfig)

az keyvault secret set --vault-name "$PHONODECK_KEY_VAULT_NAME" --name phonodeck-google-oauth-client-id --value "$client_id" --output none
az keyvault secret set --vault-name "$PHONODECK_KEY_VAULT_NAME" --name phonodeck-google-oauth-client-secret --value "$client_secret" --output none

unset client_id client_secret
```

Do not run the Key Vault commands unless the vault exists and you intend to store these credentials centrally.

## Rotation Policy

Rotate for cause, not on a noisy schedule. Rotate when a value appears in logs/chat/terminal output, is copied somewhere unintended, a machine/account is compromised, or before serious release validation if handling was messy.

After rotation:

1. Update `Config/Secrets.xcconfig` locally.
2. Update GitHub Secrets only if CI needs them.
3. Update Key Vault only if a backend/runtime service needs them.
4. Run `make release-preflight && make package-local`.