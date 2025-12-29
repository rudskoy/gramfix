import SwiftUI
import AppKit

/// Custom alert view that mimics NSAlert appearance with app icon
struct CustomAlertView: View {
    let title: String
    let message: String
    let primaryButtonTitle: String
    let primaryButtonAction: () -> Void
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            // Background overlay with glassy blur
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)
                .onTapGesture {
                    // Don't dismiss on background tap (like NSAlert)
                }
            
            // Alert content with glassy effect
            HStack(spacing: 20) {
                // App icon (left side)
                if let appIcon = NSApp.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 64, height: 64)
                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                }
                
                // Text content (right side)
                VStack(alignment: .leading, spacing: 12) {
                    // Title
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    // Message
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Buttons
                    HStack(spacing: 8) {
                        Spacer()
                        Button(primaryButtonTitle) {
                            primaryButtonAction()
                            isPresented = false
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding(.top, 4)
                }
                .frame(minWidth: 300, maxWidth: 400)
            }
            .padding(20)
            .glassEffect(in: .rect(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 1.5)
            }
            .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}

/// View modifier to present custom alert
extension View {
    func customAlert(
        _ title: String,
        message: String,
        primaryButton: String,
        isPresented: Binding<Bool>,
        primaryAction: @escaping () -> Void
    ) -> some View {
        ZStack {
            self
            if isPresented.wrappedValue {
                CustomAlertView(
                    title: title,
                    message: message,
                    primaryButtonTitle: primaryButton,
                    primaryButtonAction: primaryAction,
                    isPresented: isPresented
                )
                .zIndex(1000)
            }
        }
    }
}

