import Foundation
import SwiftData

enum ShiftStatus: String, Codable {
    case scheduled = "Agendado"
    case completed = "Realizado"
    case swappedOut = "Troquei (Saí)"
    case swappedIn = "Troquei (Entrei)"
}

@Model
class Shift {
    var id: UUID
    var startDate: Date
    var durationHours: Int
    var locationName: String
    var latitude: Double?
    var longitude: Double?
    var recurrenceID: String?
    var statusRaw: String
    var notes: String?
    
    // Financeiro
    var amount: Double = 0.0
    var isPaid: Bool = false
    
    // Trocas
    var swapValue: Double = 0.0
    var swapPaymentDate: Date?
    
    // Status Operacional
    var isWorkDone: Bool = false
    var swapIsSettled: Bool = false
    
    // Compromissos
    var isCommitment: Bool = false
    var isAllDay: Bool = false // NOVO: Indica se dura o dia todo
    
    var calendarEventID: String?
    
    var endDate: Date {
        // Se for dia todo, convenciona-se terminar no final do dia ou +24h
        let hours = isAllDay ? 24 : durationHours
        return startDate.addingTimeInterval(TimeInterval(hours * 3600))
    }
    
    var status: ShiftStatus {
        get { ShiftStatus(rawValue: statusRaw) ?? .scheduled }
        set { statusRaw = newValue.rawValue }
    }
    
    var netIncome: Double {
        if isCommitment { return 0.0 }
        switch status {
        case .swappedOut: return amount - swapValue
        case .swappedIn: return swapValue
        default: return amount
        }
    }
    
    // Init atualizado
    init(startDate: Date, durationHours: Int, locationName: String, lat: Double? = nil, long: Double? = nil, status: ShiftStatus = .scheduled, amount: Double = 0.0, isPaid: Bool = false, isCommitment: Bool = false, isAllDay: Bool = false) {
        self.id = UUID()
        self.startDate = startDate
        self.durationHours = durationHours
        self.locationName = locationName
        self.latitude = lat
        self.longitude = long
        self.statusRaw = status.rawValue
        self.amount = amount
        self.isPaid = isPaid
        self.isCommitment = isCommitment
        self.isAllDay = isAllDay
    }
}
