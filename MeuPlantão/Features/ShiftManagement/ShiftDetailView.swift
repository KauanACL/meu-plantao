import SwiftUI
import MapKit
import SwiftData

struct ShiftDetailView: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var shift: Shift
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    
                    // 1. MAPA (Só aparece se tiver GPS)
                    if let lat = shift.latitude, let long = shift.longitude {
                        Map(position: $cameraPosition) {
                            Marker(shift.locationName, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: long))
                        }
                        .frame(height: 200).clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                        .onAppear {
                            let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: lat, longitude: long), span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                            cameraPosition = .region(region)
                        }
                    } else {
                        // Se não tiver mapa (Compromisso texto), damos um espaço extra no topo
                        Spacer().frame(height: 20)
                    }
                    
                    // 2. HEADER (Título e Tempo)
                    VStack(spacing: 5) {
                        Text(shift.locationName)
                            .medFont(.title2, weight: .bold)
                            .multilineTextAlignment(.center)
                        
                        HStack {
                            Text(shift.startDate.formatted(date: .complete, time: .omitted).capitalized)
                            Text("•")
                            
                            // LÓGICA DE TEMPO (NOVO)
                            if shift.isAllDay {
                                Text("Dia Inteiro")
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.medBlue)
                            } else {
                                Text("\(shift.durationHours)h")
                                    .fontWeight(.bold)
                                if !shift.isAllDay {
                                    Text("(\(shift.startDate.formatted(date: .omitted, time: .shortened)))")
                                }
                            }
                        }
                        .medFont(.subheadline)
                        .foregroundStyle(.secondary)
                        
                        // 3. BOTÃO DE CONCLUIR (Só para Plantões de Trabalho)
                        if !shift.isCommitment && shift.status != .swappedOut {
                            Button(action: { withAnimation { shift.isWorkDone.toggle() } }) {
                                HStack {
                                    Image(systemName: shift.isWorkDone ? "checkmark.seal.fill" : "square")
                                    Text(shift.isWorkDone ? "Plantão Concluído" : "Marcar como Realizado")
                                }
                                .medFont(.headline, weight: .bold)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(shift.isWorkDone ? Color.medGreen : Color.medBlue)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: (shift.isWorkDone ? Color.medGreen : Color.medBlue).opacity(0.3), radius: 10, y: 5)
                            }
                            .padding(.top, 10)
                        }
                    }
                    
                    // 4. DETALHES ESPECÍFICOS
                    if shift.isCommitment {
                        // --- SE FOR COMPROMISSO ---
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .font(.title2)
                                    .foregroundStyle(Color.gray)
                                Text("Compromisso Pessoal")
                                    .medFont(.headline)
                            }
                            Text("Este evento bloqueia sua agenda, mas não contabiliza horas trabalhadas nem valor financeiro.")
                                .medFont(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .medCard()
                        
                    } else {
                        // --- SE FOR PLANTÃO (Configurações Avançadas) ---
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Configuração Operacional").medFont(.headline).padding(.leading, 5)
                            
                            VStack(spacing: 0) {
                                // NORMAL
                                TypeSelectRow(title: "Plantão Normal", icon: "person.fill", color: .medBlue, isSelected: shift.status == .scheduled) {
                                    withAnimation { shift.status = .scheduled }
                                }
                                Divider()
                                
                                // SAÍDA
                                TypeSelectRow(title: "Troquei (Saí)", icon: "arrow.up.right.circle.fill", color: .medRed, isSelected: shift.status == .swappedOut) {
                                    withAnimation {
                                        shift.status = .swappedOut
                                        shift.isWorkDone = false
                                    }
                                }
                                
                                if shift.status == .swappedOut {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Acordo de Repasse (Você paga)").medFont(.caption).bold().foregroundStyle(.secondary)
                                        
                                        HStack {
                                            Text("Valor a Pagar")
                                            Spacer()
                                            TextField("R$ 0,00", value: $shift.swapValue, format: .currency(code: "BRL"))
                                                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                                .medInput().frame(width: 150)
                                        }
                                        
                                        DatePicker("Data Combinada", selection: Binding(get: { shift.swapPaymentDate ?? Date() }, set: { shift.swapPaymentDate = $0 }), displayedComponents: .date)
                                        
                                        Toggle(isOn: $shift.swapIsSettled) {
                                            Text("Já paguei o colega").medFont(.subheadline, weight: .bold)
                                        }
                                        .toggleStyle(SwitchToggleStyle(tint: .medGreen))
                                    }
                                    .padding().background(Color.medRed.opacity(0.05))
                                }
                                
                                Divider()
                                
                                // ENTRADA
                                TypeSelectRow(title: "Troquei (Entrei)", icon: "arrow.down.left.circle.fill", color: .medBlue, isSelected: shift.status == .swappedIn) {
                                    withAnimation { shift.status = .swappedIn }
                                }
                                
                                if shift.status == .swappedIn {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Acordo de Recebimento").medFont(.caption).bold().foregroundStyle(.secondary)
                                        
                                        HStack {
                                            Text("Valor a Receber")
                                            Spacer()
                                            TextField("R$ 0,00", value: $shift.swapValue, format: .currency(code: "BRL"))
                                                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                                .medInput().frame(width: 150)
                                        }
                                        
                                        DatePicker("Data Combinada", selection: Binding(get: { shift.swapPaymentDate ?? Date() }, set: { shift.swapPaymentDate = $0 }), displayedComponents: .date)
                                        
                                        Toggle(isOn: $shift.swapIsSettled) {
                                            Text("Já recebi o valor").medFont(.subheadline, weight: .bold)
                                        }
                                        .toggleStyle(SwitchToggleStyle(tint: .medGreen))
                                    }
                                    .padding().background(Color.medBlue.opacity(0.1))
                                }
                            }
                            .medCard()
                        }
                        
                        // 5. CARD FINANCEIRO (HOSPITAL)
                        if shift.status != .swappedIn {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Hospital (Fonte Pagadora)").medFont(.headline).padding(.leading, 5)
                                
                                VStack(spacing: 15) {
                                    HStack {
                                        Text("Valor em Escala").medFont(.subheadline).foregroundStyle(.secondary)
                                        Spacer()
                                    }
                                    
                                    HStack {
                                        TextField("R$ 0,00", value: $shift.amount, format: .currency(code: "BRL"))
                                            .keyboardType(.decimalPad)
                                            .font(.system(.title3, design: .rounded, weight: .bold))
                                            .multilineTextAlignment(.leading)
                                            .padding()
                                            .background(Color(.tertiarySystemBackground)) // Input Color
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                                        
                                        Button(action: { withAnimation { shift.isPaid.toggle() } }) {
                                            VStack {
                                                Image(systemName: shift.isPaid ? "checkmark.circle.fill" : "circle").font(.title2)
                                                Text(shift.isPaid ? "Recebido" : "Pendente").font(.caption2).bold()
                                            }
                                            .frame(height: 55).padding(.horizontal, 15)
                                            .background(shift.isPaid ? Color.medGreen.opacity(0.15) : Color(.systemGray5))
                                            .foregroundStyle(shift.isPaid ? Color.medGreen : .secondary)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                        }
                                    }
                                }
                                .medCard()
                            }
                        }
                    }
                    
                    // 6. NOTAS
                    if let notes = shift.notes, !notes.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Notas").medFont(.headline).padding(.leading, 5)
                            Text(notes).frame(maxWidth: .infinity, alignment: .leading).medCard()
                        }
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
        }
        .navigationTitle("Detalhes")
        .navigationBarTitleDisplayMode(.inline)
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}

// COMPONENTE AUXILIAR
struct TypeSelectRow: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(isSelected ? color : .gray)
                    .frame(width: 30)
                
                Text(title)
                    .medFont(.body, weight: isSelected ? .bold : .medium)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(color)
                        .font(.headline)
                }
            }
            .padding()
            .background(isSelected ? color.opacity(0.05) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}
