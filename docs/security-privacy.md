# Security and Privacy

## Token Handling

- Store Google, Spotify, and Plex tokens in Keychain.
- Never commit client secrets or user tokens.
- Request the narrowest OAuth scopes needed for currently implemented features.
- Provide disconnect/revoke actions for each account.
- Delete cached authorized data when an account is disconnected, within the stricter service requirement when applicable.

## YouTube Requirements

- Provide an accessible privacy policy before user-authorized YouTube features.
- Link to YouTube Terms of Service and Google Privacy Policy where required.
- Do not request future scopes before the feature exists.
- Delete user-authorized data when consent is revoked.
- Refresh or delete stored API data according to YouTube storage windows.

## Spotify Requirements

- Provide account disconnect.
- Delete personal data when the user disconnects Spotify.
- Attribute Spotify content when displayed.
- Do not use Spotify content for ML training, derived metrics, or cross-service stream mixing.

## Plex Requirements

- Treat Plex server tokens as secrets.
- Respect server download permissions.
- Keep downloaded personal media in the app container unless the user explicitly exports it.
- Do not download Plex-provided streaming content.
