import SwiftUI

// MARK: - Toast Model

enum ToastType {
    case success
    case info
    case warning
}

struct ToastMessage: Identifiable {
    let id = UUID()
    let message: String
    let type: ToastType
    let undoAction: (() -> Void)?

    var displayDuration: TimeInterval {
        undoAction != nil ? 6.0 : 3.0
    }

    init(message: String, type: ToastType = .info, undoAction: (() -> Void)? = nil) {
        self.message = message
        self.type = type
        self.undoAction = undoAction
    }
}

// MARK: - Toast Overlay

struct ToastOverlayView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            ForEach(appState.toasts) { toast in
                ToastBannerView(toast: toast)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.bottom, 40)
        .padding(.horizontal, 20)
        .animation(.easeInOut(duration: 0.3), value: appState.toasts.map(\.id))
        .allowsHitTesting(!appState.toasts.isEmpty)
    }
}

// MARK: - Toast Banner

struct ToastBannerView: View {
    @Environment(AppState.self) private var appState
    let toast: ToastMessage

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 14))
                .foregroundStyle(accentColor)

            Text(toast.message)
                .font(.stardew(size: 16))
                .foregroundStyle(Color.textDark)
                .lineLimit(2)

            if let undoAction = toast.undoAction {
                Button(L.s("common_undo")) {
                    undoAction()
                    appState.dismissToast(id: toast.id)
                }
                .font(.stardew(size: 16))
                .foregroundStyle(Color.stardewBlue)
                .buttonStyle(.plain)
            }

            Button {
                withAnimation {
                    appState.dismissToast(id: toast.id)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.textMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.parchmentAlt)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(accentColor.opacity(0.5), lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        )
    }

    private var iconName: String {
        switch toast.type {
        case .success: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }

    private var accentColor: Color {
        switch toast.type {
        case .success: return .stardewGreen
        case .info: return .accentGold
        case .warning: return .stardewRed
        }
    }
}
