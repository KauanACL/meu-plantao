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
    @AppStorage("notifyOnDay") private var notifyOnDay: Bool = true      // 2 horas antes
    @AppStorage("notify24hBefore") private var notify24hBefore: Bool = true // 1 dia antes
    
    // Controles de Tela
    @State private var showingTerms = false
    @State private var isShareSheetPresented = false
    @State private var csvURL: URL?
    
    var body: some View {
        NavigationStack {
            List {
                // --- SEÇÃO 1: ASSINATURA ---
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "crown.fill").foregroundStyle(Color.medOrange).font(.title2)
                            Text("Seja Premium").medFont(.title3, weight: .bold)
                            Spacer()
                            if storeManager.isPremium { BadgeMini(text: "ATIVO", color: .medGreen) }
                        }
                        Text("Desbloqueie backups automáticos e recursos avançados.").medFont(.caption).foregroundStyle(.secondary)
                        
                        if !storeManager.isPremium {
                            HStack(spacing: 10) {
                                SubscriptionButton(title: "Mensal", price: "R$ 10,00", sub: "/mês") { print("Comprar Mensal") }
                                SubscriptionButton(title: "Anual", price: "R$ 100,00", sub: "/ano", isBestValue: true) { print("Comprar Anual") }
                            }.padding(.top, 5)
                            Button("Restaurar Compras") { Task { await storeManager.restorePurchases() } }
                                .font(.caption).foregroundStyle(Color.medBlue).frame(maxWidth: .infinity).padding(.top, 5)
                        } else {
                            Text("Obrigado por apoiar!").medFont(.subheadline).foregroundStyle(Color.medGreen).padding(.vertical, 5)
                        }
                    }.padding(.vertical, 5)
                } header: { Text("Assinatura") }
                
                // --- SEÇÃO 2: NOTIFICAÇÕES (CORRIGIDO iOS 17) ---
                Section(header: Text("Notificações")) {
                    Toggle("Ativar Notificações", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { oldValue, newValue in
                            if newValue {
                                NotificationManager.shared.requestAuthorization()
                                rescheduleAllShifts() // Reagendar se ativou
                            } else {
                                NotificationManager.shared.cancelAll() // Cancelar tudo se desativou
                            }
                        }
                        .tint(Color.medBlue)
                    
                    if notificationsEnabled {
                        Toggle("No dia (2 horas antes)", isOn: $notifyOnDay)
                            .onChange(of: notifyOnDay) { _, _ in rescheduleAllShifts() }
                        
                        Toggle("1 dia antes (Lembrete)", isOn: $notify24hBefore)
                            .onChange(of: notify24hBefore) { _, _ in rescheduleAllShifts() }
                    }
                }
                
                // --- SEÇÃO 3: PADRÕES ---
                Section(header: Text("Padrões de Cadastro")) {
                    HStack {
                        Text("Valor Padrão")
                        Spacer()
                        TextField("R$ 0,00", value: $defaultAmount, format: .currency(code: "BRL"))
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    Picker("Duração Padrão", selection: $defaultDurationRaw) {
                        ForEach(1...36, id: \.self) { hour in Text("\(hour) horas").tag(hour) }
                    }
                }
                
                // --- SEÇÃO 4: DADOS ---
                Section(header: Text("Dados e Backup")) {
                    Button(action: { calendarManager.syncShiftsToCalendar(shifts: shifts, context: modelContext) }) {
                        HStack {
                            Image(systemName: "calendar").foregroundStyle(.blue)
                            VStack(alignment: .leading) {
                                Text("Sincronizar Calendário iOS").foregroundStyle(.primary)
                                if !calendarManager.lastSyncMessage.isEmpty {
                                    Text(calendarManager.lastSyncMessage)
                                        .font(.caption)
                                        .foregroundStyle(calendarManager.lastSyncMessage.contains("Erro") ? .red : .green)
                                }
                            }
                        }
                    }
                    Button(action: exportToCSV) {
                        HStack {
                            Image(systemName: "tablecells").foregroundStyle(.green)
                            Text("Exportar Planilha (CSV)").foregroundStyle(.primary)
                        }
                    }
                    .sheet(isPresented: $isShareSheetPresented) { if let url = csvURL { ShareSheet(activityItems: [url]) } }
                    
                    HStack {
                        Image(systemName: "icloud.fill").foregroundStyle(.secondary)
                        Text("Seus dados são salvos automaticamente no iCloud.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                
                // --- SEÇÃO 5: LEGAL ---
                Section(header: Text("Sobre")) {
                    Button(action: { showingTerms = true }) {
                        HStack { Text("Termos de Uso e Privacidade"); Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary) }
                    }.foregroundStyle(.primary)
                    HStack { Text("Versão"); Spacer(); Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0").foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Concluir") { dismiss() } } }
            .sheet(isPresented: $showingTerms) { TermsView() }
        }
    }
    
    // Função Auxiliar
    func rescheduleAllShifts() {
        let futureShifts = shifts.filter { $0.startDate > Date() }
        for shift in futureShifts {
            NotificationManager.shared.scheduleNotification(for: shift)
        }
    }
    
    func exportToCSV() {
        let fileName = "MeuPlantao_Backup.csv"
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        var csvText = "Data,Local,Duracao,Status,Valor,Nota\n"
        for shift in shifts {
            let date = shift.startDate.formatted(date: .numeric, time: .shortened)
            let local = shift.locationName.replacingOccurrences(of: ",", with: " ")
            let valor = shift.amount.formatted(.number)
            let status = shift.status.rawValue
            let note = (shift.notes ?? "").replacingOccurrences(of: "\n", with: " ")
            csvText.append("\(date),\(local),\(shift.durationHours)h,\(status),\(valor),\(note)\n")
        }
        do { try csvText.write(to: path, atomically: true, encoding: .utf8); csvURL = path; isShareSheetPresented = true } catch { print("Erro CSV: \(error)") }
    }
}

// ... (Mantenha SubscriptionButton e ShareSheet iguais) ...
struct SubscriptionButton: View {
    let title: String; let price: String; let sub: String; var isBestValue: Bool = false; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                if isBestValue {
                    Text("MELHOR VALOR").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 2).background(Color.medOrange).clipShape(Capsule()).offset(y: -10)
                }
                Text(title).medFont(.headline).foregroundStyle(.primary)
                Text(price).medFont(.title3, weight: .bold).foregroundStyle(Color.medBlue)
                Text(sub).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 15).background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isBestValue ? Color.medOrange : Color.gray.opacity(0.2), lineWidth: isBestValue ? 2 : 1))
            .shadow(color: .black.opacity(0.05), radius: 5)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]; var applicationActivities: [UIActivity]? = nil
    func makeUIViewController(context: Context) -> UIActivityViewController { let c = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities); return c }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
