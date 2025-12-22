import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            
            TextField("Search clips...", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .rounded))
                .focused(isFocused)
            
            if !text.isEmpty {
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
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isFocused.wrappedValue ? Color.clipAccent.opacity(0.5) : Color.white.opacity(0.1),
                    lineWidth: 1
                )
        }
        .shadow(color: isFocused.wrappedValue ? Color.clipAccent.opacity(0.2) : .clear, radius: 8)
        .animation(.easeOut(duration: 0.2), value: isFocused.wrappedValue)
    }
}

struct SearchBarPreview: View {
    @State private var text1 = ""
    @State private var text2 = "Hello"
    @FocusState private var focus1: Bool
    @FocusState private var focus2: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            SearchBar(text: $text1, isFocused: $focus1)
            SearchBar(text: $text2, isFocused: $focus2)
        }
        .padding()
        .frame(width: 300)
        .glassEffect()
    }
}

#Preview {
    SearchBarPreview()
}
