import SwiftUI
import SwiftData

@main
struct MeuPlantaoApp: App {
    // Gerenciador de Autenticação
    @StateObject private var authManager = AuthenticationManager()
    
    // Onboarding
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    // Configuração do Banco de Dados (SwiftData)
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Shift.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    // Inicialização
    init() {
        NotificationManager.shared.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasCompletedOnboarding {
                    OnboardingView()
                        .transition(.opacity)
                } else if authManager.isUnlocked {
                    ContentView()
                        .transition(.opacity)
                } else {
                    LockView(authManager: authManager)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: hasCompletedOnboarding)
            .animation(.easeInOut(duration: 0.3), value: authManager.isUnlocked)
        }
        .modelContainer(sharedModelContainer)
    }
}
