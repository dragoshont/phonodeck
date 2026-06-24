# Contracts

Contracts keep native Apple, native Windows, and web implementations aligned without forcing them to share UI code.

Current contracts:

- `provider-policy.json` — source capability truth and policy boundaries.
- `source-capabilities.schema.json` — schema for source capabilities.
- `playback-session.schema.json` — schema for playback/session state exchanged across implementations or fixtures.

Contracts should be treated as product truth. Platform code can be native, but it must not contradict these files.