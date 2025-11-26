import SwiftUI

struct TermsView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    Group {
                        Text("Termos de Uso e Privacidade")
                            .medFont(.title2, weight: .bold)
                            .foregroundStyle(Color.medBlue)
                        
                        Text("Última atualização: Novembro 2023")
                            .medFont(.caption).foregroundStyle(.secondary)
                        
                        Divider()
                        
                        SectionTitle("1. Sobre o App")
                        BodyText("O MeuPlantão é uma ferramenta de gerenciamento pessoal para profissionais de saúde. O aplicativo armazena dados localmente no seu dispositivo e na sua conta pessoal do iCloud.")
                        
                        SectionTitle("2. Dados e Privacidade")
                        BodyText("Nós não temos acesso aos seus dados. Todas as informações financeiras, locais de trabalho e horários são armazenados de forma criptografada pela Apple no seu iCloud (CloudKit).")
                        
                        SectionTitle("3. Assinatura Premium")
                        BodyText("O pagamento será cobrado na sua conta Apple ID na confirmação da compra. A assinatura é renovada automaticamente, a menos que seja cancelada pelo menos 24 horas antes do final do período atual.")
                        
                        SectionTitle("4. Isenção de Responsabilidade")
                        BodyText("Este app serve como auxílio organizacional. O usuário é responsável por conferir seus pagamentos junto aos hospitais e contratantes.")
                    }
                }
                .padding()
            }
            .navigationTitle("Termos de Uso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }
    
    func SectionTitle(_ text: String) -> some View {
        Text(text).medFont(.headline).padding(.top, 10)
    }
    
    func BodyText(_ text: String) -> some View {
        Text(text).medFont(.body).foregroundStyle(.secondary)
    }
}
