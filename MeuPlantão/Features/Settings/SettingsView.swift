import SwiftUI
import SwiftData
import StoreKit

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    @Query(sort: \Shift.startDate, order: .forward) var shifts: [Shift]
    @StateObject private var calendarManager = CalendarSyncManager.shared
    @StateObject private var storeManager = StoreManager.shared
    
    // --- PREFERÊNCIAS (Padrões) ---
    @AppStorage("defaultAmount") private var defaultAmount: Double = 0.0
    @AppStorage("defaultDuration") private var defaultDurationRaw: Int = 12
    
    // --- PREFERÊNCIAS (Notificações) ---
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @AppStorage("notifyOnDay") private var notifyOnDay: Bool = true
    @AppStorage("notify24hBefore") private var notify24hBefore: Bool = true
    
    // Controles de Tela
    @State private var showingTerms = false
    @State private var isShareSheetPresented = false
    @State private var csvURL: URL?
    @State private var showExportSuccess = false
    
    var body: some View {
        NavigationStack {
            List {
                // --- SEÇÃO 1: ASSINATURA ---
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(Color.medOrange)
                                .font(.title2)
                            Text("Seja Premium")
                                .medFont(.title3, weight: .bold)
                            Spacer()
                            if storeManager.isPremium {
                                BadgeMini(text: "ATIVO", color: .medGreen)
                            }
                        }
                        
                        Text("Desbloqueie backups automáticos e recursos avançados.")
                            .medFont(.caption)
                            .foregroundStyle(.secondary)
                        
                        if !storeManager.isPremium {
                            HStack(spacing: 10) {
                                SubscriptionButton(
                                    title: "Mensal",
                                    price: "R$ 10,00",
                                    sub: "/mês"
                                ) {
                                    print("Comprar Mensal")
                                }
                                
                                SubscriptionButton(
                                    title: "Anual",
                                    price: "R$ 100,00",
                                    sub: "/ano",
                                    isBestValue: true
                                ) {
                                    print("Comprar Anual")
                                }
                            }
                            .padding(.top, 5)
                            
                            Button("Restaurar Compras") {
                                Task {
                                    await storeManager.restorePurchases()
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(Color.medBlue)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 5)
                        } else {
                            Text("Obrigado por apoiar!")
                                .medFont(.subheadline)
                                .foregroundStyle(Color.medGreen)
                                .padding(.vertical, 5)
                        }
                    }
                    .padding(.vertical, 5)
                } header: {
                    Text("Assinatura")
                }
                
                // --- SEÇÃO 2: NOTIFICAÇÕES ---
                Section(header: Text("Notificações")) {
                    Toggle("Ativar Notificações", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { oldValue, newValue in
                            if newValue {
                                NotificationManager.shared.requestAuthorization()
                                rescheduleAllShifts()
                            } else {
                                NotificationManager.shared.cancelAll()
                            }
                        }
                        .tint(Color.medBlue)
                    
                    if notificationsEnabled {
                        Toggle("No dia (2 horas antes)", isOn: $notifyOnDay)
                            .onChange(of: notifyOnDay) { _, _ in
                                rescheduleAllShifts()
                            }
                        
                        Toggle("1 dia antes (Lembrete)", isOn: $notify24hBefore)
                            .onChange(of: notify24hBefore) { _, _ in
                                rescheduleAllShifts()
                            }
                    }
                }
                
                // --- SEÇÃO 3: PADRÕES ---
                Section(header: Text("Padrões de Cadastro")) {
                    HStack {
                        Text("Valor Padrão")
                        Spacer()
                        TextField("R$ 0,00", value: $defaultAmount, format: .currency(code: "BRL"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    Picker("Duração Padrão", selection: $defaultDurationRaw) {
                        ForEach(1...36, id: \.self) { hour in
                            Text("\(hour) horas").tag(hour)
                        }
                    }
                }
                
                // --- SEÇÃO 4: DADOS ---
                Section(header: Text("Dados e Backup")) {
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        calendarManager.syncShiftsToCalendar(shifts: shifts, context: modelContext)
                    }) {
                        HStack {
                            if calendarManager.isSyncing {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "calendar")
                                    .foregroundStyle(.blue)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(calendarManager.isSyncing ? "Sincronizando..." : "Sincronizar Calendário iOS")
                                    .foregroundStyle(.primary)
                                
                                if !calendarManager.lastSyncMessage.isEmpty {
                                    Text(calendarManager.lastSyncMessage)
                                        .font(.caption)
                                        .foregroundStyle(
                                            calendarManager.lastSyncMessage.contains("Erro") ? .red : .green
                                        )
                                }
                            }
                        }
                    }
                    .disabled(calendarManager.isSyncing)
                    
                    Button(action: exportToCSV) {
                        HStack {
                            Image(systemName: "tablecells")
                                .foregroundStyle(.green)
                            Text("Exportar Planilha (CSV)")
                                .foregroundStyle(.primary)
                        }
                    }
                    .sheet(isPresented: $isShareSheetPresented) {
                        if let url = csvURL {
                            ShareSheet(activityItems: [url])
                        }
                    }
                    .alert("Exportado com Sucesso", isPresented: $showExportSuccess) {
                        Button("OK", role: .cancel) { }
                    } message: {
                        Text("Planilha criada e pronta para compartilhar")
                    }
                    
                    HStack {
                        Image(systemName: "icloud.fill")
                            .foregroundStyle(.secondary)
                        Text("Seus dados são salvos automaticamente no iCloud.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // --- SEÇÃO 5: LEGAL ---
                Section(header: Text("Sobre")) {
                    Button(action: { showingTerms = true }) {
                        HStack {
                            Text("Termos de Uso e Privacidade")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                    
                    HStack {
                        Text("Versão")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Concluir") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingTerms) {
                TermsView()
            }
        }
    }
    
    // MARK: - Helper Functions
    
    func rescheduleAllShifts() {
        let futureShifts = shifts.filter { $0.startDate > Date() }
        for shift in futureShifts {
            NotificationManager.shared.scheduleNotification(for: shift)
        }
    }
    
    func exportToCSV() {
        HapticManager.shared.impact(.light)
        
        let fileName = "MeuPlantao_Backup_\(Date().formatted(date: .numeric, time: .omitted)).csv"
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        var csvText = "Data,Hora,Local,Duracao,Status,Tipo,Valor,Nota\n"
        
        for shift in shifts {
            let date = shift.startDate.formatted(date: .numeric, time: .omitted)
            let time = shift.startDate.formatted(date: .omitted, time: .shortened)
            let local = escapeCSV(shift.locationName)
            let duracao = shift.isAllDay ? "Dia Inteiro" : "\(shift.durationHours)h"
            let status = shift.status.rawValue
            let tipo = shift.isCommitment ? "Compromisso" : "Plantão"
            let valor = shift.isCommitment ? "0.00" : shift.amount.formatted(.number)
            let note = escapeCSV(shift.notes ?? "")
            
            csvText.append("\(date),\(time),\(local),\(duracao),\(status),\(tipo),\(valor),\(note)\n")
        }
        
        do {
            try csvText.write(to: path, atomically: true, encoding: .utf8)
            csvURL = path
            HapticManager.shared.notification(.success)
            isShareSheetPresented = true
        } catch {
            print("Erro ao criar CSV: \(error)")
            HapticManager.shared.notification(.error)
        }
    }
    
    /// Escapa caracteres especiais para formato CSV
    private func escapeCSV(_ text: String) -> String {
        let escaped = text.replacingOccurrences(of: "\"", with: "\"\"")
        
        // Se contém vírgula, aspas ou quebra de linha, envolve em aspas
        if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") {
            return "\"\(escaped)\""
        }
        
        return escaped
    }
}

// MARK: - Supporting Views

struct SubscriptionButton: View {
    let title: String
    let price: String
    let sub: String
    var isBestValue: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(.medium)
            action()
        }) {
            VStack(spacing: 5) {
                if isBestValue {
                    Text("MELHOR VALOR")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.medOrange)
                        .clipShape(Capsule())
                        .offset(y: -10)
                }
                
                Text(title)
                    .medFont(.headline)
                    .foregroundStyle(.primary)
                
                Text(price)
                    .medFont(.title3, weight: .bold)
                    .foregroundStyle(Color.medBlue)
                
                Text(sub)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isBestValue ? Color.medOrange : Color.gray.opacity(0.2), lineWidth: isBestValue ? 2 : 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 5)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
