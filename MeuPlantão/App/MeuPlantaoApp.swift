import SwiftUI
import SwiftData

@main
struct MeuPlantaoApp: App {
    // Gerenciador de Autenticação
    @StateObject private var authManager = AuthenticationManager()
    
    // Configuração do Banco de Dados (SwiftData)
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Shift.self,
        ])
        // isStoredInMemoryOnly: false = Salva no disco real do iPhone
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    // Inicialização (Pedir permissão de notificação logo ao abrir)
    init() {
        NotificationManager.shared.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            // Lógica de Segurança:
            if authManager.isUnlocked {
                ContentView()
                    .transition(.opacity) // Efeito suave ao desbloquear
            } else {
                LockView(authManager: authManager)
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
