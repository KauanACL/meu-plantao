import SwiftUI

// --- 1. PALETA DE CORES ---
extension Color {
    static let medBlue = Color(hex: "4A90E2")
    static let medPurple = Color(hex: "5C6BC0")
    static let medGreen = Color(hex: "66BB6A")
    static let medOrange = Color(hex: "FFA726")
    static let medRed = Color(hex: "EF5350")
    
    // Inicializador Hexadecimal
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// --- 2. MODIFIERS VISUAIS ---

struct MedCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

struct MedInputModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .font(.system(.body, design: .rounded)) // Usando direto para evitar ciclo
            .foregroundStyle(.primary)
    }
}

// --- 3. EXTENSÕES DE VIEW ---

extension View {
    func medCard() -> some View {
        modifier(MedCardStyle())
    }
    
    func medInput() -> some View {
        modifier(MedInputModifier())
    }
    
    // Fonte Personalizada
    func medFont(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> some View {
        self.font(.system(style, design: .rounded).weight(weight))
    }
}

// Extensão específica para Text para facilitar o uso
extension Text {
    func medFont(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Text {
        self.font(.system(style, design: .rounded).weight(weight))
    }
}
