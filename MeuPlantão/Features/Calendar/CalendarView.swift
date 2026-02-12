import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) var modelContext
    @Query var shifts: [Shift]
    
    @State private var currentMonth: Date = Date()
    @State private var selectedDate: Date = Date()
    @State private var showingAddSheet = false
    @State private var shiftToDelete: Shift?
    @State private var showDeleteConfirmation = false
    
    let daysOfWeek = ["D", "S", "T", "Q", "Q", "S", "S"]
    let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // CALENDÁRIO
                    VStack(spacing: 15) {
                        HStack {
                            Button(action: {
                                HapticManager.shared.selection()
                                withAnimation { changeMonth(by: -1) }
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.title3.bold())
                                    .foregroundStyle(Color.medBlue)
                            }
                            
                            Spacer()
                            
                            Text(currentMonth.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "pt_BR"))).capitalized)
                                .medFont(.title3, weight: .bold)
                                .foregroundStyle(Color.primary)
                            
                            Spacer()
                            
                            Button(action: {
                                HapticManager.shared.selection()
                                withAnimation { changeMonth(by: 1) }
                            }) {
                                Image(systemName: "chevron.right")
                                    .font(.title3.bold())
                                    .foregroundStyle(Color.medBlue)
                            }
                        }
                        .padding(.horizontal)
                        
                        HStack {
                            ForEach(daysOfWeek, id: \.self) { day in
                                Text(day)
                                    .medFont(.caption, weight: .bold)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(currentMonth.getAllDays(), id: \.self) { date in
                                let dayShifts = shifts.filter { $0.startDate.isSameDay(as: date) }
                                let hasShift = !dayShifts.isEmpty
                                let hasCommitment = dayShifts.contains { $0.isCommitment }
                                let hasWork = dayShifts.contains { !$0.isCommitment }
                                let isSelected = selectedDate.isSameDay(as: date)
                                let isToday = date.isSameDay(as: Date())
                                
                                Button(action: {
                                    HapticManager.shared.selection()
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedDate = date
                                    }
                                }) {
                                    VStack(spacing: 4) {
                                        Text(date.format("d"))
                                            .medFont(.body, weight: isSelected ? .bold : .regular)
                                            .foregroundStyle(isSelected ? .white : (isToday ? Color.medBlue : .primary))
                                        
                                        // Indicadores visuais melhorados
                                        HStack(spacing: 2) {
                                            if hasWork {
                                                Circle()
                                                    .fill(isSelected ? .white : Color.medGreen)
                                                    .frame(width: 5, height: 5)
                                            }
                                            if hasCommitment {
                                                Circle()
                                                    .fill(isSelected ? .white : Color.gray)
                                                    .frame(width: 5, height: 5)
                                            }
                                            if !hasShift {
                                                Circle()
                                                    .fill(.clear)
                                                    .frame(width: 5, height: 5)
                                            }
                                        }
                                    }
                                    .frame(height: 40)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        ZStack {
                                            if isSelected {
                                                Circle()
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [.medBlue, .medPurple],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    )
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
                    
                    // LISTA DO DIA
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Agenda do Dia")
                                .medFont(.headline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(selectedDate.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "pt_BR"))))
                                .medFont(.subheadline)
                                .foregroundStyle(Color.medBlue)
                        }
                        .padding(.horizontal)
                        
                        let daysShifts = shifts.filter { $0.startDate.isSameDay(as: selectedDate) }
                            .sorted { $0.startDate < $1.startDate }
                        
                        if daysShifts.isEmpty {
                            Spacer()
                            ContentUnavailableView {
                                Label("Dia Livre", systemImage: "beach.umbrella")
                            } description: {
                                Text("Aproveite seu descanso!")
                            } actions: {
                                Button("Adicionar Plantão") {
                                    showingAddSheet = true
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.medBlue)
                            }
                            Spacer()
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(daysShifts) { shift in
                                        ShiftRowCard(shift: shift)
                                            .contextMenu {
                                                Button(role: .destructive) {
                                                    HapticManager.shared.notification(.warning)
                                                    requestDelete(shift)
                                                } label: {
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
                    Button {
                        HapticManager.shared.impact(.light)
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Color.medBlue)
                            .clipShape(Circle())
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddShiftView()
            }
            .confirmationDialog(
                "Excluir Plantão",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Excluir apenas este", role: .destructive) {
                    if let s = shiftToDelete {
                        HapticManager.shared.notification(.success)
                        deleteSingleShift(s)
                    }
                }
                
                if let s = shiftToDelete, s.recurrenceID != nil {
                    let futureCount = calculateFutureShiftsCount(s)
                    Button("Excluir este e \(futureCount) futuros", role: .destructive) {
                        HapticManager.shared.notification(.success)
                        deleteShiftSeries(triggerShift: s)
                    }
                }
                
                Button("Cancelar", role: .cancel) {
                    shiftToDelete = nil
                }
            } message: {
                if let s = shiftToDelete, s.recurrenceID != nil {
                    Text("Este plantão faz parte de uma série recorrente. Você pode excluir apenas este ou todos os futuros.")
                } else {
                    Text("Tem certeza que deseja excluir este plantão?")
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    func changeMonth(by value: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newMonth
        }
    }
    
    func requestDelete(_ shift: Shift) {
        shiftToDelete = shift
        if shift.recurrenceID != nil {
            showDeleteConfirmation = true
        } else {
            deleteSingleShift(shift)
        }
    }
    
    func deleteSingleShift(_ shift: Shift) {
        NotificationManager.shared.cancelNotification(for: shift)
        modelContext.delete(shift)
        shiftToDelete = nil
    }
    
    func calculateFutureShiftsCount(_ shift: Shift) -> Int {
        guard let recID = shift.recurrenceID else { return 0 }
        let triggerDate = shift.startDate
        
        return shifts.filter {
            $0.recurrenceID == recID && $0.startDate >= triggerDate
        }.count - 1 // -1 para não contar o atual
    }
    
    func deleteShiftSeries(triggerShift: Shift) {
        guard let recID = triggerShift.recurrenceID else { return }
        let triggerDate = triggerShift.startDate
        
        let listToDelete = shifts.filter {
            $0.recurrenceID == recID && $0.startDate >= triggerDate
        }
        
        for s in listToDelete {
            NotificationManager.shared.cancelNotification(for: s)
            modelContext.delete(s)
        }
        shiftToDelete = nil
    }
}
