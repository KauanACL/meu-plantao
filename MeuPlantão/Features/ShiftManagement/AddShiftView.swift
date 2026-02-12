import SwiftUI
import SwiftData

enum RecurrenceType: String, CaseIterable, Identifiable {
    case none = "Apenas esta data"
    case daily = "Todos os dias"
    case specificDays = "Dias da Semana (Ex: Seg e Qua)"
    case weekly = "A cada 1 semana (Mesmo dia)"
    case biweekly = "A cada 2 semanas (Quinzenal)"
    case monthly = "Todo mês (Mesmo dia)"
    
    var id: String { self.rawValue }
}

struct AddShiftView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    @AppStorage("defaultAmount") private var defaultAmount: Double = 0.0
    @AppStorage("defaultDuration") private var defaultDurationRaw: Int = 12
    
    @State private var locationName: String = ""
    @State private var latitude: Double?
    @State private var longitude: Double?
    
    @State private var startDate: Date = Date()
    @State private var durationHours: Int = 12
    @State private var notes: String = ""
    @State private var amount: Double = 0.0
    
    // Flags de Compromisso
    @State private var isCommitment: Bool = false
    @State private var isAllDay: Bool = false
    
    @State private var recurrence: RecurrenceType = .none
    @State private var repeatUntilDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date())!
    @State private var selectedWeekdays: Set<Int> = []
    
    @State private var showLocationSearch = false
    
    // NOVO: Controles de Validação
    @State private var showValidationAlert = false
    @State private var validationMessage = ""
    @State private var showRecurrenceWarning = false
    @State private var estimatedShiftCount = 0
    
    var body: some View {
        NavigationStack {
            Form {
                // 1. TIPO DE EVENTO
                Section {
                    Toggle(isOn: $isCommitment) {
                        HStack {
                            Image(systemName: isCommitment ? "calendar.badge.exclamationmark" : "stethoscope")
                                .foregroundStyle(isCommitment ? Color.gray : Color.medBlue)
                            VStack(alignment: .leading) {
                                Text("Marcar como Compromisso")
                                    .font(.headline)
                                Text(isCommitment ? "Bloqueio de agenda (Evento Pessoal)" : "Plantão de Trabalho")
                                    .font(.caption)
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                    }
                    .tint(Color.medBlue)
                }
                
                // 2. NOME / LOCAL (Lógica Híbrida)
                Section(header: Text(isCommitment ? "Título do Compromisso" : "Local do Plantão")) {
                    if isCommitment {
                        // COMPROMISSO: Campo de Texto Simples
                        TextField("Ex: Aniversário, Congresso...", text: $locationName)
                            .autocorrectionDisabled()
                    } else {
                        // PLANTÃO: Busca no Mapa
                        if !locationName.isEmpty {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(locationName)
                                        .medFont(.headline)
                                        .foregroundStyle(Color.medBlue)
                                    if latitude != nil {
                                        Text("Validado com Apple Maps")
                                            .medFont(.caption)
                                            .foregroundStyle(Color.secondary)
                                    }
                                }
                                Spacer()
                                Button("", systemImage: "xmark.circle.fill") {
                                    locationName = ""
                                    latitude = nil
                                    longitude = nil
                                }
                                .foregroundStyle(Color.gray)
                            }
                        } else {
                            Button(action: { showLocationSearch = true }) {
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                    Text("Buscar Hospital...")
                                        .foregroundStyle(Color.secondary)
                                }
                            }
                        }
                    }
                }
                
                // 3. DATA E DURAÇÃO
                Section(header: Text("Quando")) {
                    DatePicker("Início", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    
                    if isCommitment {
                        // Opção de Dia Todo para Compromissos
                        Toggle("O dia todo", isOn: $isAllDay)
                            .tint(Color.medBlue)
                        
                        if !isAllDay {
                            Picker("Duração", selection: $durationHours) {
                                ForEach(1...24, id: \.self) { hour in
                                    Text("\(hour) horas").tag(hour)
                                }
                            }
                        }
                    } else {
                        // Plantão sempre tem duração
                        Picker("Duração", selection: $durationHours) {
                            ForEach(1...36, id: \.self) { hour in
                                Text("\(hour) horas").tag(hour)
                            }
                        }
                    }
                }
                
                // 4. FINANCEIRO (Apenas Plantão)
                if !isCommitment {
                    Section(header: Text("Financeiro")) {
                        HStack {
                            Text("Valor Total")
                            Spacer()
                            TextField("R$ 0,00", value: $amount, format: .currency(code: "BRL"))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(Color.primary)
                        }
                    }
                }
                
                // 5. REPETIÇÃO
                Section(header: Text("Repetição")) {
                    Picker("Frequência", selection: $recurrence) {
                        ForEach(RecurrenceType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: recurrence) { _, newValue in
                        if newValue != .none {
                            estimatedShiftCount = calculateEstimatedShifts()
                        }
                    }
                    
                    if recurrence == .specificDays {
                        VStack(alignment: .leading) {
                            Text("Dias da Semana")
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                            HStack {
                                ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { day in
                                    WeekdayButton(
                                        day: day,
                                        isSelected: selectedWeekdays.contains(day)
                                    ) {
                                        toggleDay(day)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 5)
                    }
                    
                    if recurrence != .none {
                        DatePicker("Repetir até", selection: $repeatUntilDate, displayedComponents: .date)
                        
                        // NOVO: Contador de plantões estimados
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(Color.medBlue)
                            Text("Isso criará aproximadamente \(estimatedShiftCount) plantões")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .onChange(of: repeatUntilDate) { _, _ in
                            estimatedShiftCount = calculateEstimatedShifts()
                        }
                    }
                }
                
                Section(header: Text("Notas")) {
                    TextField("Observações...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(isCommitment ? "Novo Compromisso" : "Novo Plantão")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        validateAndSave()
                    }
                    .disabled(locationName.isEmpty)
                    .fontWeight(.bold)
                }
            }
            .sheet(isPresented: $showLocationSearch) {
                LocationSearchView { name, lat, long in
                    self.locationName = name
                    self.latitude = lat
                    self.longitude = long
                }
            }
            .alert("Atenção", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationMessage)
            }
            .alert("Muitos Plantões", isPresented: $showRecurrenceWarning) {
                Button("Cancelar", role: .cancel) { }
                Button("Continuar Assim Mesmo") {
                    saveShift()
                }
            } message: {
                Text("Isso criará \(estimatedShiftCount) plantões. Tem certeza que deseja continuar?")
            }
            .onAppear {
                let weekday = Calendar.current.component(.weekday, from: startDate)
                selectedWeekdays.insert(weekday)
                if amount == 0 { amount = defaultAmount }
                if defaultDurationRaw > 0 { durationHours = defaultDurationRaw }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    func toggleDay(_ day: Int) {
        HapticManager.shared.selection()
        if selectedWeekdays.contains(day) {
            selectedWeekdays.remove(day)
        } else {
            selectedWeekdays.insert(day)
        }
        estimatedShiftCount = calculateEstimatedShifts()
    }
    
    func calculateEstimatedShifts() -> Int {
        guard recurrence != .none else { return 1 }
        
        let calendar = Calendar.current
        let daysBetween = calendar.dateComponents([.day], from: startDate, to: repeatUntilDate).day ?? 0
        
        switch recurrence {
        case .none:
            return 1
        case .daily:
            return max(1, daysBetween)
        case .weekly:
            return max(1, daysBetween / 7)
        case .biweekly:
            return max(1, daysBetween / 14)
        case .monthly:
            return max(1, daysBetween / 30)
        case .specificDays:
            return max(1, (daysBetween / 7) * selectedWeekdays.count)
        }
    }
    
    func validateAndSave() {
        // Validação 1: Nome obrigatório
        guard !locationName.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationMessage = "O nome do local é obrigatório"
            showValidationAlert = true
            HapticManager.shared.notification(.error)
            return
        }
        
        // Validação 2: Plantão precisa de GPS
        if !isCommitment {
            guard latitude != nil, longitude != nil else {
                validationMessage = "Plantões de trabalho precisam de localização válida do Apple Maps. Use o botão 'Buscar Hospital'."
                showValidationAlert = true
                HapticManager.shared.notification(.error)
                return
            }
        }
        
        // Validação 3: Duração positiva
        guard durationHours > 0 else {
            validationMessage = "A duração deve ser maior que zero"
            showValidationAlert = true
            HapticManager.shared.notification(.error)
            return
        }
        
        // Validação 4: Data de término após início
        if recurrence != .none {
            guard repeatUntilDate > startDate else {
                validationMessage = "A data de término deve ser posterior à data de início"
                showValidationAlert = true
                HapticManager.shared.notification(.error)
                return
            }
        }
        
        // Validação 5: Dias selecionados (para specificDays)
        if recurrence == .specificDays && selectedWeekdays.isEmpty {
            validationMessage = "Selecione pelo menos um dia da semana"
            showValidationAlert = true
            HapticManager.shared.notification(.error)
            return
        }
        
        // Validação 6: Aviso para recorrências longas
        if estimatedShiftCount > 100 {
            showRecurrenceWarning = true
            HapticManager.shared.notification(.warning)
            return
        }
        
        // Tudo OK, salva
        saveShift()
    }
    
    func saveShift() {
        HapticManager.shared.notification(.success)
        
        let recurrenceID = UUID().uuidString
        let calendar = Calendar.current
        var loopDate = startDate
        let finalDate = calendar.startOfDay(for: repeatUntilDate).addingTimeInterval(86399)
        
        while loopDate <= finalDate {
            var shouldCreate = false
            switch recurrence {
            case .none:
                shouldCreate = true
            case .daily:
                shouldCreate = true
            case .weekly:
                shouldCreate = true
            case .biweekly:
                shouldCreate = true
            case .monthly:
                // CORREÇÃO: Trata meses curtos
                let dayStart = calendar.component(.day, from: startDate)
                let range = calendar.range(of: .day, in: .month, for: loopDate)!
                let lastDayOfMonth = range.count
                let targetDay = min(dayStart, lastDayOfMonth)
                let dayLoop = calendar.component(.day, from: loopDate)
                if dayLoop == targetDay { shouldCreate = true }
            case .specificDays:
                let weekday = calendar.component(.weekday, from: loopDate)
                if selectedWeekdays.contains(weekday) { shouldCreate = true }
            }
            
            if shouldCreate {
                let hour = calendar.component(.hour, from: startDate)
                let minute = calendar.component(.minute, from: startDate)
                var finalComponents = calendar.dateComponents([.year, .month, .day], from: loopDate)
                finalComponents.hour = hour
                finalComponents.minute = minute
                
                if let shiftDate = calendar.date(from: finalComponents) {
                    let newShift = Shift(
                        startDate: shiftDate,
                        durationHours: isCommitment ? (isAllDay ? 24 : durationHours) : durationHours,
                        locationName: locationName,
                        lat: isCommitment ? nil : latitude,
                        long: isCommitment ? nil : longitude,
                        amount: isCommitment ? 0 : amount,
                        isCommitment: isCommitment,
                        isAllDay: isAllDay
                    )
                    newShift.notes = notes.isEmpty ? nil : notes
                    if recurrence != .none { newShift.recurrenceID = recurrenceID }
                    modelContext.insert(newShift)
                    
                    // Notificação apenas se não for passado
                    if shiftDate > Date() {
                        NotificationManager.shared.scheduleNotification(for: newShift)
                    }
                }
            }
            
            if recurrence == .none { break }
            
            var nextDate: Date?
            switch recurrence {
            case .daily, .specificDays:
                nextDate = calendar.date(byAdding: .day, value: 1, to: loopDate)
            case .weekly:
                nextDate = calendar.date(byAdding: .weekOfYear, value: 1, to: loopDate)
            case .biweekly:
                nextDate = calendar.date(byAdding: .weekOfYear, value: 2, to: loopDate)
            case .monthly:
                nextDate = calendar.date(byAdding: .month, value: 1, to: loopDate)
            case .none:
                nextDate = nil
            }
            
            if let next = nextDate { loopDate = next } else { break }
        }
        dismiss()
    }
}

struct WeekdayButton: View {
    let day: Int
    let isSelected: Bool
    let action: () -> Void
    
    var label: String {
        switch day {
        case 1: return "D"
        case 2: return "S"
        case 3: return "T"
        case 4: return "Q"
        case 5: return "Q"
        case 6: return "S"
        case 7: return "S"
        default: return ""
        }
    }
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(.bold)
                .frame(width: 35, height: 35)
                .background(isSelected ? Color.medBlue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Circle())
        }
        .buttonStyle(.borderless)
    }
}
