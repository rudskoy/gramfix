import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    @Binding var triggerAttention: Bool
    
    @State private var breatheScale: CGFloat = 1.0
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            
            TextField("Search clipboard...", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .rounded))
                .focused(isFocused)
            
            if text.isEmpty {
                HStack(spacing: 2) {
                    Text("⌘")
                        .font(.system(size: 11, weight: .medium))
                    Text("F")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.tertiary)
            } else {
                Button(action: { 
                    withAnimation(.easeOut(duration: 0.2)) {
                        text = "" 
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .focusable(false)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .scaleEffect(breatheScale)
        .glassEffect(in: .rect(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    isFocused.wrappedValue ? Color.clipAccent.opacity(0.4) : .clear,
                    lineWidth: 1.5
                )
        }
        .shadow(color: isFocused.wrappedValue ? Color.clipAccent.opacity(0.15) : .clear, radius: 6)
        .animation(.easeOut(duration: 0.2), value: isFocused.wrappedValue)
        .onChange(of: triggerAttention) { _, _ in
            // Breathing animation: scale up then back to normal
            withAnimation(.easeOut(duration: 0.15)) {
                breatheScale = 1.03
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    breatheScale = 1.0
                }
            }
        }
    }
}

struct SearchBarPreview: View {
    @State private var text1 = ""
    @State private var text2 = "Hello"
    @FocusState private var focus1: Bool
    @FocusState private var focus2: Bool
    @State private var attention1 = false
    @State private var attention2 = false
    
    var body: some View {
        VStack(spacing: 20) {
            SearchBar(text: $text1, isFocused: $focus1, triggerAttention: $attention1)
            SearchBar(text: $text2, isFocused: $focus2, triggerAttention: $attention2)
        }
        .padding()
        .frame(width: 300)
        .glassEffect()
    }
}

#Preview {
    SearchBarPreview()
}
