import SwiftUI
import MapKit

struct LocationSearchView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var service = LocationSearchService()
    
    // Closure que vai devolver os dados para a tela AddShiftView
    var onLocationSelected: (String, Double, Double) -> Void
    
    var body: some View {
        NavigationStack {
            List(service.completions, id: \.self) { completion in
                Button {
                    // Ao clicar, buscamos as coordenadas reais
                    service.getCoordinates(for: completion) { lat, long, name in
                        onLocationSelected(name, lat, long)
                        dismiss()
                    }
                } label: {
                    VStack(alignment: .leading) {
                        Text(completion.title)
                            .font(.headline)
                        Text(completion.subtitle)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Buscar Local")
            .searchable(text: $service.searchQuery, prompt: "Digite o nome do hospital...")
        }
    }
}
