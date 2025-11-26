import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Shift.startDate, order: .forward) var shifts: [Shift]
    
    @State private var showingAddSheet = false
    @State private var showingSettings = false
    
    // 1. PRÓXIMO (Destaque)
    var nextShift: Shift? {
        shifts.first { $0.startDate > Date() && $0.status != .swappedOut }
    }
    
    // 2. SEGUINTES (Lista)
    var subsequentShifts: [Shift] {
        let now = Date()
        let upcoming = shifts.filter { $0.startDate > now && $0.status != .swappedOut }
                             .sorted { $0.startDate < $1.startDate }
        return Array(upcoming.dropFirst().prefix(2))
    }
    
    // --- CÁLCULOS DE HORAS (CORRIGIDO: Ignora Compromissos) ---
    var hoursStats: (worked: Int, toWork: Int, total: Int, progress: Double) {
        let calendar = Calendar.current
        let now = Date()
        
        let monthShifts = shifts.filter {
            calendar.isDate($0.startDate, equalTo: now, toGranularity: .month) &&
            calendar.isDate($0.startDate, equalTo: now, toGranularity: .year) &&
            $0.status != .swappedOut &&
            !$0.isCommitment // <--- AQUI ESTÁ A CORREÇÃO
        }
        
        let worked = monthShifts.filter { $0.startDate < now || $0.isWorkDone }.reduce(0) { $0 + $1.durationHours }
        let toWork = monthShifts.filter { $0.startDate >= now && !$0.isWorkDone }.reduce(0) { $0 + $1.durationHours }
        let total = worked + toWork
        let progress = total > 0 ? Double(worked) / Double(total) : 0.0
        
        return (worked, toWork, total, progress)
    }
    
    // --- CÁLCULOS FINANCEIROS ---
    var finStats: (bruto: Double, repasse: Double, liquido: Double, recebido: Double, aReceber: Double) {
        let calendar = Calendar.current
        let now = Date()
        let monthShifts = shifts.filter {
            calendar.isDate($0.startDate, equalTo: now, toGranularity: .month) &&
            calendar.isDate($0.startDate, equalTo: now, toGranularity: .year)
        }
        
        var bruto = 0.0; var repasse = 0.0; var recebido = 0.0
        
        for shift in monthShifts {
            // Compromissos já têm valor 0, então não afetam financeiro, mas por segurança:
            if shift.isCommitment { continue }
            
            if shift.status == .swappedOut {
                bruto += shift.amount
                repasse += shift.swapValue
                if shift.isPaid { recebido += shift.amount }
                if shift.swapIsSettled { recebido -= shift.swapValue }
            } else if shift.status == .swappedIn {
                bruto += shift.swapValue
                if shift.swapIsSettled { recebido += shift.swapValue }
            } else {
                bruto += shift.amount
                if shift.isPaid { recebido += shift.amount }
            }
        }
        
        let liquido = bruto - repasse
        let aReceber = liquido - recebido
        
        return (bruto, repasse, liquido, recebido, aReceber)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // HEADER
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(getDateGreeting()).medFont(.subheadline, weight: .medium).foregroundStyle(.secondary)
                                Text("MeuPlantão").medFont(.largeTitle, weight: .black)
                                    .foregroundStyle(LinearGradient(colors: [.medBlue, .medPurple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            }
                            Spacer()
                            HStack(spacing: 12) {
                                Button(action: { showingSettings = true }) {
                                    Image(systemName: "gearshape.fill").font(.title3).foregroundStyle(.gray)
                                        .frame(width: 44, height: 44).background(Color.white).clipShape(Circle())
                                }
                                Button(action: { showingAddSheet = true }) {
                                    Image(systemName: "plus").font(.title3).fontWeight(.bold).foregroundStyle(.white)
                                        .frame(width: 48, height: 48).background(Color.medBlue).clipShape(Circle())
                                }
                            }
                        }
                        
                        // 1. PRÓXIMO
                        if let shift = nextShift {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("A seguir").medFont(.caption, weight: .bold).foregroundStyle(.secondary).textCase(.uppercase)
                                NavigationLink(destination: ShiftDetailView(shift: shift)) {
                                    NextShiftCard(shift: shift)
                                }
                            }
                        } else {
                            EmptyStateCard()
                        }
                        
                        // 2. HORAS TRABALHADAS (Produtividade)
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Horas Trabalhadas (Mês)").medFont(.headline).padding(.leading, 4)
                            
                            VStack(spacing: 20) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Realizado").medFont(.subheadline).foregroundStyle(.secondary)
                                        Text("\(hoursStats.worked)h").medFont(.title, weight: .bold).foregroundStyle(Color.medBlue)
                                    }
                                    Spacer()
                                    Divider()
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        Text("Planejado").medFont(.subheadline).foregroundStyle(.secondary)
                                        Text("\(hoursStats.total)h").medFont(.title, weight: .bold).foregroundStyle(Color.medOrange)
                                    }
                                }
                                
                                GeometryReader { g in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray5))
                                        RoundedRectangle(cornerRadius: 10).fill(LinearGradient(colors: [.medBlue, .medPurple], startPoint: .leading, endPoint: .trailing))
                                            .frame(width: max(0, CGFloat(hoursStats.progress) * g.size.width))
                                            .animation(.spring, value: hoursStats.progress)
                                    }
                                }.frame(height: 12)
                                
                                Text("\(Int(hoursStats.progress * 100))% concluído")
                                    .medFont(.caption).bold().foregroundStyle(.secondary)
                            }
                            .padding(20)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
                        }
                        
                        // 3. SEGUINTES
                        if !subsequentShifts.isEmpty {
                            VStack(alignment: .leading, spacing: 15) {
                                HStack {
                                    Text("Próximos da Fila").medFont(.headline)
                                    Spacer()
                                    NavigationLink(destination: CalendarView()) {
                                        Text("Ver agenda completa").medFont(.caption, weight: .bold).foregroundStyle(Color.medBlue)
                                    }
                                }
                                .padding(.leading, 4)
                                
                                ForEach(subsequentShifts) { shift in
                                    NavigationLink(destination: ShiftDetailView(shift: shift)) {
                                        NextShiftCard(shift: shift)
                                    }
                                }
                            }
                        }
                        
                        // 4. FINANCEIRO
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Resumo Financeiro").medFont(.headline).padding(.leading, 4)
                            
                            VStack(spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Líquido Esperado").medFont(.caption).foregroundStyle(.secondary)
                                        Text(finStats.liquido.formatted(.currency(code: "BRL")))
                                            .medFont(.title2, weight: .black).foregroundStyle(Color.medBlue)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        Text("A Receber").medFont(.caption).foregroundStyle(.secondary)
                                        Text(finStats.aReceber.formatted(.currency(code: "BRL")))
                                            .medFont(.headline, weight: .bold).foregroundStyle(Color.medOrange)
                                    }
                                }
                                Divider()
                                HStack(spacing: 20) {
                                    MiniStat(label: "Bruto", value: finStats.bruto, color: .primary)
                                    MiniStat(label: "Repasses", value: finStats.repasse, color: .medRed)
                                    MiniStat(label: "Em Caixa", value: finStats.recebido, color: .medGreen)
                                }
                            }
                            .medCard()
                        }
                    }
                    .padding()
                    .padding(.bottom, 20)
                }
            }
            .sheet(isPresented: $showingAddSheet) { AddShiftView() }
            .sheet(isPresented: $showingSettings) { SettingsView() }
        }
    }
    
    func getDateGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour { case 6..<12: return "Bom dia"; case 12..<18: return "Boa tarde"; default: return "Boa noite" }
    }
}

// ... (Mantenha as structs visuais iguais ao anterior) ...
struct MiniStat: View {
    let label: String; let value: Double; let color: Color
    var body: some View {
        VStack(alignment: .leading) {
            Text(label).medFont(.caption2).foregroundStyle(.secondary)
            Text(value.formatted(.currency(code: "BRL")))
                .medFont(.subheadline, weight: .bold).foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.8)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NextShiftCard: View {
    let shift: Shift
    var body: some View {
        HStack(alignment: .top) {
            VStack(spacing: 0) {
                Text(shift.startDate.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .medFont(.caption2, weight: .bold).foregroundStyle(.white.opacity(0.8))
                Text(shift.startDate.formatted(.dateTime.day()))
                    .medFont(.title, weight: .bold).foregroundStyle(.white)
            }
            .padding(10).background(Color.white.opacity(0.2)).clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 6) {
                Text(shift.locationName).medFont(.title3, weight: .bold).lineLimit(1).foregroundStyle(.white)
                Text(shift.startDate.formatted(.dateTime.weekday(.wide).hour().minute().locale(Locale(identifier: "pt_BR"))).capitalized)
                    .medFont(.subheadline).foregroundStyle(.white.opacity(0.9))
                HStack {
                    if shift.isCommitment {
                        Badge(text: "COMPROMISSO", color: .white.opacity(0.25))
                    } else {
                        Badge(text: "\(shift.durationHours)h", color: .white.opacity(0.25))
                        if shift.status == .swappedIn { Badge(text: shift.swapValue.formatted(.currency(code: "BRL")), color: .medGreen.opacity(0.8)) }
                        else if shift.amount > 0 { Badge(text: shift.amount.formatted(.currency(code: "BRL")), color: .white.opacity(0.25)) }
                    }
                }.padding(.top, 4)
            }
            .padding(.leading, 8)
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.6)).padding(.top, 4)
        }
        .padding(20)
        .background(LinearGradient(colors: [.medBlue, .medPurple], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .medBlue.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

struct EmptyStateCard: View {
    var body: some View {
        HStack {
            Image(systemName: "calendar.badge.clock").font(.largeTitle).foregroundStyle(Color.medBlue.opacity(0.5))
            VStack(alignment: .leading) {
                Text("Agenda Livre").medFont(.headline)
                Text("Toque no + para agendar.").medFont(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }.medCard()
    }
}

struct Badge: View {
    let text: String; var color: Color
    var body: some View { Text(text).medFont(.caption2, weight: .bold).padding(.horizontal, 10).padding(.vertical, 5).background(color).clipShape(Capsule()).foregroundStyle(.white) }
}
