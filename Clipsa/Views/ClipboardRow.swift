import SwiftUI

struct ClipboardRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 10) {
            // Type icon
            ClipboardTypeIcon(type: item.type)
            
            // Content - single line, compact (use smart preview if available)
            Text(item.smartPreview)
                .font(.clipMono)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer(minLength: 4)
            
            // LLM indicators
            HStack(spacing: 6) {
                // Simple processing indicator
                if item.llmProcessing {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(LinearGradient.accentGradient)
                }
                
                // Show content type if available
                if let contentType = item.llmContentType, !item.llmProcessing {
                    Text(contentType)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(.clipContentType)
                }
                
                // Time - right aligned
                Text(item.formattedTime)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.clipSurfaceHover : (isHovered ? Color.clipSurface : Color.clear))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isSelected ? Color.clipAccent.opacity(0.4) : Color.white.opacity(isHovered ? 0.08 : 0),
                    lineWidth: 1
                )
        }
        .shadow(color: isSelected ? Color.clipAccent.opacity(0.15) : .clear, radius: 8)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

#Preview {
    VStack(spacing: 4) {
        ClipboardRow(
            item: ClipboardItem(content: "Hello, this is a sample clipboard item with some text content."),
            isSelected: false
        )
        ClipboardRow(
            item: ClipboardItem(content: "Selected item here", type: .text, appName: "Safari"),
            isSelected: true
        )
        ClipboardRow(
            item: ClipboardItem(content: "Another item", type: .image),
            isSelected: false
        )
    }
    .padding()
    .glassEffect()
}
