import SwiftUI
import SwiftData

// ... (Mantenha o ContentView e ShiftsHistoryView iguais, vamos mudar apenas o ShiftRowCard no final) ...

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView().tabItem { Label("Início", systemImage: "house.fill") }
            CalendarView().tabItem { Label("Escala", systemImage: "calendar") }
            FinancialAnalyticsView().tabItem { Label("Financeiro", systemImage: "banknote.fill") }
            ShiftsHistoryView().tabItem { Label("Histórico", systemImage: "clock.arrow.circlepath") }
        }
        .tint(Color.medBlue)
    }
}

struct ShiftsHistoryView: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Shift.startDate, order: .forward) var shifts: [Shift]
    @State private var showingAddSheet = false
    @State private var filterMode: Int = 0
    @State private var shiftToDelete: Shift?
    @State private var showDeleteConfirmation = false
    
    var filteredShifts: [Shift] {
        let now = Date()
        if filterMode == 0 {
            return shifts.filter { $0.startDate >= now && !$0.isWorkDone && $0.status != .swappedOut }
        } else {
            return shifts.filter { $0.startDate < now || $0.isWorkDone || $0.status == .swappedOut || $0.status == .swappedIn }
                .sorted { $0.startDate > $1.startDate }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                VStack(spacing: 0) {
                    Picker("Filtro", selection: $filterMode) { Text("Agenda").tag(0); Text("Histórico").tag(1) }
                        .pickerStyle(.segmented).padding().background(Color(.systemBackground))
                    
                    if filteredShifts.isEmpty {
                        Spacer()
                        ContentUnavailableView(filterMode == 0 ? "Agenda Livre" : "Histórico Vazio", systemImage: filterMode == 0 ? "calendar.badge.checkmark" : "archivebox")
                        Spacer()
                    } else {
                        List {
                            ForEach(filteredShifts) { shift in
                                ShiftRowCard(shift: shift)
                                    .listRowSeparator(.hidden).listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) { requestDelete(shift) } label: { Label("Excluir", systemImage: "trash") }
                                    }
                            }
                        }.listStyle(.plain)
                    }
                }
            }
            .navigationTitle(filterMode == 0 ? "Próximos" : "Histórico")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus").font(.system(size: 16, weight: .bold)).foregroundStyle(.white).padding(8).background(Color.medBlue).clipShape(Circle())
                }
            }
            .sheet(isPresented: $showingAddSheet) { AddShiftView() }
            .confirmationDialog("Excluir", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Excluir apenas este", role: .destructive) { if let s = shiftToDelete { deleteSingleShift(s) } }
                if let s = shiftToDelete, s.recurrenceID != nil { Button("Excluir toda a série", role: .destructive) { deleteShiftSeries(recurrenceID: s.recurrenceID!) } }
                Button("Cancelar", role: .cancel) { shiftToDelete = nil }
            } message: { Text("Como deseja excluir?") }
        }
    }
    
    func requestDelete(_ shift: Shift) { shiftToDelete = shift; if shift.recurrenceID != nil { showDeleteConfirmation = true } else { deleteSingleShift(shift) } }
    func deleteSingleShift(_ shift: Shift) { NotificationManager.shared.cancelNotification(for: shift); modelContext.delete(shift); shiftToDelete = nil }
    func deleteShiftSeries(recurrenceID: String) { let list = shifts.filter { $0.recurrenceID == recurrenceID }; for s in list { NotificationManager.shared.cancelNotification(for: s); modelContext.delete(s) }; shiftToDelete = nil }
}

struct ShiftRowCard: View {
    let shift: Shift
    
    var body: some View {
        NavigationLink(destination: ShiftDetailView(shift: shift)) {
            HStack(spacing: 15) {
                VStack(spacing: 2) {
                    Text(shift.startDate.formatted(.dateTime.day())).medFont(.title3, weight: .bold).foregroundStyle(statusColor(for: shift))
                    Text(shift.startDate.formatted(.dateTime.month(.abbreviated)).uppercased()).medFont(.caption2, weight: .bold).foregroundStyle(.secondary)
                }.frame(minWidth: 40)
                
                Rectangle().fill(Color(.systemGray5)).frame(width: 1, height: 35)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(shift.locationName).medFont(.body, weight: .semibold).lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text("\(shift.startDate.formatted(date: .omitted, time: .shortened))").medFont(.caption).foregroundStyle(.secondary)
                        
                        if shift.isCommitment {
                            BadgeMini(text: "COMPROMISSO", color: .gray)
                        } else if shift.isWorkDone { BadgeMini(text: "FEITO", color: .medGreen) }
                        else if shift.status == .swappedOut { BadgeMini(text: "SAÍ", color: .medRed); if shift.swapIsSettled { BadgeMini(text: "PAGO", color: .medGreen) } else { BadgeMini(text: "DEVENDO", color: .medRed) } }
                        else if shift.status == .swappedIn { BadgeMini(text: "ENTREI", color: .medBlue); if shift.swapIsSettled { BadgeMini(text: "RECEBIDO", color: .medGreen) } }
                    }
                }
                
                Spacer()
                
                // Se for compromisso, não mostra valor, mostra "DIA TODO" ou Horas
                VStack(alignment: .trailing) {
                    if !shift.isCommitment {
                        if shift.status == .swappedOut { Text("- \(shift.swapValue.formatted(.currency(code: "BRL")))").medFont(.subheadline, weight: .bold).foregroundStyle(Color.medRed) }
                        else if shift.status == .swappedIn { Text(shift.swapValue.formatted(.currency(code: "BRL"))).medFont(.subheadline, weight: .bold).foregroundStyle(Color.medBlue) }
                        else { Text(shift.amount.formatted(.currency(code: "BRL"))).medFont(.subheadline, weight: .bold).foregroundStyle(Color.primary) }
                    }
                    
                    // Mostra duração ou "Dia Todo"
                    if shift.isAllDay {
                        Text("Dia Todo").medFont(.caption2, weight: .bold).foregroundStyle(.secondary)
                    } else {
                        Text("\(shift.durationHours)h").medFont(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(14).background(Color(.systemBackground)).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(0.03), lineWidth: 1))
        }.buttonStyle(.plain)
    }
    
    func statusColor(for shift: Shift) -> Color {
        if shift.isCommitment { return .gray }
        if shift.isWorkDone { return .medGreen }
        switch shift.status {
        case .swappedOut: return .medRed
        case .swappedIn: return .medBlue
        default: return shift.startDate < Date() ? .medOrange : .medBlue
        }
    }
}

struct BadgeMini: View {
    let text: String; let color: Color
    var body: some View { Text(text).medFont(.caption2, weight: .bold).foregroundStyle(color).padding(.horizontal, 6).padding(.vertical, 2).background(color.opacity(0.1)).cornerRadius(4) }
}
