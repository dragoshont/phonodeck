# Google OAuth Findings

Checked against official Google OAuth docs on 2026-06-18.

## Findings

- For macOS/desktop apps with browser access, Google recommends the installed-app OAuth flow with a system browser and local loopback redirect.
- Google OAuth policy disallows embedded user agents such as `WKWebView` for Google sign-in.
- Installed apps are assumed unable to keep secrets. The docs list `client_secret` as optional in the installed-app token exchange, but the Desktop OAuth client created for PhonoDeck returned `client_secret is missing` when omitted.
- The TV / Limited Input device flow is not the preferred flow for macOS apps. Its polling step explicitly requires `client_secret` in the YouTube device-flow docs.
- Therefore PhonoDeck should use the Desktop OAuth client with PKCE, loopback redirect, and a local-only client secret stored in `Config/Secrets.xcconfig`.
- The device-code implementation was removed after this finding so the app has one supported Google sign-in path.

## Local Secret Handling

- `Config/Secrets.xcconfig` must stay ignored by Git.
- Do not paste client secrets or tokens into chat.
- Store OAuth tokens in Keychain only.
