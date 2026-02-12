import Foundation
import MapKit
import Combine

class LocationSearchService: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var searchQuery = ""
    @Published var completions: [MKLocalSearchCompletion] = []
    
    private var completer: MKLocalSearchCompleter
    private var cancellable: AnyCancellable?
    
    override init() {
        completer = MKLocalSearchCompleter()
        super.init()
        completer.delegate = self
        // Filtra para buscar locais de interesse (hospitais, clínicas) e endereços
        completer.resultTypes = .pointOfInterest
        
        // Ouve as mudanças no texto digitado e atualiza o completer
        cancellable = $searchQuery.sink { [weak self] newQuery in
            self?.completer.queryFragment = newQuery
        }
    }
    
    // MARK: - MKLocalSearchCompleterDelegate
    
    /// Método do Delegate: Chamado quando o Apple Maps retorna resultados
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.completions = completer.results
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        // Pode tratar erros aqui se quiser
        print("Erro na busca de localização: \(error.localizedDescription)")
    }
    
    // MARK: - Helper Functions
    
    /// Função auxiliar para transformar o resultado (que só tem texto) em Coordenadas
    /// - Parameters:
    ///   - completion: Resultado da busca do MKLocalSearchCompleter
    ///   - completionHandler: Closure que retorna (latitude, longitude, nome)
    func getCoordinates(
        for completion: MKLocalSearchCompletion,
        completionHandler: @escaping (Double, Double, String) -> Void
    ) {
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { response, error in
            // 1. Verificamos se há erro
            if let error = error {
                print("Erro ao buscar coordenadas: \(error.localizedDescription)")
                return
            }
            
            // 2. Verificamos se temos um item de mapa
            guard let mapItem = response?.mapItems.first else {
                print("Nenhum resultado encontrado")
                return
            }
            
            // 3. iOS 26+: .location agora retorna CLLocation direto (não é mais opcional)
            // Então podemos acessar diretamente sem guard/if let
            let location = mapItem.location
            let coordinate = location.coordinate
            
            // 4. Retorna Latitude, Longitude e o Nome completo
            completionHandler(
                coordinate.latitude,
                coordinate.longitude,
                completion.title
            )
        }
    }
}
