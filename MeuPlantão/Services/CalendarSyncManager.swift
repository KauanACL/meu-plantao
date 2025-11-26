import Foundation
import EventKit
import SwiftUI
import SwiftData
import Combine

class CalendarSyncManager: ObservableObject {
    static let shared = CalendarSyncManager()
    private let eventStore = EKEventStore()
    private let calendarName = "MeuPlantão"
    
    @Published var isSyncing = false
    @Published var lastSyncMessage = ""
    @Published var showError = false
    
    func syncShiftsToCalendar(shifts: [Shift], context: ModelContext) {
        self.isSyncing = true
        self.lastSyncMessage = "Espelhando calendário..."
        
        eventStore.requestFullAccessToEvents { [weak self] granted, error in
            DispatchQueue.main.async {
                guard granted, error == nil else {
                    self?.isSyncing = false
                    self?.lastSyncMessage = "Permissão negada. Vá em Ajustes > Privacidade."
                    self?.showError = true
                    return
                }
                
                self?.performWipeAndRecreate(shifts: shifts)
            }
        }
    }
    
    private func performWipeAndRecreate(shifts: [Shift]) {
        guard let calendar = getOrCreateAppCalendar() else {
            DispatchQueue.main.async {
                self.isSyncing = false
                self.lastSyncMessage = "Erro ao acessar calendário."
            }
            return
        }
        
        // 1. LIMPEZA TOTAL (WIPE)
        // Busca eventos de 2 anos atrás até 2 anos na frente
        let startDate = Date().addingTimeInterval(-63072000) // -2 anos
        let endDate = Date().addingTimeInterval(63072000)   // +2 anos
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: [calendar])
        let existingEvents = eventStore.events(matching: predicate)
        
        var deletedCount = 0
        
        // Deleta tudo para garantir que não sobre lixo
        for event in existingEvents {
            do {
                try eventStore.remove(event, span: .thisEvent, commit: false)
                deletedCount += 1
            } catch {
                print("Erro ao marcar para deletar: \(error)")
            }
        }
        
        // Commita a limpeza antes de criar os novos
        do {
            try eventStore.commit()
        } catch {
            print("Erro ao efetivar limpeza: \(error)")
        }
        
        // 2. RECRIAÇÃO (RECREATE)
        var createdCount = 0
        
        for shift in shifts {
            // Regra: Se eu saí (swappedOut), não aparece na minha agenda pessoal
            if shift.status == .swappedOut { continue }
            
            let event = EKEvent(eventStore: eventStore)
            event.calendar = calendar
            event.title = "Plantão: \(shift.locationName)"
            event.startDate = shift.startDate
            event.endDate = shift.endDate
            
            // Detalhes na nota
            let valorFormatado = shift.status == .swappedIn
                ? shift.swapValue.formatted(.currency(code: "BRL"))
                : shift.amount.formatted(.currency(code: "BRL"))
            
            let statusTexto = shift.isWorkDone ? "Concluído" : "Agendado"
            
            event.notes = """
            Status: \(statusTexto)
            Duração: \(shift.durationHours)h
            Valor: \(valorFormatado)
            
            Gerenciado por MeuPlantão
            """
            
            // Adiciona Localização (GPS) para abrir no Waze/Maps
            if let lat = shift.latitude, let long = shift.longitude {
                let location = EKStructuredLocation(title: shift.locationName)
                location.geoLocation = CLLocation(latitude: lat, longitude: long)
                event.structuredLocation = location
            }
            
            // Alarme (Pega do NotificationManager ou padrão 2h antes)
            // Adicionamos um alerta padrão de 2 horas antes no calendário
            let alarm = EKAlarm(relativeOffset: -7200) // -7200 segundos = 2 horas
            event.addAlarm(alarm)
            
            do {
                try eventStore.save(event, span: .thisEvent, commit: false)
                createdCount += 1
            } catch {
                print("Erro ao criar evento: \(error)")
            }
        }
        
        // Commita a criação
        do {
            try eventStore.commit()
        } catch {
            print("Erro ao salvar novos eventos: \(error)")
        }
        
        DispatchQueue.main.async {
            self.isSyncing = false
            self.lastSyncMessage = "Sincronizado! (\(createdCount) ativos)"
            
            // Limpa mensagem após 4 segundos
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                if self.lastSyncMessage.contains("Sincronizado") {
                    self.lastSyncMessage = ""
                }
            }
        }
    }
    
    private func getOrCreateAppCalendar() -> EKCalendar? {
        let calendars = eventStore.calendars(for: .event)
        
        if let existing = calendars.first(where: { $0.title == calendarName }) {
            return existing
        }
        
        let newCalendar = EKCalendar(for: .event, eventStore: eventStore)
        newCalendar.title = calendarName
        
        let sources = eventStore.sources
        // Tenta iCloud primeiro, depois Local
        if let iCloudSource = sources.first(where: { $0.sourceType == .calDAV && $0.title == "iCloud" }) {
            newCalendar.source = iCloudSource
        } else {
            newCalendar.source = eventStore.defaultCalendarForNewEvents?.source
        }
        
        do {
            try eventStore.saveCalendar(newCalendar, commit: true)
            return newCalendar
        } catch {
            print("Erro ao criar calendário: \(error)")
            return nil
        }
    }
}
