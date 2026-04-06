import Testing
import Foundation
@testable import Cossistant

@Suite("TimelineItemPart Decoding")
struct TimelineItemPartTests {
  let decoder = JSONDecoder()

  @Test("Decodes all 10 part types + unknown")
  func decodesAllPartTypes() throws {
    let response = try decoder.decode(TimelineResponse.self, from: TestFixtures.allPartsTimeline)
    let parts = response.items[0].parts
    #expect(parts.count == 11)

    // Text
    if case .text(let part) = parts[0] {
      #expect(part.text == "Hello")
      #expect(part.state == "done")
    } else {
      Issue.record("Expected .text, got \(parts[0])")
    }

    // Reasoning
    if case .reasoning(let part) = parts[1] {
      #expect(part.text == "Thinking about this...")
    } else {
      Issue.record("Expected .reasoning")
    }

    // Tool
    if case .tool(let part) = parts[2] {
      #expect(part.toolName == "searchKnowledge")
      #expect(part.state == "result")
    } else {
      Issue.record("Expected .tool")
    }

    // Source URL
    if case .sourceUrl(let part) = parts[3] {
      #expect(part.url == "https://docs.example.com/help")
      #expect(part.title == "Help docs")
    } else {
      Issue.record("Expected .sourceUrl")
    }

    // Source Document
    if case .sourceDocument(let part) = parts[4] {
      #expect(part.title == "Guide")
      #expect(part.mediaType == "application/pdf")
    } else {
      Issue.record("Expected .sourceDocument")
    }

    // Step Start
    if case .stepStart = parts[5] {
      // ok
    } else {
      Issue.record("Expected .stepStart")
    }

    // File
    if case .file(let part) = parts[6] {
      #expect(part.filename == "report.pdf")
      #expect(part.size == 1024)
    } else {
      Issue.record("Expected .file")
    }

    // Image
    if case .image(let part) = parts[7] {
      #expect(part.width == 800)
      #expect(part.height == 600)
    } else {
      Issue.record("Expected .image")
    }

    // Event
    if case .event(let part) = parts[8] {
      #expect(part.eventType == "resolved")
    } else {
      Issue.record("Expected .event")
    }

    // Metadata
    if case .metadata(let part) = parts[9] {
      #expect(part.source == "widget")
    } else {
      Issue.record("Expected .metadata")
    }

    // Unknown
    if case .unknown = parts[10] {
      // ok — gracefully handles future types
    } else {
      Issue.record("Expected .unknown for unrecognized type")
    }
  }

  @Test("Text part round-trips through encode/decode")
  func textPartRoundTrip() throws {
    let original = TextPart(text: "Hello world", state: "done")
    let part = TimelineItemPart.text(original)
    let data = try JSONEncoder().encode(part)
    let decoded = try decoder.decode(TimelineItemPart.self, from: data)

    if case .text(let result) = decoded {
      #expect(result.text == "Hello world")
      #expect(result.state == "done")
    } else {
      Issue.record("Round-trip failed")
    }
  }
}
