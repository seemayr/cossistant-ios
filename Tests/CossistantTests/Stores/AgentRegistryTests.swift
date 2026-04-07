import Testing
import Foundation
@testable import Cossistant

@Suite("AgentRegistry")
struct AgentRegistryTests {
  @MainActor func makePopulatedRegistry() throws -> AgentRegistry {
    let registry = AgentRegistry()
    let website = try JSONDecoder().decode(PublicWebsiteResponse.self, from: TestFixtures.websiteResponse)
    registry.populate(from: website)
    return registry
  }

  @Test("Resolves human agent by userId")
  @MainActor
  func resolveHumanAgent() throws {
    let registry = try makePopulatedRegistry()
    let agent = registry.agent(forUserId: "01KN8XRQMTFXECQVN4NDNJWCGY")
    #expect(agent != nil)
    #expect(agent?.name == "Test Agent")
    #expect(agent?.kind == .human)
    #expect(agent?.image != nil)
  }

  @Test("Returns nil for unknown userId")
  @MainActor
  func unknownUserId() throws {
    let registry = try makePopulatedRegistry()
    #expect(registry.agent(forUserId: "nonexistent") == nil)
    #expect(registry.agent(forUserId: nil) == nil)
  }

  @Test("Returns nil for unknown aiAgentId")
  @MainActor
  func unknownAiAgentId() throws {
    let registry = try makePopulatedRegistry()
    #expect(registry.agent(forAIAgentId: "nonexistent") == nil)
    #expect(registry.agent(forAIAgentId: nil) == nil)
  }

  @Test("sender(for:) resolves from timeline item")
  @MainActor
  func senderForTimelineItem() throws {
    let registry = try makePopulatedRegistry()
    let item = TimelineItem(
      id: "item_1", conversationId: "c1", organizationId: "o1",
      visibility: .public, type: .message, text: "Hello", tool: nil,
      parts: [], userId: "01KN8XRQMTFXECQVN4NDNJWCGY", aiAgentId: nil,
      visitorId: nil, createdAt: "2026-04-06T10:00:00Z", deletedAt: nil
    )
    let sender = registry.sender(for: item)
    #expect(sender?.name == "Test Agent")
  }

  @Test("sender(for:) returns nil for visitor messages")
  @MainActor
  func senderForVisitorMessage() throws {
    let registry = try makePopulatedRegistry()
    let item = TimelineItem(
      id: "item_2", conversationId: "c1", organizationId: "o1",
      visibility: .public, type: .message, text: "Hi", tool: nil,
      parts: [], userId: nil, aiAgentId: nil,
      visitorId: "vis_001", createdAt: "2026-04-06T10:00:00Z", deletedAt: nil
    )
    #expect(registry.sender(for: item) == nil)
  }

  @Test("allAgents returns all available agents")
  @MainActor
  func allAgents() throws {
    let registry = try makePopulatedRegistry()
    let all = registry.allAgents
    // The test fixture has 1 human agent and 0 AI agents
    #expect(all.count == 1)
    #expect(all[0].kind == .human)
  }

  @Test("Online status thresholds")
  func onlineStatusThresholds() {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    let now = formatter.string(from: Date())
    #expect(AgentRegistry.onlineStatus(lastSeenAt: now) == .online)

    let thirtyMinAgo = formatter.string(from: Date().addingTimeInterval(-30 * 60))
    #expect(AgentRegistry.onlineStatus(lastSeenAt: thirtyMinAgo) == .away)

    let twoHoursAgo = formatter.string(from: Date().addingTimeInterval(-2 * 60 * 60))
    #expect(AgentRegistry.onlineStatus(lastSeenAt: twoHoursAgo) == .offline)

    #expect(AgentRegistry.onlineStatus(lastSeenAt: nil) == .offline)
  }
}
