import SwiftUI
import SwiftData

struct FinancialAnalyticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Shift.startDate, order: .forward) private var shifts: [Shift]
    @Query(sort: \FiscalNote.createdAt, order: .reverse) private var fiscalNotes: [FiscalNote]
    @Query(sort: \SwapAgreement.createdAt, order: .reverse) private var swapAgreements: [SwapAgreement]
    @Query(sort: \Hospital.name, order: .forward) private var hospitals: [Hospital]

    @State private var selectedTab = 0
    @State private var selectedMonth = Date()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("Financeiro", selection: $selectedTab) {
                    Text("Resumo").tag(0)
                    Text("NFs").tag(1)
                    Text("Repasses").tag(2)
                    Text("Previsões").tag(3)
                    Text("Alertas").tag(4)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Group {
                    switch selectedTab {
                    case 0: FinancialOverviewTab(shifts: shifts, selectedMonth: $selectedMonth)
                    case 1: FiscalNotesTab(shifts: shifts, fiscalNotes: fiscalNotes)
                    case 2: SwapManagementTab(shifts: shifts, agreements: swapAgreements)
                    case 3: PaymentPredictionsTab(shifts: shifts, hospitals: hospitals)
                    default: AlertsCenterTab(shifts: shifts, agreements: swapAgreements, hospitals: hospitals)
                    }
                }
            }
            .navigationTitle("Financeiro v1.1")
        }
    }
}

private struct FinancialOverviewTab: View {
    let shifts: [Shift]
    @Binding var selectedMonth: Date

    private var monthShifts: [Shift] {
        let cal = Calendar.current
        return shifts.filter {
            cal.isDate($0.startDate, equalTo: selectedMonth, toGranularity: .month) &&
            cal.isDate($0.startDate, equalTo: selectedMonth, toGranularity: .year)
        }
    }

    private var grossIncome: Double {
        monthShifts.reduce(0) { partial, shift in
            guard !shift.isCommitment else { return partial }
            if shift.status == .swappedIn { return partial + shift.swapValue }
            return partial + shift.amount
        }
    }

    private var swapExpenses: Double {
        monthShifts.reduce(0) { $0 + (($1.status == .swappedOut) ? $1.swapValue : 0) }
    }

    private var netIncome: Double { grossIncome - swapExpenses }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    Button { changeMonth(by: -1) } label: { Image(systemName: "chevron.left") }
                    Spacer()
                    Text(selectedMonth.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "pt_BR"))))
                        .font(.headline)
                    Spacer()
                    Button { changeMonth(by: 1) } label: { Image(systemName: "chevron.right") }
                }
                .padding(.horizontal)

                MetricCard(title: "Receita Bruta", value: grossIncome, tint: .blue)
                MetricCard(title: "Despesas de Repasse", value: swapExpenses, tint: .red)
                MetricCard(title: "Receita Líquida", value: netIncome, tint: .green)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Plantões do mês").font(.headline)
                    ForEach(monthShifts) { shift in
                        HStack {
                            Text(shift.startDate.formatted(date: .abbreviated, time: .omitted))
                            Spacer()
                            Text(shift.locationName).lineLimit(1)
                            Spacer()
                            Text(shift.netIncome.formatted(.currency(code: "BRL")))
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                        .padding(10)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 32)
        }
    }

    private func changeMonth(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: selectedMonth) {
            selectedMonth = newDate
        }
    }
}

private struct FiscalNotesTab: View {
    @Environment(\.modelContext) private var modelContext
    let shifts: [Shift]
    let fiscalNotes: [FiscalNote]

    @State private var selectedHospital = ""
    @State private var selectedShiftIDs = Set<UUID>()
    @State private var noteNumber = ""
    @State private var amount = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Nova Nota Fiscal").font(.headline)
                TextField("Hospital", text: $selectedHospital)
                    .textFieldStyle(.roundedBorder)
                TextField("Número da NF", text: $noteNumber)
                    .textFieldStyle(.roundedBorder)
                TextField("Valor", text: $amount)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)

                Text("Vincular plantões").font(.subheadline).fontWeight(.semibold)
                ForEach(shifts.filter { !$0.isCommitment }) { shift in
                    let isSelected = selectedShiftIDs.contains(shift.id)
                    Button {
                        if isSelected { selectedShiftIDs.remove(shift.id) } else { selectedShiftIDs.insert(shift.id) }
                    } label: {
                        HStack {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            Text("\(shift.startDate.formatted(date: .abbreviated, time: .omitted)) • \(shift.locationName)")
                                .lineLimit(1)
                            Spacer()
                            Text(shift.amount.formatted(.currency(code: "BRL")))
                        }
                        .font(.footnote)
                    }
                    .buttonStyle(.plain)
                }

                Button("Salvar NF") { createFiscalNote() }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedHospital.isEmpty || selectedShiftIDs.isEmpty)

                Divider().padding(.vertical, 8)

                Text("Notas cadastradas").font(.headline)
                ForEach(fiscalNotes) { note in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(note.noteNumber ?? "Sem número") • \(note.hospitalName)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("\(note.totalAmount.formatted(.currency(code: "BRL"))) • \(note.linkedShiftIDs.count) plantão(ões)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding()
        }
    }

    private func createFiscalNote() {
        let parsedAmount = Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0
        let isConsolidated = selectedShiftIDs.count > 1
        let newNote = FiscalNote(
            noteNumber: noteNumber.isEmpty ? nil : noteNumber,
            totalAmount: parsedAmount,
            hospitalName: selectedHospital,
            fileName: "manual_\(UUID().uuidString).jpg",
            fileSize: 0,
            linkedShiftIDs: Array(selectedShiftIDs),
            isConsolidated: isConsolidated
        )

        modelContext.insert(newNote)

        for shift in shifts where selectedShiftIDs.contains(shift.id) {
            if !shift.fiscalNoteIDs.contains(newNote.id) {
                shift.fiscalNoteIDs.append(newNote.id)
            }
            shift.hospitalName = selectedHospital
        }

        selectedHospital = ""
        selectedShiftIDs.removeAll()
        noteNumber = ""
        amount = ""
    }
}

private struct SwapManagementTab: View {
    @Environment(\.modelContext) private var modelContext
    let shifts: [Shift]
    let agreements: [SwapAgreement]

    @State private var selectedShiftID: UUID?
    @State private var colleagueName = ""
    @State private var agreedAmount = ""
    @State private var paymentDate = Date()
    @State private var swapType: SwapType = .out

    private var pendingToPay: [SwapAgreement] {
        agreements.filter { !$0.isSettled && $0.swapType == .out }
    }

    private var pendingToReceive: [SwapAgreement] {
        agreements.filter { !$0.isSettled && $0.swapType == .in }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Registrar acordo").font(.headline)

                Picker("Tipo", selection: $swapType) {
                    Text("Saída").tag(SwapType.out)
                    Text("Entrada").tag(SwapType.in)
                }
                .pickerStyle(.segmented)

                Picker("Plantão", selection: $selectedShiftID) {
                    Text("Selecione").tag(nil as UUID?)
                    ForEach(shifts.filter { !$0.isCommitment }) { shift in
                        Text("\(shift.startDate.formatted(date: .abbreviated, time: .omitted)) • \(shift.locationName)")
                            .tag(Optional(shift.id))
                    }
                }

                TextField("Nome do colega", text: $colleagueName)
                    .textFieldStyle(.roundedBorder)
                TextField("Valor combinado", text: $agreedAmount)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                DatePicker("Data combinada", selection: $paymentDate, displayedComponents: .date)

                Button("Salvar repasse") { saveAgreement() }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedShiftID == nil || colleagueName.isEmpty)

                Divider().padding(.vertical, 4)

                SwapSection(title: "Você deve", agreements: pendingToPay) { settle($0) }
                SwapSection(title: "Você receberá", agreements: pendingToReceive) { settle($0) }
            }
            .padding()
        }
    }

    private func saveAgreement() {
        guard let selectedShiftID,
              let shift = shifts.first(where: { $0.id == selectedShiftID }) else { return }

        let amount = Double(agreedAmount.replacingOccurrences(of: ",", with: ".")) ?? shift.swapValue
        let agreement = SwapAgreement(
            shiftID: shift.id,
            swapType: swapType,
            yourName: "Usuário",
            colleagueName: colleagueName,
            agreementType: .paidValue,
            agreedAmount: amount,
            originalShiftValue: shift.amount,
            agreedPaymentDate: paymentDate
        )

        modelContext.insert(agreement)
        shift.swapAgreementID = agreement.id
        shift.swapValue = amount
        shift.swapPaymentDate = paymentDate
        shift.status = (swapType == .out) ? .swappedOut : .swappedIn

        selectedShiftID = nil
        colleagueName = ""
        agreedAmount = ""
        paymentDate = Date()
    }

    private func settle(_ agreement: SwapAgreement) {
        agreement.isSettled = true
        agreement.effectivePaymentDate = .now
        agreement.paymentMethod = .pix

        if let shift = shifts.first(where: { $0.id == agreement.shiftID }) {
            shift.swapIsSettled = true
        }
    }
}

private struct SwapSection: View {
    let title: String
    let agreements: [SwapAgreement]
    let onSettle: (SwapAgreement) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            if agreements.isEmpty {
                Text("Sem itens pendentes.").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(agreements) { agreement in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(agreement.colleagueName).fontWeight(.semibold)
                            Text("Vence: \(agreement.agreedPaymentDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(agreement.agreedAmount.formatted(.currency(code: "BRL")))
                        Button("Quitar") { onSettle(agreement) }
                            .buttonStyle(.bordered)
                    }
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
}

private struct PaymentPredictionsTab: View {
    @Environment(\.modelContext) private var modelContext
    let shifts: [Shift]
    let hospitals: [Hospital]

    @State private var hospitalName = ""
    @State private var paymentDay = 5
    @State private var tolerance = 5

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Configurar hospital").font(.headline)
                TextField("Nome do hospital", text: $hospitalName)
                    .textFieldStyle(.roundedBorder)
                Stepper("Dia do pagamento: \(paymentDay)", value: $paymentDay, in: 1...31)
                Stepper("Tolerância: \(tolerance) dias", value: $tolerance, in: 1...15)
                Button("Salvar configuração") { saveHospital() }
                    .buttonStyle(.borderedProminent)
                    .disabled(hospitalName.isEmpty)

                Divider().padding(.vertical, 8)

                Text("Previsões").font(.headline)
                ForEach(hospitals) { hospital in
                    let pendingShifts = shifts.filter { ($0.hospitalName ?? $0.locationName) == hospital.name && !$0.isPaid }
                    let predictedAmount = pendingShifts.reduce(0) { $0 + $1.amount }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(hospital.name).fontWeight(.semibold)
                        Text("Previsto: \((hospital.nextPaymentDate ?? .now).formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                        Text("Valor esperado: \(predictedAmount.formatted(.currency(code: "BRL")))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding()
        }
    }

    private func saveHospital() {
        let hospital = Hospital(
            name: hospitalName,
            paymentFrequency: .monthly,
            paymentDayOfMonth: paymentDay,
            latencyToleranceDays: tolerance,
            averageShiftValue: shifts.filter { ($0.hospitalName ?? $0.locationName) == hospitalName }.map(\.amount).average
        )
        modelContext.insert(hospital)
        hospitalName = ""
        paymentDay = 5
        tolerance = 5
    }
}

private struct AlertsCenterTab: View {
    let shifts: [Shift]
    let agreements: [SwapAgreement]
    let hospitals: [Hospital]

    private var alerts: [AlertItem] {
        var items: [AlertItem] = []
        let now = Date()
        let calendar = Calendar.current

        for agreement in agreements where !agreement.isSettled {
            if agreement.isOverdue, agreement.daysOverdue > 7 {
                items.append(.init(severity: .critical, title: "Repasse atrasado", detail: "\(agreement.colleagueName) • \(agreement.daysOverdue) dias"))
            } else if let days = calendar.dateComponents([.day], from: now, to: agreement.agreedPaymentDate).day, (0...2).contains(days) {
                items.append(.init(severity: .warning, title: "Repasse vencendo", detail: "\(agreement.colleagueName) • vence em \(days) dia(s)"))
            }
        }

        let shiftsWithoutNF = shifts.filter { !$0.isCommitment && !$0.isPaid && $0.fiscalNoteIDs.isEmpty && $0.startDate < now }
        if shiftsWithoutNF.count >= 3 {
            items.append(.init(severity: .warning, title: "Notas fiscais pendentes", detail: "\(shiftsWithoutNF.count) plantões sem NF"))
        }

        for hospital in hospitals where hospital.alertsEnabled {
            if let nextPaymentDate = hospital.nextPaymentDate,
               let daysDiff = calendar.dateComponents([.day], from: nextPaymentDate, to: now).day,
               daysDiff > hospital.latencyToleranceDays {
                items.append(.init(severity: .critical, title: "Pagamento atrasado", detail: "\(hospital.name) • \(daysDiff) dias"))
            }
        }

        if items.isEmpty {
            items.append(.init(severity: .info, title: "Sem alertas críticos", detail: "Tudo em dia no financeiro."))
        }

        return items.sorted { $0.severity.priority > $1.severity.priority }
    }

    var body: some View {
        List(alerts) { alert in
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Circle().fill(alert.severity.color).frame(width: 10, height: 10)
                    Text(alert.title).fontWeight(.semibold)
                }
                Text(alert.detail).font(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .listStyle(.insetGrouped)
    }
}

private struct AlertItem: Identifiable {
    let id = UUID()
    let severity: FinancialAlertSeverity
    let title: String
    let detail: String
}

private struct MetricCard: View {
    let title: String
    let value: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value.formatted(.currency(code: "BRL"))).font(.title3).fontWeight(.bold).foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }
}

private extension FinancialAlertSeverity {
    var color: Color {
        switch self {
        case .critical: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }

    var priority: Int {
        switch self {
        case .critical: return 3
        case .warning: return 2
        case .info: return 1
        }
    }
}

private extension Array where Element == Double {
    var average: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}
