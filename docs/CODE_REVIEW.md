## Code Review System

When asked to do a code review (of git changes, PRs, or specific files), apply ALL of the following checks.
These rules are designed for a production Swift SDK consumed by apps with millions of users.

### 1. Public API Surface
- New public methods/types are intentional — nothing leaks internal state
- Naming is clear and self-documenting for SDK consumers who don't read our source
- Default parameter values are sensible (`= nil`, `= []`, `= "apple"`)
- `async throws` pattern used consistently (no callbacks, no Combine)
- Breaking changes flagged explicitly — renamed/removed public API requires README update
- Present findings in a table: Change | Breaking? | Notes

### 2. Crash & Safety Analysis
- Check for force unwraps (`!`) and `fatalError()` — forbidden in SDK code
- Check for index-out-of-bounds risks (array access without bounds checking)
- Check for optional handling (guard-let vs force unwrap, nil coalescing defaults)
- Network responses must be treated as untrusted (missing fields, unexpected values)
- WebSocket event parsing must never crash on malformed JSON — fall through to `.unknown`
- Present findings in a table: Check | Result | Notes

### 3. Concurrency & Isolation
- `@MainActor` on all stores and UI-facing types
- `actor` for networking types (RESTClient, WebSocketClient)
- All new model types conform to `Sendable`
- No `@nonisolated(unsafe)` without explicit justification in a comment
- Callbacks crossing isolation boundaries marked `@MainActor @Sendable`
- No `DispatchQueue`, `NSLock`, or `os_unfair_lock` — use structured concurrency
- Check for race conditions in async/await sequences (shared state between awaits)

### 4. Upstream Type Fidelity
- Codable models match the upstream TypeScript types exactly (field names, optionality, enums)
- New fields added as optional to avoid breaking existing API responses
- `CodingKeys` used if Swift naming diverges from JSON keys
- Discriminated union types (TimelineItemPart) handle unknown variants gracefully
- Flag any model change that wasn't verified against the upstream TypeScript types

### 5. Networking
- New endpoints added to `Endpoint.swift` enum with correct path, method, and query params
- HTTP errors include response body in `CossistantError.httpError` for debugging
- No hardcoded URLs outside `Configuration` and `Endpoint`
- Requests include required headers (X-Public-Key, Origin, X-Visitor-Id)
- Guard against `notBootstrapped` state before making authenticated requests

### 6. Performance Analysis
- Flag O(n^2) or worse operations on conversation/timeline lists
- Check for expensive work in computed properties that SwiftUI may re-evaluate frequently
- Verify `.animation(_:value:)` uses targeted value parameters
- WebSocket message parsing should be O(1) per event type (switch, not iteration)
- Pagination logic must not accidentally fetch all pages in a loop
- Present findings in a table: Area | Assessment | Notes

### 7. Localization Completeness
- Follow the project's docs/LOCALIZATION_SYSTEM.md for rules and supported languages
- All user-facing strings use `R.string(.key)` — never hardcoded
- Exception: emoji-only strings and debug log output don't need localization
- New `R.string` keys have translations for ALL 5 languages (en, de, es, fr, it) in Localizable.xcstrings
- Key names describe WHERE/HOW used, not WHAT they say
- Comments added to every new key in xcstrings explaining context

### 8. State Management & SwiftUI
- Stores expose minimal public API — no cursors, no internal state leaking
- `@State` is always `private`
- No `@State` used for values passed into a view — use let properties
- `@ViewBuilder` properties/functions must NOT wrap their entire body in an optional check
- Views receive only the specific data they need, not entire stores when avoidable
- `@Environment` used for design tokens (`cossistantDesign`)

### 9. Error Handling
- New error cases added to `CossistantError` enum when introducing new failure modes
- Errors are not silently swallowed in critical paths (networking, WebSocket, bootstrap)
- `try?` only used when failure is genuinely non-critical (e.g. optional metadata update)
- Error messages include enough context for SDK consumers to debug

### 10. Test Coverage
- New endpoints → `EndpointTests` (path, method, query)
- New models/fields → decode tests + `TestFixtures.swift` JSON updated
- New `TimelineItemPart` variants → case in `TimelineItemPartTests` + fixture JSON
- New WS events → case in `WebSocketEventParserTests` + fixture
- New store logic → pure logic tests (no mocks needed for event handlers)
- Mock-dependent tests in `@Suite(.serialized)` to avoid MockURLProtocol contamination
- All 44+ tests pass (`swift test`)

### 11. Documentation Sync
- Changes to public API → update README.md (methods, properties, configuration, features)
- Changes to architecture → update AGENTS.md
- Changes to localization patterns → update docs/LOCALIZATION_SYSTEM.md
- New public methods/types have doc comments explaining purpose and usage
- README must stay accurate for SDK consumers — flag any drift

### 12. Debug Code Rules
- `print()` calls must use `SupportLogger` — no raw `print()` in production paths
- Debug-only functionality must not be accessible in release builds
- No test API keys, localhost URLs, or placeholder credentials outside test targets

### 13. Code Hygiene
- Flag commented-out code that should be removed before merge
- Flag dead code (unused functions, unreachable paths)
- No deprecated SwiftUI APIs (see swift-style rules: `foregroundStyle` not `foregroundColor`, etc.)
- 2-space indentation, SFSafeSymbols for SF Symbols, `.staticMember` syntax for colors/styles

### 14. Output Format
- Start with a summary table of all changed files and their change type
- Categorize issues by priority: Critical / High / Medium / Low
- Include exact file paths and line numbers for every issue
- End with a clear merge-readiness verdict
