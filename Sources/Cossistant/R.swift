import Foundation
import SwiftUI

enum R {
  enum RString: String, CaseIterable {
    // MARK: - Navigation
    case support_title
    case conversation_title
    case back
    case close

    // MARK: - Loading States
    case connecting
    case loading_conversations
    case loading_messages
    case creating_conversation

    // MARK: - Errors
    case error_title
    case error_connection
    case retry
    case retry_short
    case discard
    case direct_contact
    case email_copied

    // MARK: - Conversation List
    case new_conversation_cta
    case empty_conversations_title
    case empty_conversations_description
    case load_more
    case swipe_mark_read
    case swipe_rate
    case status_open
    case status_resolved
    case conversation_default_title
    case sender_you
    case sender_default

    // MARK: - Chat
    case empty_chat_title
    case empty_chat_description
    case empty_chat_human_note
    case input_placeholder
    case load_older
    case send
    case sending
    case seen
    case conversation_closed

    // MARK: - Rating
    case rating_prompt
    case rating_comment_placeholder
    case rating_submit
    case rating_thanks

    // MARK: - Typing / AI
    case typing_indicator
    case ai_phase_thinking
    case ai_phase_searching
    case ai_phase_generating
    case ai_phase_default

    // MARK: - Events
    case event_resolved
    case event_reopened
    case event_joined
    case event_left
    case event_assigned
    case event_identified
    case event_participant_requested
    case event_default_actor

    // MARK: - Content Defaults
    case participation_waiting_hint

    // MARK: - Parts
    case reasoning_done
    case reasoning_active
    case file_default_name
    case image_accessibility

    // MARK: - Context Menu
    case context_copy

    // MARK: - Image Viewer
    case image_load_failed

    // MARK: - Support Preparation
    case support_preparation_dismiss

    // MARK: - Attachments
    case attachment_photo_library
    case attachment_choose_file
    case attachment_remove
    case attachment_error_too_large
    case attachment_error_unsupported
    case attachment_error_too_many
    case attachment_uploading
  }

  static func string(_ rstring: RString, _ args: String...) -> String {
    let format = NSLocalizedString(
      rstring.rawValue,
      tableName: nil,
      bundle: .module,
      comment: ""
    )
    guard !args.isEmpty else { return format }
    return String(format: format, arguments: args)
  }
}
