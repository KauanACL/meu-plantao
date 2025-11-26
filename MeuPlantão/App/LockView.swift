import SwiftUI

struct LockView: View {
    @ObservedObject var authManager: AuthenticationManager
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
                .padding()
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())
            
            VStack(spacing: 8) {
                // Antes: Text("MedPlantão Protegido")
                Text("MeuPlantão Protegido")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Seus dados financeiros estão seguros.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                authManager.authenticate()
            }) {
                HStack {
                    Image(systemName: "faceid")
                    Text("Desbloquear com Face ID")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 50)
        }
        .onAppear {
            // Tenta autenticar assim que a tela aparece
            authManager.authenticate()
        }
    }
}
