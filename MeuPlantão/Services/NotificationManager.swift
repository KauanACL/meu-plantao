import Foundation
import UserNotifications
import UIKit

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Erro ao solicitar notificação: \(error)")
            }
        }
    }
    
    func scheduleNotification(for shift: Shift) {
        // 1. Verifica se é um compromisso ou se já passou (não agendar)
        // Se for compromisso (isCommitment), decidimos se avisamos ou não.
        // Por padrão, vamos avisar também, mas com texto diferente?
        // Vamos focar em PLANTÕES de trabalho conforme pedido.
        if shift.startDate < Date() { return }
        
        // 2. LER PREFERÊNCIAS DO USUÁRIO
        let defaults = UserDefaults.standard
        
        // Se as notificações estiverem desligadas geral, para tudo e cancela existentes deste plantão
        if !defaults.bool(forKey: "notificationsEnabled") {
            cancelNotification(for: shift)
            return
        }
        
        let notifyOnDay = defaults.bool(forKey: "notifyOnDay")      // No dia (2h antes)
        let notify24h = defaults.bool(forKey: "notify24hBefore")    // 1 dia antes
        
        // Conteúdo Base
        let content = UNMutableNotificationContent()
        content.sound = .default
        
        if shift.isCommitment {
            content.title = "Compromisso Pessoal"
            content.body = "\(shift.locationName) às \(shift.startDate.formatted(date: .omitted, time: .shortened))"
        } else {
            content.title = "Lembrete de Plantão"
            content.body = "Seu plantão em \(shift.locationName) começa em breve."
        }
        
        let center = UNUserNotificationCenter.current()
        
        // --- AGENDAMENTO 24H ANTES ---
        if notify24h {
            if let date24h = Calendar.current.date(byAdding: .day, value: -1, to: shift.startDate), date24h > Date() {
                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date24h)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                
                // Personaliza texto para 1 dia antes
                let content24 = content.mutableCopy() as! UNMutableNotificationContent
                content24.body = "Amanhã: \(shift.locationName) às \(shift.startDate.formatted(date: .omitted, time: .shortened))."
                
                let request = UNNotificationRequest(identifier: "\(shift.id.uuidString)-24h", content: content24, trigger: trigger)
                center.add(request)
            }
        } else {
            // Se o usuário desmarcou essa opção, removemos especificamente esse alerta se existia
            center.removePendingNotificationRequests(withIdentifiers: ["\(shift.id.uuidString)-24h"])
        }
        
        // --- AGENDAMENTO NO DIA (2H ANTES) ---
        if notifyOnDay {
            if let date2h = Calendar.current.date(byAdding: .hour, value: -2, to: shift.startDate), date2h > Date() {
                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date2h)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                
                let content2h = content.mutableCopy() as! UNMutableNotificationContent
                if !shift.isCommitment {
                    content2h.body = "Prepare-se! Faltam 2 horas para seu plantão de \(shift.durationHours)h."
                }
                
                let request = UNNotificationRequest(identifier: "\(shift.id.uuidString)-2h", content: content2h, trigger: trigger)
                center.add(request)
            }
        } else {
            center.removePendingNotificationRequests(withIdentifiers: ["\(shift.id.uuidString)-2h"])
        }
    }
    
    func cancelNotification(for shift: Shift) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [
            "\(shift.id.uuidString)-24h",
            "\(shift.id.uuidString)-2h"
        ])
    }
    
    // Função útil para limpar tudo se o usuário desativar geral
    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
