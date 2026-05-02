import SwiftUI
import AppKit

struct PopoverView: View {
    @Bindable var appState: AppState
    let onRefresh: () -> Void
    let onSignIn: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 380, height: 480)
    }

    private var header: some View {
        HStack {
            Text("Inbox")
                .font(.headline)
            Spacer()
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .disabled(appState.loadState == .loading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        switch (appState.authState, appState.loadState, appState.emails.isEmpty) {
        case (.signedOut, _, _):
            connectGmailEmpty
        case (.needsReauthorization, _, _):
            reauthorizationEmpty
        case (_, .loading, true):
            loadingState
        case (_, .failed(let error), _):
            errorState(error)
        case (_, _, true):
            inboxZeroEmpty
        default:
            messagesList
        }
    }

    private var messagesList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(appState.emails) { message in
                    MessageRow(message: message, onClick: {
                        if case .signedIn(let email) = appState.authState {
                            let url = NotificationManager.gmailURL(email: email, messageId: message.id)
                            NSWorkspace.shared.open(url)
                        }
                    })
                    Divider()
                }
            }
        }
    }

    private var connectGmailEmpty: some View {
        VStack(spacing: 12) {
            Image(systemName: "envelope")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Connect Gmail")
                .font(.headline)
            Text("Sign in to your Google account to start receiving notifications.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Connect Gmail", action: onSignIn)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var reauthorizationEmpty: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)
            Text("Reauthorization Required")
                .font(.headline)
            Text("Your Gmail session expired. Please sign in again.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Reauthorize", action: onSignIn)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingState: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var inboxZeroEmpty: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Inbox Zero")
                .font(.headline)
            Text("No unread mail.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ error: AppError) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(.red)
            Text("Something went wrong")
                .font(.headline)
            Text(message(for: error))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry", action: onRefresh)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            if case .signedIn(let email) = appState.authState {
                Text(email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func message(for error: AppError) -> String {
        switch error {
        case .auth(.refreshTokenInvalid):
            return "Your Gmail session expired."
        case .network:
            return "Network unavailable."
        case .api(.rateLimited):
            return "Too many requests. Backing off."
        case .api(.serverError(let status)):
            return "Server error (HTTP \(status))."
        case .api:
            return "Gmail API error."
        case .notification:
            return "Notification error."
        case .auth:
            return "Authentication error."
        }
    }
}

private struct MessageRow: View {
    let message: EmailMessage
    let onClick: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onClick) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(displayFrom)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Spacer()
                    Text(relativeTime)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Text(message.subject.isEmpty ? "(no subject)" : message.subject)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary.opacity(0.8))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHovered ? Color.accentColor.opacity(0.12) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var displayFrom: String {
        // Gmail "From" header is typically "Name <email@x>"; strip the email.
        if let open = message.from.firstIndex(of: "<") {
            return message.from[..<open].trimmingCharacters(in: .whitespaces)
        }
        return message.from.isEmpty ? "(unknown sender)" : message.from
    }

    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: message.internalDate, relativeTo: Date())
    }
}
