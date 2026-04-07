# Cossistant Swift SDK

A community-driven native Swift SDK for integrating [Cossistant](https://cossistant.com/) support chat into SwiftUI apps.

[Cossistant](https://github.com/cossistantcom/cossistant) is an open-source support chat platform by [Anthony Riera](https://x.com/_anthonyriera). The official web widget and server are maintained in the [cossistantcom/cossistant](https://github.com/cossistantcom/cossistant) repository. This SDK provides a native iOS/macOS client built on top of the same API.

- [Cossistant Docs](https://cossistant.com/docs)
- [Official Web Widget](https://github.com/cossistantcom/cossistant)

## Requirements

- Swift 6.2+
- iOS 17+ / macOS 14+
- One dependency: [SFSafeSymbols](https://github.com/SFSafeSymbols/SFSafeSymbols)

## Installation

Add the package via Swift Package Manager:

```swift
dependencies: [
  .package(url: "https://github.com/cossistant/cossistant-swift.git", from: "0.1.0")
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
NavigationStack {
  SupportView(client: client)
}
```

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

## Features

- Real-time messaging via WebSocket with automatic reconnection
- AI agent support with typing indicators and processing state
- Conversation list with pagination
- File and image upload attachments
- Visitor identification and metadata
- Conversation ratings
- Activity tracking (heartbeat, focus)
- Localized UI (English, German)
- Full strict concurrency support (Swift 6)

## API

### CossistantClient

The main entry point. All methods are `async throws`.

```swift
// Bootstrap — call once before using the SDK
try await client.bootstrap()

// Identify visitor (link to a contact)
try await client.identify(
  externalId: "user_123",
  email: "user@example.com",
  name: "Jane Doe",
  metadata: VisitorMetadata(["plan": .string("pro")])
)

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
| `client.conversations` | `conversations`, `sorted`, `hasMore` | `load()`, `loadMore()`, `create(...)` |
| `client.timeline` | `items`, `visibleItems`, `pendingMessages` | `sendMessage(...)`, `markSeen(...)`, `submitRating(...)` |
| `client.connection` | `isConnected`, `typingIndicators`, `aiProcessing` | `isAgentTyping(...)`, `aiStatusMessage(...)` |
| `client.agents` | — | `agent(forUserId:)`, `agent(forAIAgentId:)`, `sender(for:)` |

## License

[MIT](LICENSE)
