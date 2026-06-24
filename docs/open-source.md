# Open Source

PhonoDeck is open source under the MIT license.

## Commercial Builds

The official signed App Store builds may be paid. Charging for a signed build, distribution, updates, and support does not make the source closed. The source code remains available under MIT for people who want to build it themselves.

## Boundaries

- Do not commit provider secrets, Apple signing material, tokens, provisioning profiles, app-specific passwords, or local config.
- Do not add private service APIs, scraped endpoints, hidden players, stream extraction, or unauthorized downloads.
- App Store, Microsoft Store, and web distribution artifacts may have platform-specific signing and packaging steps that are not stored in the repo.

## Platform Strategy

PhonoDeck uses native code per platform:

- Apple platforms: Swift and SwiftUI.
- Windows: .NET / WinUI.
- Web: React / TypeScript.

Shared contracts, fixtures, source policy, and documentation keep the implementations aligned.