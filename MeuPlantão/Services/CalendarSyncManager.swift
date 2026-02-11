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
        let startDate = Date().addingTimeInterval(-63072000) // -2 anos
        let endDate = Date().addingTimeInterval(63072000)   // +2 anos
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: [calendar])
        let existingEvents = eventStore.events(matching: predicate)
        
        // Deleta tudo para garantir que não sobre lixo
        for event in existingEvents {
            do {
                try eventStore.remove(event, span: .thisEvent, commit: false)
            } catch {
                print("Erro ao marcar para deletar: \(error)")
            }
        }
        
        do { try eventStore.commit() } catch { print("Erro ao efetivar limpeza: \(error)") }
        
        // 2. RECRIAÇÃO (RECREATE)
        var createdCount = 0
        
        for shift in shifts {
            // Regra: Se eu saí (swappedOut), não aparece na minha agenda pessoal
            if shift.status == .swappedOut { continue }
            
            let event = EKEvent(eventStore: eventStore)
            event.calendar = calendar
            
            // --- PERSONALIZAÇÃO VISUAL ---
            let prefixo = shift.isCommitment ? "🗓️" : "🏥 Plantão:"
            event.title = "\(prefixo) \(shift.locationName)"
            
            event.startDate = shift.startDate
            event.endDate = shift.endDate
            event.isAllDay = shift.isAllDay // Sincroniza a flag de Dia Todo
            
            // Detalhes na nota
            var info = ""
            if shift.isCommitment {
                info = "Compromisso Pessoal\nBloqueio de Agenda"
            } else {
                let valorFormatado = shift.status == .swappedIn
                    ? shift.swapValue.formatted(.currency(code: "BRL"))
                    : shift.amount.formatted(.currency(code: "BRL"))
                let statusTexto = shift.isWorkDone ? "Concluído" : "Agendado"
                
                info = """
                Status: \(statusTexto)
                Duração: \(shift.durationHours)h
                Valor: \(valorFormatado)
                """
            }
            
            event.notes = "\(info)\n\nGerenciado por MeuPlantão"
            
            // Adiciona Localização (GPS) apenas se não for compromisso de texto simples
            if let lat = shift.latitude, let long = shift.longitude {
                let location = EKStructuredLocation(title: shift.locationName)
                location.geoLocation = CLLocation(latitude: lat, longitude: long)
                event.structuredLocation = location
            }
            
            // Alarme Padrão no Calendário (Opcional, pois o App já notifica)
            // Mas é bom ter no calendário nativo também
            if !shift.isAllDay {
                event.addAlarm(EKAlarm(relativeOffset: -7200)) // 2h antes
            } else {
                // Se for dia todo, avisa as 09:00 do dia anterior (exemplo)
                // Ou não põe alarme e deixa o usuário decidir
            }
            
            do {
                try eventStore.save(event, span: .thisEvent, commit: false)
                createdCount += 1
            } catch {
                print("Erro ao criar evento: \(error)")
            }
        }
        
        do { try eventStore.commit() } catch { print("Erro ao salvar novos eventos: \(error)") }
        
        DispatchQueue.main.async {
            self.isSyncing = false
            self.lastSyncMessage = "Sincronizado! (\(createdCount) ativos)"
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                if self.lastSyncMessage.contains("Sincronizado") {
                    self.lastSyncMessage = ""
                }
            }
        }
    }
    
    private func getOrCreateAppCalendar() -> EKCalendar? {
        let calendars = eventStore.calendars(for: .event)
        if let existing = calendars.first(where: { $0.title == calendarName }) { return existing }
        
        let newCalendar = EKCalendar(for: .event, eventStore: eventStore)
        newCalendar.title = calendarName
        
        let sources = eventStore.sources
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
