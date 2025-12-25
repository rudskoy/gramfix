import SwiftUI

struct ClipboardRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 6) {
            // Type icon
            ClipboardTypeIcon(type: item.type)
            
            // Content - single line, compact (use smart preview if available)
            Text(item.smartPreview)
                .font(.clipBody)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer(minLength: 4)
            
            // LLM indicators
            HStack(spacing: 6) {
                // Simple processing indicator
                if item.isProcessing {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(LinearGradient.accentGradient)
                }
                
                // Show prompt completion status if processing or has results
                if item.hasAnyPromptResult && !item.isProcessing {
                    Text("\(item.completedPromptCount)/\(item.totalPromptCount)")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(.clipContentType)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            if isSelected {
                Color.clear
                    .glassEffect(in: .rect(cornerRadius: 8, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            } else if isHovered {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { isHovered = $0 }
    }
}

#Preview {
    VStack(spacing: 2) {
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
