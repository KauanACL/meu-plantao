import SwiftUI
import SwiftData
import Charts

struct FinancialAnalyticsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Shift.startDate, order: .forward) var shifts: [Shift]
    
    @State private var selectedTab: Int = 0
    @State private var selectedDate: Date = Date()
    @State private var selectedShiftIDs = Set<UUID>()
    @State private var editMode: EditMode = .inactive
    
    // --- LÓGICA DE CÁLCULO MENSAL (CORRIGIDA) ---
    var monthStats: MonthStats {
        let calendar = Calendar.current
        let monthShifts = shifts.filter {
            calendar.isDate($0.startDate, equalTo: selectedDate, toGranularity: .month) &&
            calendar.isDate($0.startDate, equalTo: selectedDate, toGranularity: .year)
        }
        
        var totalHours: Int = 0
        
        // Previsão (O que deveria acontecer no mundo ideal)
        var grossIncome: Double = 0.0
        var expenses: Double = 0.0
        
        // Realidade (O que aconteceu no caixa)
        var totalReceived: Double = 0.0 // Somatória de todas as entradas
        var totalPaid: Double = 0.0     // Somatória de todas as saídas
        
        for shift in monthShifts {
            // Ignora compromissos pessoais
            if shift.isCommitment { continue }
            
            // Horas (Se trabalhou)
            if shift.status != .swappedOut && (shift.isWorkDone || shift.startDate < Date()) {
                totalHours += shift.durationHours
            }
            
            switch shift.status {
            case .swappedOut:
                // Saída: Hospital me deve (Bruto), Eu devo ao colega (Despesa)
                grossIncome += shift.amount
                expenses += shift.swapValue
                
                // Caixa Real:
                if shift.isPaid {
                    totalReceived += shift.amount // Entrou o dinheiro do hospital
                }
                if shift.swapIsSettled {
                    totalPaid += shift.swapValue // Saiu o dinheiro pro colega
                }
                
            case .swappedIn:
                // Entrada: Colega me deve
                grossIncome += shift.swapValue
                
                // Caixa Real:
                if shift.swapIsSettled {
                    totalReceived += shift.swapValue // Entrou o dinheiro do colega
                }
                
            default: // Scheduled ou Completed
                // Normal: Hospital me deve
                grossIncome += shift.amount
                
                // Caixa Real:
                if shift.isPaid {
                    totalReceived += shift.amount // Entrou o dinheiro do hospital
                }
            }
        }
        
        return MonthStats(
            totalHours: totalHours,
            grossIncome: grossIncome,
            expenses: expenses,
            netIncome: grossIncome - expenses,
            totalReceived: totalReceived,
            totalPaid: totalPaid
        )
    }
    
    struct MonthStats {
        let totalHours: Int
        let grossIncome: Double
        let expenses: Double
        let netIncome: Double
        
        let totalReceived: Double
        let totalPaid: Double
        
        // Saldo Real = Tudo que entrou - Tudo que saiu
        var cashOnHand: Double { totalReceived - totalPaid }
    }
    
    // --- FILTROS ---
    var receivables: [Shift] {
        let now = Date()
        return shifts.filter { shift in
            if shift.isCommitment { return false }
            // Só mostra se a data já passou ou trabalho feito ou é repasse
            let isFinancialActive = shift.startDate < now || shift.isWorkDone || shift.status == .swappedOut
            if !isFinancialActive { return false }
            
            // Regras
            return (shift.status != .swappedOut && shift.status != .swappedIn && !shift.isPaid) ||
                   (shift.status == .swappedOut && !shift.isPaid) ||
                   (shift.status == .swappedIn && !shift.swapIsSettled)
        }.sorted { $0.startDate < $1.startDate }
    }
    
    var payables: [Shift] {
        let now = Date()
        return shifts.filter { shift in
            if shift.isCommitment { return false }
            // Só mostra se a data já passou ou trabalho feito ou é repasse
            let isFinancialActive = shift.startDate < now || shift.isWorkDone || shift.status == .swappedOut
            if !isFinancialActive { return false }
            
            // Regra
            return shift.status == .swappedOut && !shift.swapIsSettled
        }.sorted { $0.startDate < $1.startDate }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Picker("Visão", selection: $selectedTab) {
                        Text("Resumo do Mês").tag(0)
                        Text("Gestão de Pendências").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    .background(Color(.systemBackground))
                    
                    if selectedTab == 0 {
                        ScrollView {
                            VStack(spacing: 20) {
                                // Seletor de Mês
                                HStack {
                                    Button(action: { withAnimation { changeMonth(by: -1) } }) { Image(systemName: "chevron.left").font(.title3.bold()).foregroundStyle(Color.medBlue) }
                                    Spacer()
                                    Text(selectedDate.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "pt_BR")))).medFont(.title2, weight: .bold).textCase(.uppercase)
                                    Spacer()
                                    Button(action: { withAnimation { changeMonth(by: 1) } }) { Image(systemName: "chevron.right").font(.title3.bold()).foregroundStyle(Color.medBlue) }
                                }
                                .padding().background(Color(.systemBackground)).clipShape(RoundedRectangle(cornerRadius: 16))
                                
                                // CARD LUCRO LÍQUIDO (PREVISÃO)
                                VStack(alignment: .leading, spacing: 20) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text("Lucro Líquido Estimado").medFont(.caption, weight: .bold).foregroundStyle(.white.opacity(0.8)).textCase(.uppercase)
                                            Text(monthStats.netIncome.formatted(.currency(code: "BRL")))
                                                .font(.system(size: 32, weight: .black, design: .rounded))
                                                .foregroundStyle(.white)
                                        }
                                        Spacer()
                                        Image(systemName: "chart.pie.fill").font(.title).foregroundStyle(.white.opacity(0.8))
                                    }
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text("Faturamento Bruto").medFont(.caption2).foregroundStyle(.white.opacity(0.8))
                                            Text(monthStats.grossIncome.formatted(.currency(code: "BRL"))).medFont(.subheadline, weight: .bold).foregroundStyle(.white)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing) {
                                            Text("Repasses (Previsto)").medFont(.caption2).foregroundStyle(.white.opacity(0.8))
                                            Text("- \(monthStats.expenses.formatted(.currency(code: "BRL")))").medFont(.subheadline, weight: .bold).foregroundStyle(Color.white)
                                        }
                                    }
                                }
                                .padding(25)
                                .background(LinearGradient(colors: [.medBlue, .medPurple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                                .shadow(color: .medBlue.opacity(0.3), radius: 15, y: 10)
                                
                                // --- FLUXO DE CAIXA REAL (CORRIGIDO) ---
                                VStack(spacing: 0) {
                                    // Entradas Totais
                                    DetailRow(title: "Total Já Recebido (Entradas)", value: monthStats.totalReceived, color: .medGreen, icon: "arrow.down.left")
                                    
                                    Divider()
                                    
                                    // Saídas Totais
                                    DetailRow(title: "Total Pago (Repasses)", value: -monthStats.totalPaid, color: .medRed, icon: "arrow.up.right")
                                    
                                    Divider()
                                    
                                    // Saldo (Em Caixa)
                                    HStack {
                                        Image(systemName: "building.columns.fill")
                                            .foregroundStyle(Color.medBlue)
                                        Text("Em Caixa (Saldo Real)")
                                            .medFont(.body, weight: .bold)
                                        Spacer()
                                        // AQUI ESTÁ A MÁGICA: Recebido - Pago
                                        Text(monthStats.cashOnHand.formatted(.currency(code: "BRL")))
                                            .medFont(.title3, weight: .black)
                                            .foregroundStyle(Color.medBlue)
                                    }
                                    .padding()
                                    .background(Color.medBlue.opacity(0.05))
                                }
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                                
                                // EXTRATO
                                VStack(alignment: .leading, spacing: 15) {
                                    Text("Movimentações").medFont(.headline).padding(.leading, 5)
                                    let currentShifts = shifts.filter {
                                        Calendar.current.isDate($0.startDate, equalTo: selectedDate, toGranularity: .month) &&
                                        Calendar.current.isDate($0.startDate, equalTo: selectedDate, toGranularity: .year)
                                    }.sorted { $0.startDate < $1.startDate }
                                    
                                    if currentShifts.isEmpty {
                                        ContentUnavailableView("Sem Dados", systemImage: "list.bullet.rectangle.portrait")
                                    } else {
                                        ForEach(currentShifts) { shift in FinancialRow(shift: shift) }
                                    }
                                }
                            }
                            .padding()
                        }
                    } else {
                        // ABA PENDÊNCIAS
                        VStack {
                            if receivables.isEmpty && payables.isEmpty {
                                ContentUnavailableView("Tudo em Dia", systemImage: "checkmark.circle.fill", description: Text("Nenhuma pendência financeira.")).padding(.top, 50)
                                Spacer()
                            } else {
                                List(selection: $selectedShiftIDs) {
                                    if !receivables.isEmpty {
                                        Section(header: Text("A RECEBER").font(.caption).bold().foregroundStyle(Color.medBlue)) {
                                            ForEach(receivables) { shift in PendingRow(shift: shift, type: .receivable).tag(shift.id) }
                                        }
                                    }
                                    if !payables.isEmpty {
                                        Section(header: Text("A PAGAR (REPASSES)").font(.caption).bold().foregroundStyle(Color.medRed)) {
                                            ForEach(payables) { shift in PendingRow(shift: shift, type: .payable).tag(shift.id) }
                                        }
                                    }
                                }
                                .listStyle(.insetGrouped)
                                .environment(\.editMode, $editMode)
                                
                                if !selectedShiftIDs.isEmpty {
                                    Button(action: confirmSelected) {
                                        Text("Confirmar Baixa (\(selectedShiftIDs.count))")
                                            .medFont(.headline, weight: .bold)
                                            .foregroundStyle(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(Color.medBlue)
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                            .shadow(radius: 5)
                                    }
                                    .padding()
                                    .background(Color(.systemBackground))
                                }
                            }
                        }
                        .onAppear { editMode = .active }
                    }
                }
            }
            .navigationTitle("Gestão Financeira")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    func confirmSelected() {
        withAnimation {
            for id in selectedShiftIDs {
                if let shift = shifts.first(where: { $0.id == id }) {
                    if shift.status == .swappedOut {
                        if payables.contains(shift) { shift.swapIsSettled = true }
                        if receivables.contains(shift) { shift.isPaid = true }
                    } else if shift.status == .swappedIn { shift.swapIsSettled = true }
                    else { shift.isPaid = true }
                }
            }
            selectedShiftIDs.removeAll()
        }
    }
    func changeMonth(by value: Int) { if let newDate = Calendar.current.date(byAdding: .month, value: value, to: selectedDate) { selectedDate = newDate } }
}

// ... (Mantenha FinancialRow, PendingRow, DetailRow iguais) ...
struct FinancialRow: View {
    let shift: Shift
    var body: some View {
        HStack {
            Text(shift.startDate.formatted(.dateTime.day())).medFont(.title3, weight: .bold).frame(width: 35).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(shift.locationName).medFont(.subheadline, weight: .semibold).lineLimit(1)
                Text(shift.isCommitment ? "Compromisso" : shiftStatusText(shift)).medFont(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !shift.isCommitment {
                VStack(alignment: .trailing) {
                    if shift.status == .swappedOut {
                        Text("- \(shift.swapValue.formatted(.currency(code: "BRL")))").medFont(.subheadline, weight: .bold).foregroundStyle(Color.medRed)
                    } else {
                        let val = shift.status == .swappedIn ? shift.swapValue : shift.amount
                        Text(val.formatted(.currency(code: "BRL"))).medFont(.subheadline, weight: .bold).foregroundStyle(shift.status == .swappedIn ? Color.medBlue : .primary)
                    }
                }
            }
        }.padding().background(Color(.systemBackground)).clipShape(RoundedRectangle(cornerRadius: 12))
    }
    func shiftStatusText(_ s: Shift) -> String {
        switch s.status { case .swappedOut: return "Repasse"; case .swappedIn: return "Entrada"; default: return s.isWorkDone ? "Realizado" : "Agendado" }
    }
}

enum PendingType { case receivable, payable }
struct PendingRow: View {
    let shift: Shift; let type: PendingType
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(shift.locationName).medFont(.body, weight: .bold)
                Text(shift.startDate.formatted(date: .numeric, time: .shortened)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            let amount = (type == .payable || shift.status == .swappedIn) ? shift.swapValue : shift.amount
            Text(amount.formatted(.currency(code: "BRL"))).medFont(.callout, weight: .bold).foregroundStyle(type == .payable ? Color.medRed : Color.medGreen)
        }
    }
}

struct DetailRow: View {
    let title: String; let value: Double; let color: Color; var icon: String? = nil
    var body: some View {
        HStack {
            if let icon = icon { Image(systemName: icon).foregroundStyle(color).frame(width: 20) }
            Text(title).medFont(.body)
            Spacer()
            Text(value.formatted(.currency(code: "BRL"))).medFont(.headline).foregroundStyle(color)
        }.padding()
    }
}
