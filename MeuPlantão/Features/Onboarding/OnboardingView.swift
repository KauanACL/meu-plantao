import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompleted = false
    @Environment(\.dismiss) var dismiss
    @State private var currentPage = 0
    
    let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "stethoscope",
            title: "Gerencie seus Plantões",
            description: "Organize sua escala médica com calendário visual e lembretes inteligentes",
            color: .medBlue
        ),
        OnboardingPage(
            icon: "arrow.left.arrow.right.circle.fill",
            title: "Controle de Trocas",
            description: "Gerencie quando entra ou sai de plantões, com controle de repasses entre colegas",
            color: .medPurple
        ),
        OnboardingPage(
            icon: "chart.line.uptrend.xyaxis",
            title: "Financeiro Completo",
            description: "Acompanhe pagamentos, repasses e tenha visão clara do seu caixa real",
            color: .medGreen
        ),
        OnboardingPage(
            icon: "calendar.badge.plus",
            title: "Compromissos Pessoais",
            description: "Bloqueie datas para eventos pessoais sem misturar com plantões de trabalho",
            color: .medOrange
        ),
        OnboardingPage(
            icon: "lock.shield.fill",
            title: "Privacidade Total",
            description: "Seus dados ficam criptografados no seu iCloud. Face ID para segurança extra",
            color: .medBlue
        )
    ]
    
    var body: some View {
        ZStack {
            // Gradiente de fundo suave
            LinearGradient(
                colors: [
                    pages[currentPage].color.opacity(0.1),
                    Color(.systemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Skip Button
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button("Pular") {
                            completeOnboarding()
                        }
                        .foregroundStyle(.secondary)
                        .padding()
                    }
                }
                
                // Content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        VStack(spacing: 30) {
                            Spacer()
                            
                            // Ícone Animado
                            Image(systemName: page.icon)
                                .font(.system(size: 100))
                                .foregroundStyle(page.color)
                                .padding()
                                .background(page.color.opacity(0.1))
                                .clipShape(Circle())
                                .scaleEffect(currentPage == index ? 1.0 : 0.8)
                                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: currentPage)
                            
                            VStack(spacing: 12) {
                                Text(page.title)
                                    .medFont(.title, weight: .bold)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                Text(page.description)
                                    .medFont(.body)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }
                            
                            Spacer()
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .animation(.easeInOut, value: currentPage)
                
                // Bottom Button
                Group {
                    if currentPage == pages.count - 1 {
                        Button(action: {
                            HapticManager.shared.notification(.success)
                            completeOnboarding()
                        }) {
                            HStack {
                                Text("Começar")
                                    .medFont(.headline, weight: .bold)
                                Image(systemName: "arrow.right.circle.fill")
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.medBlue, .medPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .medBlue.opacity(0.3), radius: 10, y: 5)
                        }
                        .padding()
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        Button(action: {
                            HapticManager.shared.selection()
                            withAnimation {
                                currentPage += 1
                            }
                        }) {
                            HStack {
                                Text("Próximo")
                                    .medFont(.headline, weight: .bold)
                                Image(systemName: "arrow.right")
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(pages[currentPage].color)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: pages[currentPage].color.opacity(0.3), radius: 10, y: 5)
                        }
                        .padding()
                        .padding(.bottom, 20)
                    }
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentPage)
            }
        }
    }
    
    func completeOnboarding() {
        withAnimation {
            hasCompleted = true
        }
    }
}

struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let color: Color
}

#Preview {
    OnboardingView()
}
