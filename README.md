# Cossistant Swift SDK

A community-driven native Swift SDK for integrating [Cossistant](https://cossistant.com/) support chat into SwiftUI apps.

[Cossistant](https://github.com/cossistantcom/cossistant) is an open-source support chat platform by [Anthony Riera](https://x.com/_anthonyriera). The official web widget and server are maintained in the [cossistantcom/cossistant](https://github.com/cossistantcom/cossistant) repository. This SDK provides a native iOS/macOS client built on top of the same API.

- [Cossistant Docs](https://cossistant.com/docs)
- [Official Web Widget](https://github.com/cossistantcom/cossistant)

## Requirements

- Swift 6.2+
- iOS 17+ / macOS 14+
- Dependencies: [SFSafeSymbols](https://github.com/SFSafeSymbols/SFSafeSymbols), [ULID.swift](https://github.com/yaslab/ULID.swift)

## Installation

Add the package via Swift Package Manager:

```swift
dependencies: [
  .package(url: "https://github.com/seemayr/cossistant-ios.git", from: "0.1.0")
]
```

Or in Xcode: **File > Add Package Dependencies** and enter the repository URL.

## Quick Start

```swift
import Cossistant

// 1. Create the client
let client = CossistantClient(
  configuration: Configuration(
    apiKey: "pk_live_YOUR_KEY",
    origin: "https://your-whitelisted-domain.com"
  )
)

// 2. Show the support view (push into an existing NavigationStack)
SupportView(client: client)
```

If the parent view does not already provide a `NavigationStack`, use `SupportNavigationView` instead — it wraps `SupportView` with its own navigation container:

```swift
SupportNavigationView(client: client, onDismiss: { dismiss() })
```

> **Note:** Both `SupportView` and `SupportNavigationView` call `bootstrap()` automatically — no manual setup needed. The `client.bootstrap()` method in the [API section](#cossistantclient) below is for programmatic usage without the built-in views.

### Auto-Create with Context

Skip the conversation list and go straight to a new conversation with metadata:

```swift
SupportView(
  client: client,
  autoCreate: SupportContext(
    source: "game_loading",
    metadata: VisitorMetadata([
      "gameId": .string(game.id),
      "groupId": .string(group.id),
    ]),
    initialMessage: "I'm having trouble loading a game."
  )
)
```

## Configuration

| Parameter | Required | Description |
|-----------|----------|-------------|
| `apiKey` | Yes | Your public API key (`pk_live_...` or `pk_test_...`) |
| `origin` | Yes | Must match a whitelisted domain in your Cossistant dashboard. Test keys accept `http://localhost:3000`. |
| `apiBaseURL` | No | REST API base URL (defaults to `https://api.cossistant.com/v1`) |
| `webSocketBaseURL` | No | WebSocket base URL (defaults to `wss://api.cossistant.com/ws`) |
| `supportEmail` | No | When set, shows a "Direct Contact" button in error views |

## Customization

Customize the visual appearance of the support UI with `CossistantDesign`:

```swift
SupportNavigationView(client: client)
  .cossistantDesign(CossistantDesign(accentColor: .purple, fontDesign: .rounded))
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `accentColor` | App's accent color | Color for CTA buttons, visitor message bubbles, and interactive elements |
| `fontDesign` | `.default` | Font design applied to all text (`.rounded`, `.serif`, `.monospaced`) |

Both parameters are optional — pass only what you want to change.

### Reading Design Tokens

Inside your own views you can read the current design tokens from the environment:

```swift
@Environment(\.cossistantDesign) private var design

var body: some View {
  Text("Styled text")
    .foregroundStyle(design.accentColor)
    .fontDesign(design.fontDesign)
}
```

## Features

- Real-time messaging via WebSocket with automatic reconnection
- AI agent support with typing indicators and processing state
- Conversation list with pagination
- File and image upload attachments with fullscreen image viewer
- Long-press copy on message bubbles
- Visitor identification and metadata
- Conversation ratings
- Activity tracking (heartbeat, focus)
- Localized UI (English, German, Spanish, French, Italian)
- Full strict concurrency support (Swift 6)

## API

### CossistantClient

The main entry point. When using `SupportView` or `SupportNavigationView`, bootstrap is called automatically. These methods are for programmatic usage without the built-in views.

```swift
// Bootstrap — required before calling other methods (views handle this automatically)
try await client.bootstrap()

// Pre-configure identity (applied automatically during bootstrap)
client.setIdentity(
  externalId: "user_123",
  email: "user@example.com",
  name: "Jane Doe"
)

// Or identify after bootstrap
try await client.identify(
  externalId: "user_123",
  email: "user@example.com",
  name: "Jane Doe",
  metadata: VisitorMetadata(["plan": .string("pro")])
)

// Clear identity on logout
client.clearIdentity()

// Update visitor metadata (merge, not replace)
try await client.updateMetadata(VisitorMetadata([
  "lastScreen": .string("settings"),
  "appVersion": .string("2.1.0"),
]))

// Activity tracking
try await client.sendActivity(sessionId: "session_abc")

// Disconnect when done
await client.disconnect()
```

### Observable Stores

All stores are `@Observable` and `@MainActor`-isolated for direct use in SwiftUI views.

| Store | Key Properties | Key Methods |
|-------|---------------|-------------|
| `client.conversations` | `conversations`, `sorted`, `hasMore`, `hasUnread` | `load()`, `loadMore()`, `create(...)` |
| `client.timeline` | `items`, `visibleItems`, `pendingMessages` | `sendMessage(...)`, `markSeen(...)`, `submitRating(...)` |
| `client.connection` | `isConnected`, `typingIndicators`, `aiProcessing` | `isAgentTyping(...)`, `aiStatusMessage(...)` |
| `client.agents` | — | `agent(forUserId:)`, `agent(forAIAgentId:)`, `sender(for:)` |

## Supported Languages

| | Language | Code |
|---|----------|------|
| 🇬🇧 | English | `en` |
| 🇩🇪 | German | `de` |
| 🇪🇸 | Spanish | `es` |
| 🇫🇷 | French | `fr` |
| 🇮🇹 | Italian | `it` |

## License

[MIT](LICENSE)
