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
        // 1. Validações básicas (não agendar passado)
        if shift.startDate < Date() { return }
        
        // 2. Ler preferências
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "notificationsEnabled") {
            cancelNotification(for: shift)
            return
        }
        
        let notifyOnDay = defaults.bool(forKey: "notifyOnDay")
        let notify24h = defaults.bool(forKey: "notify24hBefore")
        
        let content = UNMutableNotificationContent()
        content.sound = .default
        
        // Texto Base
        if shift.isCommitment {
            content.title = "Compromisso"
            content.body = "\(shift.locationName)"
        } else {
            content.title = "Plantão"
            content.body = "Local: \(shift.locationName)"
        }
        
        let center = UNUserNotificationCenter.current()
        
        // --- 1. Alerta 24h antes (Lembrete Geral) ---
        if notify24h {
            if let date24h = Calendar.current.date(byAdding: .day, value: -1, to: shift.startDate), date24h > Date() {
                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date24h)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                
                let content24 = content.mutableCopy() as! UNMutableNotificationContent
                content24.body = "Amanhã: \(shift.locationName)"
                
                let request = UNNotificationRequest(identifier: "\(shift.id.uuidString)-24h", content: content24, trigger: trigger)
                center.add(request)
            }
        } else {
            center.removePendingNotificationRequests(withIdentifiers: ["\(shift.id.uuidString)-24h"])
        }
        
        // --- 2. Alerta 2h antes (Urgência) ---
        // IMPORTANTE: Se for Dia Todo (00:00), não queremos notificar 22:00 do dia anterior como urgência.
        if notifyOnDay && !shift.isAllDay {
            if let date2h = Calendar.current.date(byAdding: .hour, value: -2, to: shift.startDate), date2h > Date() {
                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date2h)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                
                let content2h = content.mutableCopy() as! UNMutableNotificationContent
                if !shift.isCommitment {
                    content2h.body = "Em 2 horas: \(shift.durationHours)h de plantão."
                } else {
                    content2h.body = "Começa em 2 horas: \(shift.locationName)"
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
    
    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
