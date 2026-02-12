import Foundation
import SwiftData

enum ShiftStatus: String, Codable {
    case scheduled = "Agendado"
    case completed = "Realizado"
    case swappedOut = "Troquei (Saí)"
    case swappedIn = "Troquei (Entrei)"
}

enum FileType: String, Codable {
    case image
    case pdf
}

enum SwapType: String, Codable {
    case out = "Saída"
    case `in` = "Entrada"
}

enum AgreementType: String, Codable {
    case free = "Grátis (Favor)"
    case futureSwap = "Troca Futura"
    case paidValue = "Valor Combinado"
}

enum PaymentMethod: String, Codable, CaseIterable {
    case pix = "PIX"
    case cash = "Dinheiro"
    case transfer = "Transferência"
    case other = "Outro"
}

enum PaymentFrequency: String, Codable, CaseIterable {
    case weekly = "Semanal"
    case biweekly = "Quinzenal"
    case monthly = "Mensal"
    case custom = "Personalizado"
}

enum FinancialAlertSeverity: String, Codable, CaseIterable {
    case critical
    case warning
    case info
}

enum FinancialAlertType: String, Codable {
    case overdueHospitalPayment
    case overdueSwap
    case missingFiscalNote
    case upcomingHospitalPayment
    case upcomingSwap
}

struct PaymentRecord: Codable {
    var expectedDate: Date
    var actualDate: Date
    var amount: Double
    var shiftIDs: [UUID]
    var daysLate: Int
    var wasOnTime: Bool
}

struct TaxRetention: Codable {
    var irRate: Double
    var issRate: Double
    var inssRate: Double
}

@Model
class FiscalNote {
    var id: UUID
    var noteNumber: String?
    var emissionDate: Date
    var totalAmount: Double
    var cnpj: String?
    var hospitalName: String
    var imageData: Data?
    var pdfData: Data?
    var fileName: String
    var fileSize: Int
    var linkedShiftIDs: [UUID]
    var isConsolidated: Bool
    var createdAt: Date
    var updatedAt: Date
    var notes: String?

    var fileType: FileType {
        pdfData != nil ? .pdf : .image
    }

    init(noteNumber: String? = nil,
         emissionDate: Date = .now,
         totalAmount: Double,
         cnpj: String? = nil,
         hospitalName: String,
         imageData: Data? = nil,
         pdfData: Data? = nil,
         fileName: String,
         fileSize: Int,
         linkedShiftIDs: [UUID] = [],
         isConsolidated: Bool = false,
         notes: String? = nil) {
        self.id = UUID()
        self.noteNumber = noteNumber
        self.emissionDate = emissionDate
        self.totalAmount = totalAmount
        self.cnpj = cnpj
        self.hospitalName = hospitalName
        self.imageData = imageData
        self.pdfData = pdfData
        self.fileName = fileName
        self.fileSize = fileSize
        self.linkedShiftIDs = linkedShiftIDs
        self.isConsolidated = isConsolidated
        self.createdAt = .now
        self.updatedAt = .now
        self.notes = notes
    }
}

@Model
class SwapAgreement {
    var id: UUID
    var shiftID: UUID
    var swapTypeRaw: String
    var yourName: String
    var colleagueName: String
    var colleaguePhone: String?
    var colleagueEmail: String?
    var agreementTypeRaw: String
    var agreedAmount: Double
    var originalShiftValue: Double
    var agreedPaymentDate: Date
    var effectivePaymentDate: Date?
    var isSettled: Bool
    var agreementProofImageData: Data?
    var paymentProofImageData: Data?
    var paymentMethodRaw: String?
    var reminderSentDates: [Date]
    var nextReminderDate: Date?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    var swapType: SwapType {
        get { SwapType(rawValue: swapTypeRaw) ?? .out }
        set { swapTypeRaw = newValue.rawValue }
    }

    var agreementType: AgreementType {
        get { AgreementType(rawValue: agreementTypeRaw) ?? .paidValue }
        set { agreementTypeRaw = newValue.rawValue }
    }

    var paymentMethod: PaymentMethod? {
        get {
            guard let paymentMethodRaw else { return nil }
            return PaymentMethod(rawValue: paymentMethodRaw)
        }
        set { paymentMethodRaw = newValue?.rawValue }
    }

    var isOverdue: Bool {
        !isSettled && agreedPaymentDate < Date()
    }

    var daysOverdue: Int {
        max(0, Calendar.current.dateComponents([.day], from: agreedPaymentDate, to: Date()).day ?? 0)
    }

    init(shiftID: UUID,
         swapType: SwapType,
         yourName: String,
         colleagueName: String,
         agreementType: AgreementType,
         agreedAmount: Double,
         originalShiftValue: Double,
         agreedPaymentDate: Date,
         notes: String? = nil) {
        self.id = UUID()
        self.shiftID = shiftID
        self.swapTypeRaw = swapType.rawValue
        self.yourName = yourName
        self.colleagueName = colleagueName
        self.agreementTypeRaw = agreementType.rawValue
        self.agreedAmount = agreedAmount
        self.originalShiftValue = originalShiftValue
        self.agreedPaymentDate = agreedPaymentDate
        self.isSettled = false
        self.reminderSentDates = []
        self.notes = notes
        self.createdAt = .now
        self.updatedAt = .now
    }
}

@Model
class Hospital {
    var id: UUID
    var name: String
    var cnpj: String?
    var address: String?
    var paymentFrequencyRaw: String
    var paymentDayOfMonth: Int?
    var isLastDayOfMonth: Bool
    var latencyToleranceDays: Int
    var averageShiftValue: Double
    var defaultTaxRetention: TaxRetention?
    var paymentHistory: [PaymentRecord]
    var punctualityScore: Double
    var financeDepartmentPhone: String?
    var financeDepartmentEmail: String?
    var notes: String?
    var alertsEnabled: Bool

    var paymentFrequency: PaymentFrequency {
        get { PaymentFrequency(rawValue: paymentFrequencyRaw) ?? .monthly }
        set { paymentFrequencyRaw = newValue.rawValue }
    }

    var nextPaymentDate: Date? {
        let calendar = Calendar.current
        let base = Date()
        switch paymentFrequency {
        case .monthly:
            if isLastDayOfMonth {
                guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: base),
                      let range = calendar.range(of: .day, in: .month, for: nextMonth),
                      let year = calendar.dateComponents([.year], from: nextMonth).year,
                      let month = calendar.dateComponents([.month], from: nextMonth).month else { return nil }
                return calendar.date(from: DateComponents(year: year, month: month, day: range.count))
            }

            guard let day = paymentDayOfMonth else { return nil }
            var components = calendar.dateComponents([.year, .month], from: base)
            components.day = day
            return calendar.date(from: components)
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: base)
        case .biweekly:
            return calendar.date(byAdding: .day, value: 15, to: base)
        case .custom:
            return nil
        }
    }

    init(name: String,
         cnpj: String? = nil,
         paymentFrequency: PaymentFrequency = .monthly,
         paymentDayOfMonth: Int? = 5,
         isLastDayOfMonth: Bool = false,
         latencyToleranceDays: Int = 5,
         averageShiftValue: Double = 0,
         alertsEnabled: Bool = true,
         notes: String? = nil) {
        self.id = UUID()
        self.name = name
        self.cnpj = cnpj
        self.paymentFrequencyRaw = paymentFrequency.rawValue
        self.paymentDayOfMonth = paymentDayOfMonth
        self.isLastDayOfMonth = isLastDayOfMonth
        self.latencyToleranceDays = latencyToleranceDays
        self.averageShiftValue = averageShiftValue
        self.paymentHistory = []
        self.punctualityScore = 1
        self.alertsEnabled = alertsEnabled
        self.notes = notes
    }
}

@Model
class FinancialAlert {
    var id: UUID
    var typeRaw: String
    var severityRaw: String
    var title: String
    var message: String
    var relatedShiftID: UUID?
    var dueDate: Date?
    var isResolved: Bool
    var createdAt: Date
    var resolvedAt: Date?

    var type: FinancialAlertType {
        get { FinancialAlertType(rawValue: typeRaw) ?? .upcomingHospitalPayment }
        set { typeRaw = newValue.rawValue }
    }

    var severity: FinancialAlertSeverity {
        get { FinancialAlertSeverity(rawValue: severityRaw) ?? .info }
        set { severityRaw = newValue.rawValue }
    }

    init(type: FinancialAlertType,
         severity: FinancialAlertSeverity,
         title: String,
         message: String,
         relatedShiftID: UUID? = nil,
         dueDate: Date? = nil) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.severityRaw = severity.rawValue
        self.title = title
        self.message = message
        self.relatedShiftID = relatedShiftID
        self.dueDate = dueDate
        self.isResolved = false
        self.createdAt = .now
    }
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

    // Financeiro v1.1
    var fiscalNoteIDs: [UUID] = []
    var swapAgreementID: UUID?
    var hospitalID: UUID?
    var hospitalName: String?
    
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
