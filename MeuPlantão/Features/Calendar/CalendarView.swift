import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) var modelContext
    @Query var shifts: [Shift]
    
    @State private var currentMonth: Date = Date()
    @State private var selectedDate: Date = Date()
    @State private var showingAddSheet = false
    
    // Alertas de Exclusão
    @State private var shiftToDelete: Shift?
    @State private var showDeleteConfirmation = false
    
    let daysOfWeek = ["D", "S", "T", "Q", "Q", "S", "S"]
    let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // --- 1. O CALENDÁRIO (WIDGET) ---
                    VStack(spacing: 15) {
                        // Navegação Mês
                        HStack {
                            Button(action: { withAnimation { changeMonth(by: -1) } }) {
                                Image(systemName: "chevron.left")
                                    .font(.title3.bold())
                                    .foregroundStyle(Color.medBlue)
                            }
                            Spacer()
                            Text(currentMonth.formatted(.dateTime.month(.wide).year()).capitalized)
                                .medFont(.title3, weight: .bold)
                                .foregroundStyle(Color.primary)
                            Spacer()
                            Button(action: { withAnimation { changeMonth(by: 1) } }) {
                                Image(systemName: "chevron.right")
                                    .font(.title3.bold())
                                    .foregroundStyle(Color.medBlue)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Dias da Semana
                        HStack {
                            ForEach(daysOfWeek, id: \.self) { day in
                                Text(day)
                                    .medFont(.caption, weight: .bold)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        
                        // Grade de Dias
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(currentMonth.getAllDays(), id: \.self) { date in
                                let hasShift = shifts.contains { $0.startDate.isSameDay(as: date) }
                                let isSelected = selectedDate.isSameDay(as: date)
                                let isToday = date.isSameDay(as: Date())
                                
                                Button(action: {
                                    withAnimation(.spring(response: 0.3)) { selectedDate = date }
                                }) {
                                    VStack(spacing: 4) {
                                        Text(date.format("d"))
                                            .medFont(.body, weight: isSelected ? .bold : .regular)
                                            .foregroundStyle(isSelected ? .white : (isToday ? Color.medBlue : .primary))
                                        
                                        // Indicador de Plantão (Bolinha)
                                        if hasShift {
                                            Circle()
                                                .fill(isSelected ? .white : Color.medGreen)
                                                .frame(width: 5, height: 5)
                                        } else {
                                            Circle().fill(.clear).frame(width: 5, height: 5)
                                        }
                                    }
                                    .frame(height: 40)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        ZStack {
                                            if isSelected {
                                                Circle()
                                                    .fill(LinearGradient(colors: [.medBlue, .medPurple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                            }
                                        }
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)
                    
                    // --- 2. LISTA DO DIA SELECIONADO ---
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Agenda do Dia")
                                .medFont(.headline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(selectedDate.formatted(.dateTime.day().month(.wide)))
                                .medFont(.subheadline)
                                .foregroundStyle(Color.medBlue)
                        }
                        .padding(.horizontal)
                        
                        let daysShifts = shifts.filter { $0.startDate.isSameDay(as: selectedDate) }
                        
                        if daysShifts.isEmpty {
                            Spacer()
                            ContentUnavailableView(
                                "Dia Livre",
                                systemImage: "beach.umbrella",
                                description: Text("Aproveite seu descanso!")
                            )
                            Spacer()
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(daysShifts) { shift in
                                        ShiftRowCard(shift: shift)
                                            .contextMenu {
                                                Button(role: .destructive) { requestDelete(shift) } label: {
                                                    Label("Excluir", systemImage: "trash")
                                                }
                                            }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Escala")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAddSheet = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Color.medBlue)
                            .clipShape(Circle())
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) { AddShiftView() }
            .confirmationDialog("Excluir", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Excluir apenas este", role: .destructive) { if let s = shiftToDelete { deleteSingleShift(s) } }
                if let s = shiftToDelete, s.recurrenceID != nil {
                    Button("Excluir toda a série", role: .destructive) { deleteShiftSeries(recurrenceID: s.recurrenceID!) }
                }
                Button("Cancelar", role: .cancel) { shiftToDelete = nil }
            } message: { Text("Como deseja excluir?") }
        }
    }
    
    // Helpers
    func changeMonth(by value: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newMonth
        }
    }
    
    func requestDelete(_ shift: Shift) {
        shiftToDelete = shift
        if shift.recurrenceID != nil { showDeleteConfirmation = true } else { deleteSingleShift(shift) }
    }
    
    func deleteSingleShift(_ shift: Shift) {
        NotificationManager.shared.cancelNotification(for: shift)
        modelContext.delete(shift)
        shiftToDelete = nil
    }
    
    func deleteShiftSeries(recurrenceID: String) {
        let list = shifts.filter { $0.recurrenceID == recurrenceID }
        for s in list { NotificationManager.shared.cancelNotification(for: s); modelContext.delete(s) }
        shiftToDelete = nil
    }
}
