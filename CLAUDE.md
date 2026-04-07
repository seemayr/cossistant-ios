# Cossistant Swift SDK

Native Swift Package wrapping the [Cossistant](https://github.com/cossistantcom/cossistant) open-source support chat API for SwiftUI apps. Zero external dependencies.

**Target:** Swift 6.2, iOS 17+ / macOS 14+

## Upstream: Cossistant Open Source

The API contract, types, and behavior are defined by the open-source repo. Use `gh` CLI (authenticated) to read source and docs:

```sh
# Read any doc page:
gh api repos/cossistantcom/cossistant/contents/apps/web/content/docs/<path>.mdx --jq '.content' | base64 -d

# Key doc paths:
#   quickstart/index.mdx
#   support-component/index.mdx       — Usage, props, SupportConfig, visitor ID
#   support-component/hooks.mdx       — useSupport, useVisitor, useSupportConfig
#   support-component/primitives.mdx  — Headless UI building blocks
#   support-component/customization.mdx — Styling, compound components

# Read API type definitions (source of truth for our Codable models):
gh api repos/cossistantcom/cossistant/contents/packages/types/src/api/<file>.ts --jq '.content' | base64 -d

# Key type files:
#   visitor.ts        — VisitorMetadata, UpdateVisitorRequest, attribution, activity
#   contact.ts        — IdentifyContactRequest/Response, ContactMetadata
#   conversation.ts   — Create/List/MarkSeen/Typing/Rating request/response
#   timeline-item.ts  — TimelineItem, all Part types (text, reasoning, tool, source, file, image, event)
#   website.ts        — PublicWebsiteResponse, agents, PublicVisitor

# Read enums and realtime event definitions:
gh api repos/cossistantcom/cossistant/contents/packages/types/src/enums.ts --jq '.content' | base64 -d
gh api repos/cossistantcom/cossistant/contents/packages/types/src/realtime-events.ts --jq '.content' | base64 -d

# Browse SDK source (React client, REST client, stores):
gh api repos/cossistantcom/cossistant/contents/packages/core/src --jq '.[].name'
gh api repos/cossistantcom/cossistant/contents/packages/react/src --jq '.[].name'
```

When modifying models or adding endpoints, **always read the upstream TypeScript types first** to ensure field names, optionality, and enums match exactly.

## README

The `README.md` is the public-facing documentation for SDK consumers. **Keep it up to date** when making changes that affect the public API:

- Adding/removing/renaming public methods on `CossistantClient` → update the API section
- Adding new features or capabilities → update the Features list
- Changing `Configuration` parameters → update the Configuration table
- Adding/changing observable store properties or methods → update the Observable Stores table
- Changing requirements (Swift version, platform minimums, dependencies) → update Requirements and Installation

## API Overview

- **REST:** `https://api.cossistant.com/v1` — ~11 endpoints (see `Network/Endpoint.swift`)
- **WebSocket:** `wss://api.cossistant.com/ws` — realtime events (see `WebSocket/WebSocketEvent.swift`)
- **Auth:** `X-Public-Key` header + `Origin` header (required, must match whitelisted domain)
- **Visitor:** Auto-created on bootstrap, ID persisted in UserDefaults

The `Origin` header is mandatory — the API rejects requests without it (returns 403). Test keys accept `http://localhost:3000`. Live keys require a domain whitelisted in the Cossistant dashboard. Native apps should use a whitelisted origin like `https://app.yourapp.com`.

## Project Structure

```
Sources/Cossistant/
├── CossistantClient.swift            — @MainActor entry point: bootstrap(), identify(), disconnect()
├── CossistantError.swift             — Unified error enum (http, decoding, ws, network)
├── Configuration.swift               — apiKey, origin, base URLs
├── Network/
│   ├── RESTClient.swift              — actor, URLSession async/await, headers, error mapping
│   └── Endpoint.swift                — Type-safe enum for all API endpoints
├── WebSocket/
│   ├── WebSocketClient.swift         — actor, URLSessionWebSocketTask, heartbeat (15s), reconnect
│   ├── WebSocketEvent.swift          — Typed enum for all WS events + JSON parser
│   └── ReconnectionPolicy.swift      — Exponential backoff (1s base, 30s max, 20 attempts)
├── Models/
│   ├── Website.swift                 — PublicWebsiteResponse, HumanAgent, AIAgent, PublicVisitor
│   ├── Conversation.swift            — Conversation, status, create/list/seen/typing/rating types
│   ├── TimelineItem.swift            — TimelineItem, 10 part types (discriminated union), delivery status
│   ├── Visitor.swift                 — VisitorMetadata (free-form key/value), MetadataValue literals
│   └── Contact.swift                 — Contact, IdentifyContactRequest/Response
├── Stores/
│   ├── ConversationStore.swift       — @MainActor @Observable: load/loadMore/create + WS handlers
│   ├── TimelineStore.swift           — @MainActor @Observable: messages, pagination, send/seen/typing
│   └── ConnectionStore.swift         — @MainActor @Observable: WS state, typing indicators, AI progress
└── Extensions/
    ├── DeviceInfo.swift              — Native device/OS/app version/locale collection
    └── VisitorStorage.swift          — UserDefaults wrapper for visitorId persistence
```

## Architecture Decisions

| Decision | Choice | Why |
|----------|--------|-----|
| Dependencies | Zero | URLSession + URLSessionWebSocketTask + Codable + @Observable cover everything |
| CossistantClient | `@MainActor` class | Holds @Observable stores; needs same isolation to create them |
| WebSocketClient | `actor` | Concurrent state (task, heartbeat, reconnect) needs serialized access |
| RESTClient | `actor` | Mutable visitorId, session state |
| Stores | `@MainActor @Observable` | SwiftUI-native, simplest concurrency model |
| Bootstrap | Explicit `async throws` | Not lazy — clearer errors and visitor lifecycle |
| Pagination | Encapsulated cursors | Stores expose `loadMore()`, consumers never see cursor strings |

## Testing

**Framework:** Swift Testing (`import Testing`), not XCTest.

**Run:** `swift test` from the package root.

```
Tests/CossistantTests/
├── Helpers/
│   ├── MockURLProtocol.swift         — URLProtocol subclass for intercepting HTTP in tests
│   └── TestFixtures.swift            — JSON fixtures matching real API responses + WS events
├── Models/                           — Codable decoding for all model types and part variants
├── WebSocket/                        — Event parser (all event types + unknown + invalid JSON)
├── Network/
│   ├── EndpointTests.swift           — Path, method, query param correctness for all endpoints
│   └── RESTClientTests.swift         — Headers, visitor ID, error handling, body encoding
│                                       Also includes mock-dependent store tests (load, clear)
├── Stores/                           — Pure logic: WS event handlers, dedup, typing, AI progress
└── Integration/                      — Real API calls with test key (tagged .integration)
```

### Test rules

- **All mock-dependent tests** live in `RESTClientTests.swift` inside a single `@Suite(.serialized)` to avoid `MockURLProtocol` handler contamination across parallel tests.
- **Pure logic tests** (event handlers, dedup, state changes) can run in parallel — they don't use mocks.
- **Integration tests** are tagged `.integration` and hit the real API with the test key.
- **JSON fixtures** in `TestFixtures.swift` represent the API contract. They are copies of real API responses. When upstream types change, update fixtures AND models together.

### Keeping tests in sync with code

When you modify source code, you MUST update corresponding tests:

| Change | Update |
|--------|--------|
| Add/rename a model field | Update `TestFixtures.swift` JSON + model decode tests |
| Add a new `TimelineItemPart` variant | Add case to `TimelineItemPartTests` + add fixture JSON to `allPartsTimeline` |
| Add a new endpoint | Add to `EndpointTests` (path, method, query) |
| Add a new WS event type | Add to `WebSocketEventParserTests` + add fixture in `TestFixtures` |
| Change store logic | Update store event tests + mock network tests if load/send behavior changed |
| Change REST headers or auth | Update `RESTClientTests` header assertions |

After any change, run `swift test` and verify all 44+ tests pass before considering the work done.

## Apple Documentation (sosumi MCP)

Use the `sosumi` MCP tools to look up current Apple APIs, patterns, and WWDC content before implementing new features. Prefer modern, state-of-the-art approaches over legacy patterns.

```
# Search Apple docs:
mcp__sosumi__searchAppleDocumentation(query: "URLSessionWebSocketTask")

# Fetch a specific doc page:
mcp__sosumi__fetchAppleDocumentation(path: "/documentation/foundation/urlsession")
mcp__sosumi__fetchAppleDocumentation(path: "/documentation/observation/observable()")
mcp__sosumi__fetchAppleDocumentation(path: "/documentation/swiftui/managing-model-data-in-your-app")

# Fetch WWDC session transcripts:
mcp__sosumi__fetchAppleVideoTranscript(url: "<wwdc session url>")

# Fetch external docs (e.g. Swift Evolution proposals):
mcp__sosumi__fetchExternalDocumentation(url: "<url>")
```

When implementing new features or evaluating approaches, **always check sosumi first** for:
- Whether a newer API exists (e.g. new concurrency primitives, Observation changes)
- Current best practices from recent WWDC sessions
- HIG guidelines if building any UI components
- Deprecation notices on APIs we currently use

## Building & Testing

**IMPORTANT:** Only run `swift test` when the user explicitly asks for it. Do NOT run tests automatically after every change. Always run `swift build` to verify compilation.

This is a Swift Package — use the CLI directly. No Xcode project needed.

```sh
# Build (debug):
swift build

# Build and show warnings:
swift build 2>&1

# Run all tests:
swift test

# Run tests with verbose output:
swift test --verbose

# Run a specific test suite:
swift test --filter "TimelineItemPart"

# Run only integration tests:
swift test --filter "Integration"

# Clean build artifacts:
swift package clean
```

**Always run `swift build` after code changes** to catch compiler errors, strict concurrency issues, and type mismatches immediately. The build output shows all errors and warnings — read them carefully.

**Always run `swift test` after any change** and verify all tests pass before considering work done. If tests fail, fix them — do not leave broken tests.

The package uses Swift 6.2 strict concurrency. Common issues to watch for:
- `@MainActor` isolation: stores are `@MainActor`, so test helper functions that create them must also be `@MainActor`
- `Sendable` conformance: all models are `Sendable`, new types must be too
- Actor isolation boundaries: hopping between actors requires `await`

## Localization

Full localization guide: [`.claude/LOCALIZATION_SYSTEM.md`](.claude/LOCALIZATION_SYSTEM.md)

Uses the RString pattern (same as PlayUs). All user-facing strings are localized via `R.string(.key)`.

**Supported languages:** English (en), German (de), Spanish (es), French (fr), Italian (it)

**Files:**
- `Sources/Cossistant/R.swift` — `R.string(.key)` accessor + `RString` enum
- `Sources/Cossistant/Resources/Localizable.xcstrings` — translations JSON

**Rules:**
- Never hardcode user-facing strings in views — always use `R.string(.key)`
- Key names describe WHERE/HOW used (not WHAT they say): `error_connection` not `connection_error_text`
- `%@` for parameters: `R.string(.typing_indicator, agentName)`
- Add a `comment` to every key in xcstrings explaining context
- When adding new strings, add translations for ALL supported languages
- R.swift lives outside `Resources/` (SPM treats Resources as non-source)

## Environment

- **Test API key:** set `COSSISTANT_TEST_API_KEY` env var (required for integration tests; mock tests use a placeholder)
- **Test origin:** set `COSSISTANT_TEST_ORIGIN` env var (defaults to `http://localhost:3000`)
- **Swift version:** 6.2 (strict concurrency mode)
- **Minimum deployment:** iOS 17, macOS 14
