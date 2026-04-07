import SwiftUI
import SFSafeSymbols
#if canImport(MessageUI)
import MessageUI
#endif

/// Reusable button that opens a mail composer to contact support directly.
/// Used as a fallback when the Cossistant API is unreachable.
///
/// - iOS: Uses `MFMailComposeViewController` if available, falls back to `mailto:` URL.
/// - macOS: Uses `mailto:` URL to open the default mail client.
/// - Final fallback: Copies the email address to the clipboard.
struct DirectContactButton: View {
  let email: String
  var subject: String?

  @State private var isCopied = false
  #if canImport(MessageUI)
  @State private var isShowingMailComposer = false
  #endif

  var body: some View {
    Button {
      sendMail()
    } label: {
      Label(
        isCopied ? R.string(.email_copied) : R.string(.direct_contact),
        systemSymbol: isCopied ? .checkmarkCircleFill : .envelopeFill
      )
    }
    .buttonStyle(HapticButtonStyle(haptic: .buttonTap))
    #if canImport(MessageUI)
    .sheet(isPresented: $isShowingMailComposer) {
      MailComposerView(
        recipient: email,
        subject: subject ?? "",
        onDismiss: { isShowingMailComposer = false }
      )
    }
    #endif
  }

  private func sendMail() {
    #if canImport(MessageUI)
    if MFMailComposeViewController.canSendMail() {
      isShowingMailComposer = true
      return
    }
    #endif

    openMailtoURL()
  }

  private func openMailtoURL() {
    var components = URLComponents()
    components.scheme = "mailto"
    components.path = email
    if let subject {
      components.queryItems = [URLQueryItem(name: "subject", value: subject)]
    }

    #if os(iOS)
    guard let url = components.url else {
      copyToPasteboard()
      return
    }
    UIApplication.shared.open(url) { success in
      if !success {
        copyToPasteboard()
      }
    }
    #elseif os(macOS)
    guard let url = components.url else {
      copyToPasteboard()
      return
    }
    if !NSWorkspace.shared.open(url) {
      copyToPasteboard()
    }
    #endif
  }

  private func copyToPasteboard() {
    #if os(iOS)
    UIPasteboard.general.string = email
    #elseif os(macOS)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(email, forType: .string)
    #endif

    withAnimation {
      isCopied = true
    }

    Task {
      try? await Task.sleep(for: .seconds(2))
      withAnimation {
        isCopied = false
      }
    }
  }
}

// MARK: - Mail Composer (iOS)

#if canImport(MessageUI)
private struct MailComposerView: UIViewControllerRepresentable {
  let recipient: String
  let subject: String
  let onDismiss: () -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(onDismiss: onDismiss)
  }

  func makeUIViewController(context: Context) -> MFMailComposeViewController {
    let composer = MFMailComposeViewController()
    composer.mailComposeDelegate = context.coordinator
    composer.setToRecipients([recipient])
    composer.setSubject(subject)
    return composer
  }

  func updateUIViewController(_: MFMailComposeViewController, context _: Context) {}

  final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
    let onDismiss: () -> Void

    init(onDismiss: @escaping () -> Void) {
      self.onDismiss = onDismiss
    }

    func mailComposeController(
      _ controller: MFMailComposeViewController,
      didFinishWith _: MFMailComposeResult,
      error _: Error?
    ) {
      controller.dismiss(animated: true)
      onDismiss()
    }
  }
}
#endif
