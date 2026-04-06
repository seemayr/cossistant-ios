import Foundation
import Observation

/// Resolves agent identity (name, image, online status) from userId or aiAgentId.
/// Populated at bootstrap from the website's available agents.
@MainActor
@Observable
public final class AgentRegistry {
  private var humanAgents: [String: HumanAgent] = [:]
  private var aiAgents: [String: AIAgent] = [:]

  // MARK: - Population

  /// Populates the registry from bootstrap response.
  func populate(from website: PublicWebsiteResponse) {
    humanAgents = Dictionary(uniqueKeysWithValues: website.availableHumanAgents.map { ($0.id, $0) })
    aiAgents = Dictionary(uniqueKeysWithValues: website.availableAIAgents.map { ($0.id, $0) })
  }

  // MARK: - Lookup

  /// Resolves agent info from a human agent's userId.
  public func agent(forUserId id: String?) -> AgentInfo? {
    guard let id, let agent = humanAgents[id] else { return nil }
    return AgentInfo(
      id: agent.id,
      name: agent.name ?? "Support",
      image: agent.image,
      kind: .human,
      onlineStatus: Self.onlineStatus(lastSeenAt: agent.lastSeenAt)
    )
  }

  /// Resolves agent info from an AI agent's aiAgentId.
  public func agent(forAIAgentId id: String?) -> AgentInfo? {
    guard let id, let agent = aiAgents[id] else { return nil }
    return AgentInfo(
      id: agent.id,
      name: agent.name,
      image: agent.image,
      kind: .ai,
      onlineStatus: .online
    )
  }

  /// Resolves the sender of a timeline item (checks userId first, then aiAgentId).
  public func sender(for item: TimelineItem) -> AgentInfo? {
    if let info = agent(forUserId: item.userId) { return info }
    if let info = agent(forAIAgentId: item.aiAgentId) { return info }
    return nil
  }

  /// All available agents (human + AI) for display in headers/lists.
  public var allAgents: [AgentInfo] {
    let humans = humanAgents.values.map { agent in
      AgentInfo(
        id: agent.id,
        name: agent.name ?? "Support",
        image: agent.image,
        kind: .human,
        onlineStatus: Self.onlineStatus(lastSeenAt: agent.lastSeenAt)
      )
    }
    let ais = aiAgents.values.map { agent in
      AgentInfo(
        id: agent.id,
        name: agent.name,
        image: agent.image,
        kind: .ai,
        onlineStatus: .online
      )
    }
    return humans + ais
  }

  // MARK: - Online Status

  /// Determines online status from a lastSeenAt timestamp.
  /// - Online: within 15 minutes
  /// - Away: within 1 hour
  /// - Offline: beyond 1 hour or nil
  public nonisolated static func onlineStatus(lastSeenAt: String?) -> OnlineStatus {
    guard let lastSeenAt else { return .offline }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    guard let date = formatter.date(from: lastSeenAt) else { return .offline }
    let elapsed = Date().timeIntervalSince(date)
    if elapsed < 15 * 60 { return .online }
    if elapsed < 60 * 60 { return .away }
    return .offline
  }
}

// MARK: - Types

public struct AgentInfo: Sendable, Identifiable {
  public let id: String
  public let name: String
  public let image: String?
  public let kind: AgentKind
  public let onlineStatus: OnlineStatus
}

public enum AgentKind: Sendable {
  case human
  case ai
}

public enum OnlineStatus: Sendable {
  case online
  case away
  case offline
}
