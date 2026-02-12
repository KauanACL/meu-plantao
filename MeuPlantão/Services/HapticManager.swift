import UIKit

/// Gerenciador centralizado de feedback háptico
/// Uso: HapticManager.shared.impact() ou .notification(.success)
class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    /// Feedback de impacto físico (leve, médio, pesado)
    /// - Parameter style: Intensidade do impacto (.light, .medium, .heavy, .soft, .rigid)
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    /// Feedback de notificação (sucesso, erro, aviso)
    /// - Parameter type: Tipo de notificação (.success, .warning, .error)
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    
    /// Feedback de seleção (mudança de opção em pickers, calendário, etc)
    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}
