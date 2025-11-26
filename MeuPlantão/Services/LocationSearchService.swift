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
    
    // Método do Delegate: Chamado quando o Apple Maps retorna resultados
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.completions = completer.results
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        // Pode tratar erros aqui se quiser
        print("Erro na busca: \(error.localizedDescription)")
    }
    
    // Função auxiliar para transformar o resultado (que só tem texto) em Coordenadas
    // Função auxiliar para transformar o resultado (que só tem texto) em Coordenadas
        func getCoordinates(for completion: MKLocalSearchCompletion, completionHandler: @escaping (Double, Double, String) -> Void) {
            let searchRequest = MKLocalSearch.Request(completion: completion)
            let search = MKLocalSearch(request: searchRequest)
            
            search.start { response, error in
                // 1. Verificamos se temos um item de mapa
                guard let mapItem = response?.mapItems.first else { return }
                
                // 2. Acessamos a localização (CLLocation) dentro do placemark
                // É aqui que corrigimos o warning: usamos .location ao invés de .coordinate direto
                guard let location = mapItem.placemark.location else { return }
                
                // 3. Pegamos a coordenada
                let coordinate = location.coordinate
                
                // Retorna Latitude, Longitude e o Nome completo
                completionHandler(coordinate.latitude, coordinate.longitude, completion.title)
            }
        }
}
