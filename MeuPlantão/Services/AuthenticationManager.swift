import Foundation
import LocalAuthentication
import Combine // <--- Faltava esta linha para corrigir o erro

class AuthenticationManager: ObservableObject {
    @Published var isUnlocked = false
    @Published var hasError = false
    @Published var errorMessage = ""
    
    // Tenta desbloquear o app
    func authenticate() {
        let context = LAContext()
        var error: NSError?
        
        // Verifica se o dispositivo tem biometria (FaceID/TouchID)
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Desbloqueie para acessar seus plantões."
            
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                
                // A resposta vem numa thread secundária, precisamos voltar para a principal para atualizar a UI
                DispatchQueue.main.async {
                    if success {
                        self.isUnlocked = true
                    } else {
                        self.hasError = true
                        self.errorMessage = "Falha na autenticação."
                    }
                }
            }
        } else {
            // Dispositivo sem biometria ou simulador
            // Liberamos direto para você conseguir testar no computador
            DispatchQueue.main.async {
                self.isUnlocked = true
            }
        }
    }
}
