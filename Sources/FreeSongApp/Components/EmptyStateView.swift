import SwiftUI

/// A reusable empty state view with icon, title, and optional message.
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String?

    init(icon: String = "music.note", title: String, message: String? = nil) {
        self.icon = icon
        self.title = title
        self.message = message
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.title3.weight(.medium))
                .foregroundStyle(.primary)

            if let message = message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }
}

#Preview("Empty") {
    EmptyStateView(
        icon: "tray",
        title: "No Songs Yet",
        message: "Import a backup or add songs to get started."
    )
}
